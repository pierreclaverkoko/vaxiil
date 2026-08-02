import 'package:flutter/material.dart';
import 'package:vaxiil_mobile/core/di/injection_container.dart';
import 'package:vaxiil_mobile/features/business/data/organization_repository.dart';
import 'package:vaxiil_mobile/l10n/app_localizations.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';

class BusinessSettlementPage extends StatefulWidget {
  const BusinessSettlementPage({required this.organizationId, super.key});

  final String organizationId;

  @override
  State<BusinessSettlementPage> createState() => _BusinessSettlementPageState();
}

class _BusinessSettlementPageState extends State<BusinessSettlementPage> {
  bool _loading = true;
  String? _error;
  String? _actionError;
  List<Map<String, dynamic>> _balances = const [];
  List<Map<String, dynamic>> _accounts = const [];
  List<Map<String, dynamic>> _requests = const [];
  Map<String, dynamic>? _settings;
  String _periodicity = 'N';
  final _minimumCtrl = TextEditingController(text: '10');
  final _identifierCtrl = TextEditingController();
  final _accountNameCtrl = TextEditingController();
  final _requestAmountCtrl = TextEditingController();
  String? _requestAccountId;
  Map<String, dynamic>? _selectedMethod;
  bool _addingAccount = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _minimumCtrl.dispose();
    _identifierCtrl.dispose();
    _accountNameCtrl.dispose();
    _requestAmountCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = sl<OrganizationRepository>();
      final results = await Future.wait([
        repo.settlementBalances(widget.organizationId),
        repo.settlementAccounts(widget.organizationId),
        repo.settlementSettings(widget.organizationId),
        repo.settlementRequests(widget.organizationId),
      ]);
      final settings = results[2] as Map<String, dynamic>;
      final accounts = results[1] as List<Map<String, dynamic>>;
      final periodicity = settings['periodicity'];
      String period = 'N';
      if (periodicity is Map && periodicity['value'] != null) {
        period = periodicity['value'].toString();
      } else if (periodicity != null) {
        period = periodicity.toString();
      }
      if (!mounted) return;
      setState(() {
        _balances = results[0] as List<Map<String, dynamic>>;
        _accounts = accounts;
        _settings = settings;
        _requests = results[3] as List<Map<String, dynamic>>;
        _periodicity = period;
        _minimumCtrl.text = settings['minimum_amount']?.toString() ?? '10';
        _requestAccountId =
            accounts.isNotEmpty ? accounts.first['id']?.toString() : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    try {
      await sl<OrganizationRepository>().updateSettlementSettings(
        widget.organizationId,
        {
          'periodicity': _periodicity,
          'minimum_amount': _minimumCtrl.text.trim(),
        },
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionError = e.toString());
    }
  }

  Future<void> _openMethodPicker() async {
    try {
      final methods = await sl<OrganizationRepository>().listPaymentMethods(
        operation: 'settlement',
      );
      if (!mounted) return;
      final picked = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) {
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.7,
              child: ListView.builder(
                itemCount: methods.length,
                itemBuilder: (context, i) {
                  final m = methods[i];
                  final name =
                      m['name']?.toString() ?? m['code']?.toString() ?? '';
                  final logo = m['logo_url']?.toString();
                  return ListTile(
                    leading: logo != null && logo.isNotEmpty
                        ? Image.network(logo, width: 40, height: 40)
                        : CircleAvatar(
                            child: Text(name.isNotEmpty ? name[0] : '?'),
                          ),
                    title: Text(name),
                    subtitle: Text(m['code']?.toString() ?? ''),
                    onTap: () => Navigator.pop(ctx, m),
                  );
                },
              ),
            ),
          );
        },
      );
      if (picked != null && mounted) {
        setState(() {
          _selectedMethod = picked;
          _addingAccount = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionError = e.toString());
    }
  }

  Future<void> _addAccount() async {
    final method = _selectedMethod;
    final identifier = _identifierCtrl.text.trim();
    if (method == null || identifier.isEmpty) return;
    try {
      await sl<OrganizationRepository>().createSettlementAccount(
        widget.organizationId,
        {
          'method_id': method['id'],
          'account_identifier': identifier,
          'account_name': _accountNameCtrl.text.trim(),
          'details': <String, dynamic>{},
          'is_default': _accounts.isEmpty,
          'label': method['name']?.toString() ?? '',
        },
      );
      _identifierCtrl.clear();
      _accountNameCtrl.clear();
      if (!mounted) return;
      setState(() {
        _selectedMethod = null;
        _addingAccount = false;
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionError = e.toString());
    }
  }

  Future<void> _requestSettlement() async {
    final amount = _requestAmountCtrl.text.trim();
    final accountId = _requestAccountId;
    if (amount.isEmpty || accountId == null) return;
    try {
      final currency = _balances.isNotEmpty
          ? _balances.first['currency_code']?.toString()
          : _settings?['currency_code']?.toString();
      await sl<OrganizationRepository>().createSettlementRequest(
        widget.organizationId,
        amount: amount,
        accountId: accountId,
        currencyCode: currency,
      );
      _requestAmountCtrl.clear();
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _actionError = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(l10n.businessSettlementTitle),
        backgroundColor: AppTheme.backgroundColor,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      l10n.businessSettlementLede,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                    if (_actionError != null) ...[
                      const SizedBox(height: 12),
                      Text(_actionError!, style: TextStyle(color: cs.error)),
                    ],
                    const SizedBox(height: 20),
                    Text(
                      l10n.businessSettlementBalance,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    if (_balances.isEmpty)
                      Text(l10n.businessSettlementNoBalance)
                    else
                      ..._balances.map(
                        (b) => Text(
                          '${b['currency_code']}: ${b['available']} '
                          '(${l10n.businessSettlementLedgerBalance} ${b['balance']})',
                        ),
                      ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.businessSettlementSettings,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _periodicity,
                      decoration: InputDecoration(
                        labelText: l10n.businessSettlementPeriodicity,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'W',
                          child: Text(l10n.businessSettlementWeekly),
                        ),
                        DropdownMenuItem(
                          value: 'B',
                          child: Text(l10n.businessSettlementBiweekly),
                        ),
                        DropdownMenuItem(
                          value: 'M',
                          child: Text(l10n.businessSettlementMonthly),
                        ),
                        DropdownMenuItem(
                          value: 'N',
                          child: Text(l10n.businessSettlementManual),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _periodicity = v);
                        _saveSettings();
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _minimumCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: l10n.businessSettlementMinimum,
                      ),
                      onEditingComplete: _saveSettings,
                    ),
                    if (_settings?['minimum_floor'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '${l10n.businessSettlementMinimumFloor}: '
                          '${_settings!['minimum_floor']}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.businessSettlementAccounts,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    if (_accounts.isEmpty)
                      Text(l10n.businessSettlementNoAccounts)
                    else
                      ..._accounts.map((a) {
                        final method = a['method'];
                        final methodTitle = method is Map
                            ? (method['name'] ?? method['code'])?.toString()
                            : method?.toString();
                        final dest = a['account_identifier'] ??
                            a['label'] ??
                            '';
                        final logo = method is Map
                            ? method['logo_url']?.toString()
                            : null;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: logo != null && logo.isNotEmpty
                              ? Image.network(logo, width: 32, height: 32)
                              : null,
                          title: Text('$methodTitle — $dest'),
                        );
                      }),
                    if (_addingAccount && _selectedMethod != null) ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(_selectedMethod!['name']?.toString() ?? ''),
                        subtitle: Text(_selectedMethod!['code']?.toString() ?? ''),
                      ),
                      TextField(
                        controller: _identifierCtrl,
                        decoration: InputDecoration(
                          labelText: l10n.businessSettlementEmail,
                        ),
                      ),
                      TextField(
                        controller: _accountNameCtrl,
                        decoration: InputDecoration(
                          labelText: l10n.businessSettlementHolder,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton(
                          onPressed: _addAccount,
                          child: Text(l10n.businessSettlementAddAccount),
                        ),
                      ),
                    ] else
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton(
                          onPressed: _openMethodPicker,
                          child: Text(l10n.businessSettlementAddAccount),
                        ),
                      ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.businessSettlementManualRequest,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _requestAmountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: l10n.businessSettlementMinimum,
                      ),
                    ),
                    if (_accounts.isNotEmpty)
                      DropdownButtonFormField<String>(
                        value: _requestAccountId,
                        items: _accounts
                            .map(
                              (a) => DropdownMenuItem(
                                value: a['id']?.toString(),
                                child: Text(
                                  (a['account_identifier'] ??
                                          a['label'] ??
                                          a['id'])
                                      .toString(),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _requestAccountId = v),
                      ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _requestSettlement,
                      child: Text(l10n.businessSettlementRequest),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.businessSettlementHistory,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    if (_requests.isEmpty)
                      Text(l10n.businessSettlementNoRequests)
                    else
                      ..._requests.map((r) {
                        final status = r['status'];
                        final statusTitle = status is Map
                            ? status['title']?.toString()
                            : status?.toString();
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${r['amount']} ${r['currency_code']} — $statusTitle',
                          ),
                        );
                      }),
                  ],
                ),
    );
  }
}
