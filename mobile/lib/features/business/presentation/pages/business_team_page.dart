import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:vaxiil_mobile/core/di/injection_container.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';
import 'package:vaxiil_mobile/features/business/data/organization_models.dart';
import 'package:vaxiil_mobile/features/business/data/organization_repository.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';
import 'package:vaxiil_mobile/shared/widgets/choice_enum_widget.dart';
import 'package:vaxiil_mobile/shared/widgets/soft_card.dart';

class BusinessTeamPage extends StatefulWidget {
  const BusinessTeamPage({required this.organizationId, super.key});

  final String organizationId;

  @override
  State<BusinessTeamPage> createState() => _BusinessTeamPageState();
}

class _BusinessTeamPageState extends State<BusinessTeamPage> {
  late Future<List<TeamMemberModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = sl<OrganizationRepository>().team(widget.organizationId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team'),
      ),
      body: FutureBuilder<List<TeamMemberModel>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final msg = snapshot.error is Failure
                ? (snapshot.error! as Failure).message
                : snapshot.error.toString();
            return Center(child: Text(msg));
          }
          final members = snapshot.data ?? [];
          if (members.isEmpty) {
            return Center(
              child: Text(
                'No team members yet',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: members.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final m = members[i];
              return SoftCard(
                child: ListTile(
                  leading: const HeroIcon(
                    HeroIcons.user,
                    style: HeroIconStyle.outline,
                    color: AppTheme.primaryVariant,
                  ),
                  title: Text(m.displayName),
                  subtitle: Row(
                    children: [
                      if (m.membershipRole != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceEnumWidget(choice: m.membershipRole),
                        )
                      else if (m.role != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceEnumWidget(choice: m.role),
                        ),
                      Expanded(
                        child: Text(
                          m.email,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
