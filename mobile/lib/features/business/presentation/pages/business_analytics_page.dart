import 'package:flutter/material.dart';
import 'package:vaxiil_mobile/core/di/injection_container.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';
import 'package:vaxiil_mobile/features/business/data/organization_models.dart';
import 'package:vaxiil_mobile/features/business/data/organization_repository.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';
import 'package:vaxiil_mobile/shared/utils/responsive.dart';
import 'package:vaxiil_mobile/shared/widgets/soft_card.dart';
import 'package:vaxiil_mobile/shared/widgets/vaxiil_site_footer.dart';

class BusinessAnalyticsPage extends StatefulWidget {
  const BusinessAnalyticsPage({required this.organizationId, super.key});

  final String organizationId;

  @override
  State<BusinessAnalyticsPage> createState() => _BusinessAnalyticsPageState();
}

class _BusinessAnalyticsPageState extends State<BusinessAnalyticsPage> {
  late Future<OrganizationAnalyticsModel> _future;

  @override
  void initState() {
    super.initState();
    _future = sl<OrganizationRepository>().analytics(widget.organizationId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
      ),
      body: FutureBuilder<OrganizationAnalyticsModel>(
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
          final analytics = snapshot.data!;
          return ListView(
            children: [
              ResponsiveContent(
                maxWidth: 1280,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      'Performance insights',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primaryVariant,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Track bookings, revenue, and engagement for your wellness sanctuary.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 24),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = context.isMdUp ? 3 : 1;
                        final revenueLabel =
                            '${analytics.revenue} ${analytics.currency ?? ''}'
                                .trim();
                        final kpis = [
                          _AnalyticsKpi(
                            label: 'Total bookings',
                            value: '${analytics.totalBookings}',
                            trend: analytics.totalBookings > 0
                                ? 'Active pipeline'
                                : 'Awaiting data',
                            icon: Icons.event_available_outlined,
                          ),
                          _AnalyticsKpi(
                            label: 'Total revenue',
                            value: revenueLabel,
                            trend:
                                analytics.revenue != '0' ? 'Live totals' : '—',
                            icon: Icons.payments_outlined,
                          ),
                          _AnalyticsKpi(
                            label: 'Completed bookings',
                            value: '${analytics.completedBookings}',
                            trend: 'Live booking status',
                            icon: Icons.analytics_outlined,
                          ),
                        ];

                        if (columns == 1) {
                          return Column(
                            children: [
                              for (final kpi in kpis) ...[
                                _KpiCard(kpi: kpi),
                                const SizedBox(height: 16),
                              ],
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var i = 0; i < kpis.length; i++) ...[
                              if (i > 0) const SizedBox(width: 16),
                              Expanded(child: _KpiCard(kpi: kpis[i])),
                            ],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    _BookingsBreakdownCard(analytics: analytics),
                    const SizedBox(height: 24),
                    if (analytics.note != null)
                      Text(
                        analytics.note!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              const VaxiilSiteFooter(),
            ],
          );
        },
      ),
    );
  }
}

class _AnalyticsKpi {
  const _AnalyticsKpi({
    required this.label,
    required this.value,
    required this.trend,
    required this.icon,
  });

  final String label;
  final String value;
  final String trend;
  final IconData icon;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.kpi});

  final _AnalyticsKpi kpi;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Stack(
        children: [
          Positioned(
            right: -8,
            bottom: -8,
            child: Icon(
              kpi.icon,
              size: 96,
              color: AppTheme.primaryVariant.withOpacity(0.06),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                kpi.label.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                kpi.value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryVariant,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                kpi.trend,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: const Color(0xFFF57C00),
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BookingsBreakdownCard extends StatelessWidget {
  const _BookingsBreakdownCard({required this.analytics});

  final OrganizationAnalyticsModel analytics;

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Confirmed', analytics.confirmedBookings),
      ('Completed', analytics.completedBookings),
      ('Cancelled', analytics.cancelledBookings),
    ];
    final maxValue =
        rows.map((r) => r.$2).fold<int>(0, (a, b) => a > b ? a : b);

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Booking breakdown',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 20),
          for (final row in rows) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    row.$1,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                Text(
                  '${row.$2}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppTheme.primaryVariant,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: maxValue == 0 ? 0 : row.$2 / maxValue,
                minHeight: 10,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                color: AppTheme.primaryVariant,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}
