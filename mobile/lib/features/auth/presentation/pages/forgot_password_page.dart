import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vaxiil_mobile/core/constants/app_routes.dart';
import 'package:vaxiil_mobile/core/di/injection_container.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';
import 'package:vaxiil_mobile/features/auth/data/auth_repository.dart';
import 'package:vaxiil_mobile/l10n/app_localizations.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';
import 'package:vaxiil_mobile/shared/widgets/soft_card.dart';
import 'package:vaxiil_mobile/shared/widgets/turnstile_widget.dart';
import 'package:vaxiil_mobile/shared/widgets/vaxiil_logo.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _requestKey = GlobalKey<FormState>();
  final _confirmKey = GlobalKey<FormState>();
  final _turnstileKey = GlobalKey<TurnstileWidgetState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();

  var _step = _ForgotStep.request;
  String? _challengeId;
  String? _turnstileToken;
  var _submitting = false;
  String? _message;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    final l10n = AppLocalizations.of(context);
    if (_requestKey.currentState?.validate() != true) return;
    if (_turnstileToken == null || _turnstileToken!.isEmpty) {
      setState(() => _error = l10n.turnstileRequired);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
      _message = null;
    });
    try {
      final challengeId = await sl<AuthRepository>().requestPasswordReset(
        email: _email.text.trim(),
        turnstileToken: _turnstileToken!,
      );
      if (!mounted) return;
      setState(() {
        _challengeId = challengeId;
        _step = _ForgotStep.confirm;
        _message = l10n.forgotPasswordCodeSent;
        _submitting = false;
      });
      await _turnstileKey.currentState?.reset();
    } on Failure catch (f) {
      if (!mounted) return;
      setState(() {
        _error = f.message;
        _submitting = false;
      });
      await _turnstileKey.currentState?.reset();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _submitting = false;
      });
      await _turnstileKey.currentState?.reset();
    }
  }

  Future<void> _confirmReset() async {
    final l10n = AppLocalizations.of(context);
    if (_confirmKey.currentState?.validate() != true) return;
    if (_turnstileToken == null || _turnstileToken!.isEmpty) {
      setState(() => _error = l10n.turnstileRequired);
      return;
    }
    final challengeId = _challengeId;
    if (challengeId == null || challengeId.isEmpty) {
      setState(() => _error = l10n.forgotPasswordMissingChallenge);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
      _message = null;
    });
    try {
      await sl<AuthRepository>().confirmPasswordReset(
        email: _email.text.trim(),
        challengeId: challengeId,
        code: _code.text.trim(),
        newPassword: _password.text,
        turnstileToken: _turnstileToken!,
      );
      if (!mounted) return;
      setState(() {
        _message = l10n.forgotPasswordDone;
        _step = _ForgotStep.request;
        _submitting = false;
      });
      await _turnstileKey.currentState?.reset();
    } on Failure catch (f) {
      if (!mounted) return;
      setState(() {
        _error = f.message;
        _submitting = false;
      });
      await _turnstileKey.currentState?.reset();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _submitting = false;
      });
      await _turnstileKey.currentState?.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(l10n.forgotPasswordTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const VaxiilLogo(height: 48),
          const SizedBox(height: 16),
          Text(
            l10n.forgotPasswordLede,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          SoftCard(
            child: _step == _ForgotStep.request
                ? _buildRequestForm(l10n)
                : _buildConfirmForm(l10n),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (_message != null) ...[
            const SizedBox(height: 12),
            Text(_message!),
          ],
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => context.go(AppRoutes.login),
            child: Text(l10n.forgotPasswordBackToLogin),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestForm(AppLocalizations l10n) {
    return Form(
      key: _requestKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(labelText: l10n.forgotPasswordEmail),
            validator: (v) {
              if (v == null || !v.contains('@')) {
                return l10n.forgotPasswordEmailRequired;
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TurnstileWidget(
            key: _turnstileKey,
            onToken: (token) => setState(() => _turnstileToken = token),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submitting || _turnstileToken == null
                ? null
                : _requestCode,
            child: _submitting
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.forgotPasswordSendCode),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmForm(AppLocalizations l10n) {
    return Form(
      key: _confirmKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _code,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: l10n.loginOtpCode),
            validator: (v) {
              if (v == null || v.trim().length < 6) {
                return l10n.loginOtpRequired;
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _password,
            obscureText: true,
            decoration: InputDecoration(
              labelText: l10n.forgotPasswordNewPassword,
            ),
            validator: (v) {
              if (v == null || v.length < 8) {
                return l10n.forgotPasswordPasswordShort;
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TurnstileWidget(
            key: _turnstileKey,
            onToken: (token) => setState(() => _turnstileToken = token),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submitting || _turnstileToken == null
                ? null
                : _confirmReset,
            child: _submitting
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.forgotPasswordReset),
          ),
        ],
      ),
    );
  }
}

enum _ForgotStep { request, confirm }
