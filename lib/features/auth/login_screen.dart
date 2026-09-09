import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/auth_providers.dart';
import '../../core/providers/dao_providers.dart';
import '../../data/local/database.dart';
import '../../data/repositories/auth_repository.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  CachedProfile? _selected;
  bool _manualEntry = false;
  final _emailController = TextEditingController();
  final _pinController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _emailController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dao = ref.watch(cachedProfileDaoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('로그인')),
      body: StreamBuilder<List<CachedProfile>>(
        stream: dao.watchAll(),
        builder: (context, snapshot) {
          final profiles = snapshot.data ?? [];

          if (_manualEntry) return _buildManualEntry();
          if (_selected != null) return _buildPinEntry(_selected!.displayName);

          return ListView(
            children: [
              for (final profile in profiles)
                ListTile(
                  title: Text(profile.displayName),
                  onTap: () => setState(() => _selected = profile),
                ),
              TextButton(
                key: const Key('manualEntryButton'),
                onPressed: () => setState(() => _manualEntry = true),
                child: const Text('이메일로 로그인 (이 기기가 처음이신가요?)'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildManualEntry() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextField(
            key: const Key('emailField'),
            controller: _emailController,
            decoration: const InputDecoration(labelText: '이메일'),
          ),
          TextField(
            key: const Key('manualPinField'),
            controller: _pinController,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(labelText: 'PIN'),
          ),
          if (_errorText != null)
            Text(_errorText!, style: const TextStyle(color: Colors.red)),
          ElevatedButton(
            onPressed: () => _submit(
              id: null,
              email: _emailController.text.trim(),
              pin: _pinController.text,
            ),
            child: const Text('로그인'),
          ),
          TextButton(
            onPressed: () => setState(() {
              _manualEntry = false;
              _errorText = null;
            }),
            child: const Text('이름 목록으로 돌아가기'),
          ),
        ],
      ),
    );
  }

  Widget _buildPinEntry(String displayName) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(displayName),
          const SizedBox(height: 16),
          TextField(
            key: const Key('pinField'),
            controller: _pinController,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(labelText: 'PIN'),
          ),
          if (_errorText != null)
            Text(_errorText!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _submit(
              id: _selected!.id,
              email: _selected!.email,
              pin: _pinController.text,
            ),
            child: const Text('로그인'),
          ),
          TextButton(
            onPressed: () => setState(() {
              _selected = null;
              _errorText = null;
              _pinController.clear();
            }),
            child: const Text('다른 사용자'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit({
    required String? id,
    required String email,
    required String pin,
  }) async {
    final result = await ref.read(authRepositoryProvider).login(
          id: id,
          email: email,
          pin: pin,
        );

    if (result.outcome == AuthOutcome.success) {
      ref.read(authSessionProvider.notifier).setSession(
            AuthSession(
              id: result.userId!,
              email: email,
              pin: pin,
              displayName: result.displayName!,
              role: result.role!,
            ),
          );
      return;
    }

    setState(() {
      _errorText = result.outcome == AuthOutcome.offlineNoCache
          ? '이 기기에서 온라인으로 로그인한 기록이 없습니다'
          : 'PIN이 올바르지 않습니다';
    });
  }
}
