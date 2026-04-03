import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';
import 'package:vaxiil_mobile/shared/widgets/soft_card.dart';

class BusinessProfilePage extends StatelessWidget {
  const BusinessProfilePage({super.key, this.organizationId});

  final String? organizationId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Business profile'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  HeroIcon(
                    HeroIcons.buildingOffice2,
                    style: HeroIconStyle.outline,
                    color: AppTheme.primaryVariant,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      organizationId != null
                          ? 'Organization $organizationId'
                          : 'Organization',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Details load from the organizations API when connected.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
