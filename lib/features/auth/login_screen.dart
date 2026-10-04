import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/auth_providers.dart';
import '../../core/providers/dao_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _BrandHeader(),
                  const SizedBox(height: 24),
                  StreamBuilder<List<CachedProfile>>(
                    stream: dao.watchAll(),
                    builder: (context, snapshot) {
                      final profiles = snapshot.data ?? [];

                      if (_manualEntry) return _buildManualEntry();
                      if (_selected != null) {
                        return _buildPinEntry(_selected!.displayName);
                      }
                      return _buildProfileList(profiles);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileList(List<CachedProfile> profiles) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: SectionLabel('이름을 선택하세요'),
          ),
          for (final profile in profiles) ...[
            const Divider(height: 1, color: AppColors.border),
            InkWell(
              onTap: () => setState(() => _selected = profile),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    _Avatar(name: profile.displayName),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        profile.displayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textStrong,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
          ],
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 8),
          TextButton(
            key: const Key('manualEntryButton'),
            onPressed: () => setState(() => _manualEntry = true),
            child: const Text('이메일로 로그인 (이 기기가 처음이신가요?)'),
          ),
        ],
      ),
    );
  }

  Widget _buildManualEntry() {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionLabel('이메일로 로그인'),
          TextField(
            key: const Key('emailField'),
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: '이메일'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('manualPinField'),
            controller: _pinController,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: 'PIN',
              counterText: '',
            ),
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 12),
            InlineError(_errorText!),
          ],
          const SizedBox(height: 16),
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
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Avatar(name: displayName),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textStrong,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            key: const Key('pinField'),
            controller: _pinController,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, letterSpacing: 8),
            decoration: const InputDecoration(
              labelText: 'PIN',
              counterText: '',
            ),
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 12),
            InlineError(_errorText!),
          ],
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
    final result = await ref
        .read(authRepositoryProvider)
        .login(id: id, email: email, pin: pin);

    if (result.outcome == AuthOutcome.success) {
      ref
          .read(authSessionProvider.notifier)
          .setSession(
            AuthSession(
              id: result.userId!,
              email: email,
              pin: pin,
              displayName: result.displayName!,
              role: result.role!,
              storeId: result.storeId,
              storeName: result.storeName,
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

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Icon(Icons.inventory_2_outlined, size: 40, color: AppColors.primary),
        SizedBox(height: 10),
        Text(
          '재고관리',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.textStrong,
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.isEmpty ? '?' : name.characters.first;

    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.chipBackground,
        shape: BoxShape.circle,
      ),
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
