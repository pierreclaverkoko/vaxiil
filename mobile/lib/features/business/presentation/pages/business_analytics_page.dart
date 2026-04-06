import 'package:flutter/material.dart';
import 'package:vaxiil_mobile/core/di/injection_container.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';
import 'package:vaxiil_mobile/features/business/data/organization_models.dart';
import 'package:vaxiil_mobile/features/business/data/organization_repository.dart';
import 'package:vaxiil_mobile/features/business/presentation/widgets/organization_analytics_summary.dart';

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
          final a = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              OrganizationAnalyticsSummary(
                organizationId: widget.organizationId,
                analytics: a,
                showDetailsButton: false,
              ),
            ],
          );
        },
      ),
    );
  }
}
