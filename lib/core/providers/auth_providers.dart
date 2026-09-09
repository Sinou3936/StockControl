import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/auth_repository.dart';
import '../../data/services/auth_gateway.dart';
import 'dao_providers.dart';

class AuthSession {
  AuthSession({
    required this.id,
    required this.email,
    required this.pin,
    required this.displayName,
    required this.role,
  });

  final String id;
  final String email;
  final String pin;
  final String displayName;
  final String role;

  bool get isOwner => role == 'owner';
}

class AuthSessionNotifier extends StateNotifier<AuthSession?> {
  AuthSessionNotifier() : super(null);

  void setSession(AuthSession session) => state = session;

  void clear() => state = null;
}

final authSessionProvider =
    StateNotifierProvider<AuthSessionNotifier, AuthSession?>(
  (ref) => AuthSessionNotifier(),
);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    SupabaseAuthGateway(Supabase.instance.client),
    ref.watch(cachedProfileDaoProvider),
  );
});
