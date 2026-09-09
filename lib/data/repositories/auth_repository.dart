import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/pin_hash.dart';
import '../local/daos/cached_profile_dao.dart';
import '../local/database.dart';
import '../services/auth_gateway.dart';

enum AuthOutcome { success, invalidPin, offlineNoCache }

class AuthResult {
  AuthResult({
    required this.outcome,
    this.userId,
    this.displayName,
    this.role,
  });

  final AuthOutcome outcome;
  final String? userId;
  final String? displayName;
  final String? role;
}

class AuthRepository {
  AuthRepository(this._gateway, this._cachedProfileDao);

  final AuthGateway _gateway;
  final CachedProfileDao _cachedProfileDao;

  Future<AuthResult> login({
    String? id,
    required String email,
    required String pin,
  }) async {
    try {
      final user = await _gateway.signInWithPassword(
        email: email,
        password: pin,
      );
      final profileRow = await _gateway.fetchProfile(user.id);
      final displayName = profileRow['display_name'] as String;
      final role = profileRow['role'] as String;

      final salt = generatePinSalt();
      await _cachedProfileDao.upsertProfile(
        CachedProfilesCompanion.insert(
          id: user.id,
          displayName: displayName,
          role: role,
          email: email,
          pinHash: hashPin(pin, salt),
          pinSalt: salt,
        ),
      );

      return AuthResult(
        outcome: AuthOutcome.success,
        userId: user.id,
        displayName: displayName,
        role: role,
      );
    } on AuthRetryableFetchException {
      if (id == null) {
        return AuthResult(outcome: AuthOutcome.offlineNoCache);
      }
      final cached = await _cachedProfileDao.getById(id);
      if (cached == null) {
        return AuthResult(outcome: AuthOutcome.offlineNoCache);
      }
      if (hashPin(pin, cached.pinSalt) == cached.pinHash) {
        return AuthResult(
          outcome: AuthOutcome.success,
          userId: cached.id,
          displayName: cached.displayName,
          role: cached.role,
        );
      }
      return AuthResult(outcome: AuthOutcome.invalidPin);
    } on AuthException {
      return AuthResult(outcome: AuthOutcome.invalidPin);
    }
  }

  Future<void> addStaff({
    required String displayName,
    required String pin,
    required String ownerEmail,
    required String ownerPin,
  }) async {
    final syntheticEmail =
        'staff-${DateTime.now().millisecondsSinceEpoch}@internal.local';

    final newUser = await _gateway.signUp(
      email: syntheticEmail,
      password: pin,
    );

    await _gateway.insertProfile(
      id: newUser.id,
      displayName: displayName,
      role: 'staff',
    );

    // 이 기기의 로그인 화면 이름 목록에 바로 뜨고, 곧바로 PIN으로 로그인할 수
    // 있도록 login()과 동일하게 로컬 캐시에도 저장해둔다. addStaff()를 거치지
    // 않으면 이 직원은 실제로 한 번 로그인하기 전까지는 캐시에 없어서, 이름
    // 목록에도 안 뜨고 자동 생성된 이메일도 알 방법이 없어 로그인 자체가
    // 불가능해진다.
    final salt = generatePinSalt();
    await _cachedProfileDao.upsertProfile(
      CachedProfilesCompanion.insert(
        id: newUser.id,
        displayName: displayName,
        role: 'staff',
        email: syntheticEmail,
        pinHash: hashPin(pin, salt),
        pinSalt: salt,
      ),
    );

    // signUp()이 세션을 방금 만든 직원 계정으로 바꿔버리므로, 사장 계정으로
    // 다시 로그인해서 세션을 복구한다.
    await _gateway.signInWithPassword(email: ownerEmail, password: ownerPin);
  }
}
