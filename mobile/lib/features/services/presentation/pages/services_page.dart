import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';

class ServicesPage extends StatelessWidget {
  const ServicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Services')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HeroIcon(
              HeroIcons.magnifyingGlass,
              style: HeroIconStyle.outline,
              size: 64,
              color: AppTheme.primaryVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Browse services',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Search and book wellness experiences',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
