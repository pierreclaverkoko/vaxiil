import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';

class BookingsPage extends StatelessWidget {
  const BookingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bookings')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HeroIcon(
              HeroIcons.calendarDays,
              style: HeroIconStyle.outline,
              size: 64,
              color: AppTheme.primaryVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Your bookings',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Manage appointments and sessions',
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
