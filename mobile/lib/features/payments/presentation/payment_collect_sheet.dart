import 'package:flutter/material.dart';

import 'package:vaxiil_mobile/core/di/injection_container.dart';
import 'package:vaxiil_mobile/features/business/data/organization_repository.dart';
import 'package:vaxiil_mobile/l10n/app_localizations.dart';

/// Simple collect / wallet-fund sheet: pick a method + phone.
Future<({String methodId, String phone, String? accountName})?>
    showPaymentCollectSheet(
  BuildContext context, {
  required String operation,
}) async {
  final l10n = AppLocalizations.of(context);
  List<Map<String, dynamic>> methods = [];
  try {
    methods = await sl<OrganizationRepository>().listPaymentMethods(
      operation: operation,
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.paymentMethodsLoadError)),
      );
    }
    return null;
  }
  if (!context.mounted || methods.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.paymentMethodsEmpty)),
      );
    }
    return null;
  }

  String? selectedId = methods.first['id']?.toString();
  final phoneCtrl = TextEditingController();
  final nameCtrl = TextEditingController();

  final result = await showModalBottomSheet<
      ({String methodId, String phone, String? accountName})>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.viewInsetsOf(ctx).bottom + 20,
        ),
        child: StatefulBuilder(
          builder: (ctx, setLocal) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.paymentCollectTitle,
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedId,
                  items: [
                    for (final m in methods)
                      DropdownMenuItem(
                        value: m['id']?.toString(),
                        child: Text(
                          m['name']?.toString() ??
                              m['code']?.toString() ??
                              '',
                        ),
                      ),
                  ],
                  onChanged: (v) => setLocal(() => selectedId = v),
                  decoration: InputDecoration(
                    labelText: l10n.paymentMethodLabel,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: l10n.paymentPhoneLabel,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.paymentAccountNameLabel,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    final id = selectedId;
                    final phone = phoneCtrl.text.trim();
                    if (id == null || id.isEmpty || phone.isEmpty) {
                      return;
                    }
                    Navigator.of(ctx).pop((
                      methodId: id,
                      phone: phone,
                      accountName: nameCtrl.text.trim().isEmpty
                          ? null
                          : nameCtrl.text.trim(),
                    ));
                  },
                  child: Text(l10n.paymentCollectSubmit),
                ),
              ],
            );
          },
        ),
      );
    },
  );
  phoneCtrl.dispose();
  nameCtrl.dispose();
  return result;
}
