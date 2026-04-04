import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';

/// Placeholder until legal copy is finalized.
class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: HeroIcon(
            HeroIcons.arrowLeft,
            style: HeroIconStyle.outline,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => context.pop(),
        ),
        title: const Text('Terms of service'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Text(
          'Terms of service will appear here. This is a placeholder. '
          'Contact support if you need legal documents before they are published.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

/// Placeholder until privacy policy copy is finalized.
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: HeroIcon(
            HeroIcons.arrowLeft,
            style: HeroIconStyle.outline,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => context.pop(),
        ),
        title: const Text('Privacy policy'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Text(
          'Privacy policy will appear here. This is a placeholder. '
          'We take your data seriously; full policy text is coming soon.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
