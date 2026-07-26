import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vaxiil_mobile/core/constants/app_routes.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';
import 'package:vaxiil_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vaxiil_mobile/features/auth/presentation/cubit/auth_state.dart';
import 'package:vaxiil_mobile/l10n/app_localizations.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';

/// Blocking screen when the account email is not verified.
class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({super.key});

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  final _codeController = TextEditingController();
  String? _challengeId;
  String _emailHint = '';
  String? _info;
  String? _error;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthCubit>().state.user;
    _emailHint = user?.email ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) => _sendCode());
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await context.read<AuthCubit>().sendEmailVerification();
      if (!mounted) return;
      setState(() {
        _challengeId = result.challengeId;
        if (result.emailHint.isNotEmpty) {
          _emailHint = result.emailHint;
        }
        _info = AppLocalizations.of(context)!.emailVerifySent;
        _busy = false;
      });
    } on Failure catch (f) {
      if (!mounted) return;
      setState(() {
        _error = f.message;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _busy = false;
      });
    }
  }

  Future<void> _verify() async {
    final l10n = AppLocalizations.of(context)!;
    final challengeId = _challengeId;
    final code = _codeController.text.trim();
    if (challengeId == null || challengeId.isEmpty || code.isEmpty) {
      setState(() => _error = l10n.emailVerifyCodeRequired);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    await context.read<AuthCubit>().verifyEmail(
          challengeId: challengeId,
          code: code,
        );
    if (!mounted) return;
    final state = context.read<AuthCubit>().state;
    if (state.status == AuthStatus.authenticated &&
        !(state.user?.needsEmailVerification ?? true)) {
      context.go(AppRoutes.home);
      return;
    }
    setState(() {
      _error = state.errorMessage ?? l10n.emailVerifyCodeRequired;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.emailVerifyTitle,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.emailVerifyLede(_emailHint),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
              if (_info != null) ...[
                const SizedBox(height: 12),
                Text(_info!, style: TextStyle(color: AppTheme.primaryColor)),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l10n.emailVerifyCode),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _verify,
                child: Text(
                  _busy ? l10n.emailVerifySubmitting : l10n.emailVerifySubmit,
                ),
              ),
              TextButton(
                onPressed: _busy ? null : _sendCode,
                child: Text(l10n.emailVerifyResend),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
