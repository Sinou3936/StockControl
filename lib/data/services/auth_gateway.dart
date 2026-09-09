import 'package:supabase_flutter/supabase_flutter.dart';

class AuthGatewayUser {
  AuthGatewayUser(this.id);

  final String id;
}

abstract class AuthGateway {
  Future<AuthGatewayUser> signInWithPassword({
    required String email,
    required String password,
  });

  Future<AuthGatewayUser> signUp({
    required String email,
    required String password,
  });

  Future<Map<String, dynamic>> fetchProfile(String userId);

  Future<void> insertProfile({
    required String id,
    required String displayName,
    required String role,
  });
}

class SupabaseAuthGateway implements AuthGateway {
  SupabaseAuthGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<AuthGatewayUser> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final user = response.user;
    if (user == null) {
      throw const AuthApiException('로그인에 실패했습니다');
    }
    return AuthGatewayUser(user.id);
  }

  @override
  Future<AuthGatewayUser> signUp({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );
    final user = response.user;
    if (user == null) {
      throw const AuthApiException('계정 생성에 실패했습니다');
    }
    return AuthGatewayUser(user.id);
  }

  @override
  Future<Map<String, dynamic>> fetchProfile(String userId) {
    return _client.from('profiles').select().eq('id', userId).single();
  }

  @override
  Future<void> insertProfile({
    required String id,
    required String displayName,
    required String role,
  }) {
    return _client.from('profiles').insert({
      'id': id,
      'display_name': displayName,
      'role': role,
    });
  }
}
