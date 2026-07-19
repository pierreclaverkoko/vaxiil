import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vaxiil_mobile/core/constants/app_routes.dart';
import 'package:vaxiil_mobile/core/di/injection_container.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';
import 'package:vaxiil_mobile/core/locale/locale_manager.dart';
import 'package:vaxiil_mobile/features/auth/data/auth_metadata_models.dart';
import 'package:vaxiil_mobile/features/auth/data/legal_repository.dart';
import 'package:vaxiil_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vaxiil_mobile/features/auth/presentation/cubit/auth_state.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';
import 'package:vaxiil_mobile/shared/widgets/soft_card.dart';

/// Fetches current legal document body from the API for the active locale.
class LegalDocumentPage extends StatefulWidget {
  const LegalDocumentPage({
    required this.documentType,
    required this.title,
    super.key,
  });

  final String documentType;
  final String title;

  @override
  State<LegalDocumentPage> createState() => _LegalDocumentPageState();
}

class _LegalDocumentPageState extends State<LegalDocumentPage> {
  Object? _error;
  var _loading = true;
  String _body = '';
  String _summary = '';
  String _version = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final doc = await sl<LegalRepository>().fetchDocument(
        documentType: widget.documentType,
        languageCode: LocaleManager().languageCode,
      );
      if (!mounted) return;
      setState(() {
        _body = doc.body;
        _summary = doc.summary;
        _version = doc.version;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _error is Failure
                              ? (_error! as Failure).message
                              : _error.toString(),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_version.isNotEmpty)
                        Text(
                          'Version $_version',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                        ),
                      if (_summary.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          _summary,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        _body,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              height: 1.5,
                            ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalDocumentPage(
      documentType: 'terms',
      title: 'Terms of service',
    );
  }
}

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalDocumentPage(
      documentType: 'privacy',
      title: 'Privacy policy',
    );
  }
}

/// Blocking screen when profile `legal.needs_acceptance` is true.
class LegalAcceptancePage extends StatefulWidget {
  const LegalAcceptancePage({super.key});

  @override
  State<LegalAcceptancePage> createState() => _LegalAcceptancePageState();
}

class _LegalAcceptancePageState extends State<LegalAcceptancePage> {
  AuthMetadata? _metadata;
  Object? _loadError;
  var _loadingMetadata = true;
  var _accepted = false;

  @override
  void initState() {
    super.initState();
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    setState(() {
      _loadingMetadata = true;
      _loadError = null;
    });
    try {
      final metadata = await sl<AuthCubit>().fetchMetadata();
      if (!mounted) return;
      setState(() {
        _metadata = metadata;
        _loadingMetadata = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _loadingMetadata = false;
      });
    }
  }

  Future<void> _submit() async {
    final terms = _metadata?.termsVersion;
    final privacy = _metadata?.privacyVersion;
    if (terms == null || privacy == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Legal documents are unavailable.')),
      );
      return;
    }
    if (!_accepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept the updated legal terms.')),
      );
      return;
    }
    await context.read<AuthCubit>().acceptLegal(
          acceptedTermsVersion: terms,
          acceptedPrivacyVersion: privacy,
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listenWhen: (p, c) => p.errorMessage != c.errorMessage,
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!)),
          );
          context.read<AuthCubit>().clearError();
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Updated legal terms',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'We updated our Terms of Service and Privacy Policy. '
                      'Review them and accept to continue using Vaxiil.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                            height: 1.45,
                          ),
                    ),
                    const SizedBox(height: 24),
                    if (_loadingMetadata)
                      const Center(child: CircularProgressIndicator())
                    else if (_loadError != null)
                      Column(
                        children: [
                          Text(
                            _loadError is Failure
                                ? (_loadError! as Failure).message
                                : _loadError.toString(),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: _loadMetadata,
                            child: const Text('Retry'),
                          ),
                        ],
                      )
                    else ...[
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _accepted,
                        onChanged: (v) => setState(() => _accepted = v ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                        title: _legalAgreementText(context),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _submit,
                        child: const Text('Accept and continue'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => context.read<AuthCubit>().logout(),
                        child: const Text('Sign out'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _legalAgreementText(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    final linkStyle = style?.copyWith(
      color: Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
    );
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          const TextSpan(text: 'I agree to the '),
          TextSpan(
            text: 'Terms of Service',
            style: linkStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () => context.push(AppRoutes.terms),
          ),
          const TextSpan(text: ' and '),
          TextSpan(
            text: 'Privacy Policy',
            style: linkStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () => context.push(AppRoutes.privacy),
          ),
        ],
      ),
    );
  }
}

/// Checkbox + links for registration.
class LegalAgreementCheckbox extends StatelessWidget {
  const LegalAgreementCheckbox({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final bool value;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    final linkStyle = style?.copyWith(
      color: Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
    );
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: onChanged,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text.rich(
        TextSpan(
          style: style,
          children: [
            const TextSpan(text: 'I agree to the '),
            TextSpan(
              text: 'Terms of Service',
              style: linkStyle,
              recognizer: TapGestureRecognizer()
                ..onTap = () => context.push(AppRoutes.terms),
            ),
            const TextSpan(text: ' and '),
            TextSpan(
              text: 'Privacy Policy',
              style: linkStyle,
              recognizer: TapGestureRecognizer()
                ..onTap = () => context.push(AppRoutes.privacy),
            ),
          ],
        ),
      ),
    );
  }
}
