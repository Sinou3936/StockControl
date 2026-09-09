import 'package:stockcontrol/data/services/auth_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeAuthGateway implements AuthGateway {
  FakeAuthGateway({this.throwNetworkError = false});

  final bool throwNetworkError;
  final Map<String, _FakeUser> _usersByEmail = {};
  final Map<String, Map<String, dynamic>> _profilesById = {};

  void seedUser({
    required String id,
    required String email,
    required String password,
    required String displayName,
    required String role,
  }) {
    _usersByEmail[email] = _FakeUser(id: id, password: password);
    _profilesById[id] = {'id': id, 'display_name': displayName, 'role': role};
  }

  @override
  Future<AuthGatewayUser> signInWithPassword({
    required String email,
    required String password,
  }) async {
    if (throwNetworkError) {
      throw AuthRetryableFetchException(message: '시뮬레이션된 네트워크 오류');
    }
    final user = _usersByEmail[email];
    if (user == null || user.password != password) {
      throw const AuthApiException('이메일 또는 PIN이 올바르지 않습니다');
    }
    return AuthGatewayUser(user.id);
  }

  @override
  Future<AuthGatewayUser> signUp({
    required String email,
    required String password,
  }) async {
    final id = 'fake-user-${_usersByEmail.length + 1}';
    _usersByEmail[email] = _FakeUser(id: id, password: password);
    return AuthGatewayUser(id);
  }

  @override
  Future<Map<String, dynamic>> fetchProfile(String userId) async {
    final profile = _profilesById[userId];
    if (profile == null) {
      throw const AuthApiException('프로필을 찾을 수 없습니다');
    }
    return profile;
  }

  @override
  Future<void> insertProfile({
    required String id,
    required String displayName,
    required String role,
  }) async {
    _profilesById[id] = {'id': id, 'display_name': displayName, 'role': role};
  }
}

class _FakeUser {
  _FakeUser({required this.id, required this.password});

  final String id;
  final String password;
}
