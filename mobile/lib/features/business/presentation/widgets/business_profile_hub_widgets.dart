import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:vaxiil_mobile/core/constants/app_constants.dart';
import 'package:vaxiil_mobile/core/constants/app_routes.dart';
import 'package:vaxiil_mobile/features/business/data/organization_models.dart';
import 'package:vaxiil_mobile/l10n/app_localizations.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';

/// Stitch “Company Hub”: centered hero on white, role chip, description, chips.
class VerifiedCompanyHero extends StatelessWidget {
  const VerifiedCompanyHero({required this.org, super.key});

  final OrganizationModel org;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final roleLabel = org.myMembershipRole?.title ?? 'Member';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.editorialShadow,
      ),
      child: Column(
        children: [
          _HeroLogo(logoUrl: org.logoUrl),
          const SizedBox(height: 20),
          Text(
            org.name,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.primary,
                ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$roleLabel View',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: cs.onPrimaryContainer,
                  ),
            ),
          ),
          const SizedBox(height: 14),
          if (org.description != null && org.description!.trim().isNotEmpty)
            Text(
              org.description!.trim(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                    height: 1.45,
                  ),
            ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (org.city.isNotEmpty)
                _InfoChip(
                  icon: Icons.location_on_outlined,
                  label: org.city,
                ),
              if (org.website != null && org.website!.trim().isNotEmpty)
                _InfoChip(
                  icon: Icons.language,
                  label: org.website!.trim(),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroLogo extends StatelessWidget {
  const _HeroLogo({this.logoUrl});

  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final u = logoUrl?.trim();
    return Container(
      width: 112,
      height: 112,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: cs.surfaceContainerHigh,
        boxShadow: AppTheme.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: u != null && u.isNotEmpty
          ? Image.network(
              u,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(
                Icons.business,
                size: 48,
                color: cs.primary,
              ),
            )
          : Icon(
              Icons.business,
              size: 48,
              color: cs.primary,
            ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Stitch balanced row: Members, Services, Bookings, More.
class VerifiedHubQuickActions extends StatelessWidget {
  const VerifiedHubQuickActions({
    required this.organizationId,
    super.key,
  });

  final String organizationId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: _HubCircleAction(
              label: 'Members',
              icon: Icons.group_outlined,
              background: cs.primaryContainer,
              foreground: cs.onPrimaryContainer,
              onTap: () => context.push(
                '${AppRoutes.businessPractitioners}?id=$organizationId',
              ),
            ),
          ),
          Expanded(
            child: _HubCircleAction(
              label: 'Services',
              icon: Icons.spa_outlined,
              background: cs.secondaryContainer,
              foreground: cs.onSecondaryContainer,
              onTap: () => context.push(
                '${AppRoutes.businessServices}?id=$organizationId',
              ),
            ),
          ),
          Expanded(
            child: _HubCircleAction(
              label: 'Bookings',
              icon: Icons.event_available_outlined,
              background: cs.primary.withOpacity(0.1),
              foreground: cs.primary,
              onTap: () => context.push(
                '${AppRoutes.businessBookings}?id=$organizationId',
              ),
            ),
          ),
          Expanded(
            child: _HubCircleAction(
              label: 'More',
              icon: Icons.grid_view_outlined,
              background: cs.surfaceContainerHighest,
              foreground: cs.onSurfaceVariant,
              onTap: () => _openMoreSheet(context, organizationId),
            ),
          ),
        ],
      ),
    );
  }

  void _openMoreSheet(BuildContext context, String organizationId) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AppLocalizations.of(ctx).businessHubMoreTitle,
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Theme.of(ctx).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(ctx).colorScheme.primaryContainer,
                    child: Icon(
                      Icons.settings_outlined,
                      color: Theme.of(ctx).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  title: Text(AppLocalizations.of(ctx).businessHubSettings),
                  subtitle: Text(
                    AppLocalizations.of(ctx).businessHubSettingsSubtitle,
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push(
                      '${AppRoutes.businessSettings}?id=$organizationId',
                    );
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        Theme.of(ctx).colorScheme.secondaryContainer,
                    child: Icon(
                      Icons.analytics_outlined,
                      color: Theme.of(ctx).colorScheme.onSecondaryContainer,
                    ),
                  ),
                  title: Text(AppLocalizations.of(ctx).businessHubAnalytics),
                  subtitle: Text(
                    AppLocalizations.of(ctx).businessHubAnalyticsSubtitle,
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push(
                      '${AppRoutes.businessAnalytics}?id=$organizationId',
                    );
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(ctx).colorScheme.tertiaryContainer,
                    child: Icon(
                      Icons.chat_bubble_outline,
                      color: Theme.of(ctx).colorScheme.onTertiaryContainer,
                    ),
                  ),
                  title: Text(AppLocalizations.of(ctx).businessHubMessages),
                  subtitle: Text(
                    AppLocalizations.of(ctx).businessHubMessagesSubtitle,
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push(
                      '${AppRoutes.businessMessages}?id=$organizationId',
                    );
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.notifications_outlined,
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  title: Text(AppLocalizations.of(ctx).businessHubNotifications),
                  subtitle: Text(
                    AppLocalizations.of(ctx).businessHubNotificationsSubtitle,
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push(
                      '${AppRoutes.businessNotifications}?id=$organizationId',
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HubCircleAction extends StatelessWidget {
  const _HubCircleAction({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: background,
                  shape: BoxShape.circle,
                  boxShadow: AppTheme.cardShadow,
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: foreground, size: 28),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
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

/// Orange KYB pending banner + optional support action.
class KybPendingBanner extends StatelessWidget {
  const KybPendingBanner({super.key});

  static const Color _sunset = Color(0xFFFB8C00);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.editorialShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0x1FFB8C00),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.schedule, color: _sunset, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KYB PENDING VERIFICATION',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: _sunset,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'We are reviewing your documents. This usually takes '
                      '24–48 hours.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () async {
                await Clipboard.setData(
                  const ClipboardData(text: AppConstants.supportEmail),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Copied ${AppConstants.supportEmail} to clipboard',
                      ),
                    ),
                  );
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: _sunset,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
              child: const Text('Priority support'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hero for KYB not sent — Stitch “Verification Required”.
class KybNotSentHero extends StatelessWidget {
  const KybNotSentHero({super.key});

  static const Color _sunset = Color(0xFFFB8C00);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.editorialShadow,
      ),
      child: Stack(
        children: [
          Positioned(
            right: -24,
            top: -24,
            child: Icon(
              Icons.blur_circular,
              size: 120,
              color: cs.primary.withOpacity(0.12),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _sunset.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Action required',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: _sunset,
                            ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Verification required',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your account is in KYB NOT SENT status. Complete '
                      'business verification to unlock payments, team '
                      'management, and analytics.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                            height: 1.45,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.domain_verification_outlined,
                  size: 44,
                  color: _sunset,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Read-only business fields (Stitch business information panels).
class BusinessInfoReadOnlyCard extends StatelessWidget {
  const BusinessInfoReadOnlyCard({required this.org, super.key});

  final OrganizationModel org;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.editorialShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Business information',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.primary,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Keep your professional identity up to date',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
          const SizedBox(height: 20),
          _ReadOnlyField(label: 'Business name', value: org.name),
          _ReadOnlyField(label: 'Email', value: org.email),
          if (org.phone != null && org.phone!.isNotEmpty)
            _ReadOnlyField(label: 'Phone', value: org.phone!),
          _ReadOnlyField(
            label: 'Address',
            value:
                '${org.address}, ${org.city} ${org.postalCode}, ${org.country}',
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

/// Grayed 2×2 grid with lock overlay (Stitch locked management).
class LockedManagementGrid extends StatelessWidget {
  const LockedManagementGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Business management',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.primary,
                  ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '4 modules restricted',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: cs.outline,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _LockedTile(
                label: 'Services',
                icon: HeroIcons.sparkles,
                caption: 'Offerings and plans',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _LockedTile(
                label: 'Bookings',
                icon: HeroIcons.calendarDays,
                caption: 'Calendar and clients',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _LockedTile(
                label: 'Team',
                icon: HeroIcons.userGroup,
                caption: 'Staff and roles',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _LockedTile(
                label: 'Settings',
                icon: HeroIcons.cog6Tooth,
                caption: 'Organization setup',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LockedTile extends StatelessWidget {
  const _LockedTile({
    required this.label,
    required this.icon,
    required this.caption,
  });

  final String label;
  final HeroIcons icon;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withOpacity(0.65),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Opacity(
            opacity: 0.45,
            child: ColorFiltered(
              colorFilter: const ColorFilter.matrix(<double>[
                0.2126,
                0.7152,
                0.0722,
                0,
                0,
                0.2126,
                0.7152,
                0.0722,
                0,
                0,
                0.2126,
                0.7152,
                0.0722,
                0,
                0,
                0,
                0,
                0,
                1,
                0,
              ]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withOpacity(0.35),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: HeroIcon(
                      icon,
                      style: HeroIconStyle.outline,
                      color: cs.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    caption,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.outline,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: Tooltip(
              message: 'Unlocks after verification',
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {},
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(Icons.lock_outline, color: cs.outline),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
