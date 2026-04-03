import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:vaxiil_mobile/core/constants/app_routes.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';
import 'package:vaxiil_mobile/shared/widgets/soft_card.dart';

class BusinessPage extends StatelessWidget {
  const BusinessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Business')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SoftCard(
            child: ListTile(
              leading: HeroIcon(
                HeroIcons.buildingOffice2,
                style: HeroIconStyle.outline,
                color: AppTheme.primaryVariant,
                size: 32,
              ),
              title: Text(
                'Organizations',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: const Text('List, register, and manage businesses'),
              trailing: HeroIcon(
                HeroIcons.chevronRight,
                style: HeroIconStyle.outline,
                color: AppTheme.textSecondary,
              ),
              onTap: () => context.push(AppRoutes.businessList),
            ),
          ),
        ],
      ),
    );
  }
}
