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
}
