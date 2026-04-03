import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:vaxiil_mobile/core/constants/app_routes.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';
import 'package:vaxiil_mobile/shared/widgets/soft_card.dart';

class BusinessListPage extends StatelessWidget {
  const BusinessListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your businesses'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SoftCard(
            child: ListTile(
              leading: HeroIcon(
                HeroIcons.plusCircle,
                style: HeroIconStyle.outline,
                color: AppTheme.primaryVariant,
              ),
              title: Text(
                'Register a business',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: const Text('Create an organization profile'),
              onTap: () => context.push(AppRoutes.businessSetup),
            ),
          ),
          const SizedBox(height: 12),
          SoftCard(
            child: ListTile(
              leading: HeroIcon(
                HeroIcons.buildingOffice2,
                style: HeroIconStyle.outline,
                color: AppTheme.primaryVariant,
              ),
              title: Text(
                'Manage businesses',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: const Text('Open organization tools from the Business tab'),
              onTap: () => context.go(AppRoutes.business),
            ),
          ),
        ],
      ),
    );
  }
}
