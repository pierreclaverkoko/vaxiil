import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:vaxiil_mobile/core/di/injection_container.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';
import 'package:vaxiil_mobile/features/business/data/organization_models.dart';
import 'package:vaxiil_mobile/features/business/data/organization_repository.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';
import 'package:vaxiil_mobile/shared/utils/responsive.dart';
import 'package:vaxiil_mobile/shared/widgets/choice_enum_widget.dart';
import 'package:vaxiil_mobile/shared/widgets/soft_card.dart';
import 'package:vaxiil_mobile/shared/widgets/vaxiil_site_footer.dart';

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

  void _refresh() {
    setState(() {
      _future = sl<OrganizationRepository>().team(widget.organizationId);
    });
  }

  Future<void> _invite() async {
    final email = TextEditingController();
    var role = 'T';
    final values = await showDialog<(String, String)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Invite team member'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email address'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'O', child: Text('Owner')),
                  DropdownMenuItem(value: 'A', child: Text('Admin')),
                  DropdownMenuItem(value: 'M', child: Text('Manager')),
                  DropdownMenuItem(value: 'T', child: Text('Staff')),
                  DropdownMenuItem(value: 'C', child: Text('Cashier')),
                  DropdownMenuItem(value: 'D', child: Text('Delivery')),
                ],
                onChanged: (value) => setDialogState(() => role = value!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, (email.text.trim(), role)),
              child: const Text('Invite'),
            ),
          ],
        ),
      ),
    );
    email.dispose();
    if (values == null || values.$1.isEmpty) return;
    try {
      await sl<OrganizationRepository>().inviteTeamMember(
        widget.organizationId,
        email: values.$1,
        role: values.$2,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitation sent')),
      );
      _refresh();
    } catch (e) {
      if (!mounted) return;
      final message = e is Failure ? e.message : e.toString();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team'),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _invite,
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Invite'),
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
          return CustomScrollView(
            slivers: [
              if (members.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ResponsiveContent(
                    maxWidth: 1280,
                    child: Center(
                      child: Text(
                        'No team members yet',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ),
                )
              else
                SliverToBoxAdapter(
                  child: ResponsiveContent(
                    maxWidth: 1280,
                    padding: const EdgeInsets.all(16),
                    child: context.isMdUp
                        ? GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 8,
                              childAspectRatio: 2.6,
                            ),
                            itemCount: members.length,
                            itemBuilder: (context, i) =>
                                _memberCard(context, members[i]),
                          )
                        : Column(
                            children: [
                              for (var i = 0; i < members.length; i++) ...[
                                if (i > 0) const SizedBox(height: 8),
                                _memberCard(context, members[i]),
                              ],
                            ],
                          ),
                  ),
                ),
              const SliverToBoxAdapter(child: VaxiilSiteFooter()),
            ],
          );
        },
      ),
    );
  }

  Widget _memberCard(BuildContext context, TeamMemberModel m) {
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
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            try {
              final repo = sl<OrganizationRepository>();
              if (value == 'remove') {
                await repo.removeTeamMember(widget.organizationId, m.id);
              } else {
                await repo.updateTeamMemberRole(
                  widget.organizationId,
                  m.id,
                  role: value,
                );
              }
              if (mounted) _refresh();
            } catch (e) {
              if (!mounted) return;
              final message = e is Failure ? e.message : e.toString();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(message)),
              );
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'O', child: Text('Make owner')),
            PopupMenuItem(value: 'A', child: Text('Make admin')),
            PopupMenuItem(value: 'M', child: Text('Make manager')),
            PopupMenuItem(value: 'T', child: Text('Make staff')),
            PopupMenuDivider(),
            PopupMenuItem(value: 'remove', child: Text('Remove')),
          ],
        ),
      ),
    );
  }
}
