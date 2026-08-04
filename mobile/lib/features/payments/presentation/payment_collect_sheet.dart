import 'package:flutter/material.dart';

import 'package:vaxiil_mobile/core/di/injection_container.dart';
import 'package:vaxiil_mobile/core/errors/display_error.dart';
import 'package:vaxiil_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vaxiil_mobile/features/business/data/organization_models.dart';
import 'package:vaxiil_mobile/features/business/data/organization_repository.dart';
import 'package:vaxiil_mobile/l10n/app_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Stepped collect / wallet-fund sheet:
/// category → method (+ country) → amount/account → confirm.
///
/// Record field [phone] holds the resolved account identifier (phone/email/generic).
Future<({String methodId, String phone, String? accountName, String? currencyCode, String? amount})?>
    showPaymentCollectSheet(
  BuildContext context, {
  required String operation,
  String? countryId,
  String? fixedCurrencyCode,
  bool showAmount = false,
  String? initialAmount,
}) async {
  final l10n = AppLocalizations.of(context);
  final repo = sl<OrganizationRepository>();

  List<CountryBriefModel> countries = const [];
  try {
    countries = await repo.listCountries();
  } catch (_) {
    countries = const [];
  }

  String? authCountry;
  try {
    authCountry = context.read<AuthCubit>().state.user?.defaultCountryId;
  } catch (_) {
    authCountry = null;
  }
  final initialCountry = (countryId ?? authCountry ?? '').trim();

  if (!context.mounted) return null;

  return showModalBottomSheet<
      ({
        String methodId,
        String phone,
        String? accountName,
        String? currencyCode,
        String? amount,
      })>(
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
        child: _PaymentWizard(
          operation: operation,
          countries: countries,
          initialCountryId: initialCountry,
          fixedCurrencyCode: fixedCurrencyCode,
          showAmount: showAmount,
          initialAmount: initialAmount,
          l10n: l10n,
        ),
      );
    },
  );
}

class _PaymentWizard extends StatefulWidget {
  const _PaymentWizard({
    required this.operation,
    required this.countries,
    required this.initialCountryId,
    required this.fixedCurrencyCode,
    required this.showAmount,
    required this.initialAmount,
    required this.l10n,
  });

  final String operation;
  final List<CountryBriefModel> countries;
  final String initialCountryId;
  final String? fixedCurrencyCode;
  final bool showAmount;
  final String? initialAmount;
  final AppLocalizations l10n;

  @override
  State<_PaymentWizard> createState() => _PaymentWizardState();
}

class _PaymentWizardState extends State<_PaymentWizard> {
  static const _categories = <(String, String, IconData)>[
    ('B', 'Bank', Icons.account_balance_outlined),
    ('M', 'Mobile money', Icons.smartphone_outlined),
    ('F', 'Fintech', Icons.payments_outlined),
    ('C', 'Crypto', Icons.toll_outlined),
  ];

  var _step = 1;
  String? _category;
  String? _countryId;
  List<Map<String, dynamic>> _methods = const [];
  Map<String, dynamic>? _method;
  var _loadingMethods = false;
  final _query = TextEditingController();
  final _identifier = TextEditingController();
  final _national = TextEditingController();
  final _name = TextEditingController();
  final _amount = TextEditingController();
  String? _dialIso;
  String? _error;

  @override
  void initState() {
    super.initState();
    _countryId =
        widget.initialCountryId.isEmpty ? null : widget.initialCountryId;
    if ((widget.initialAmount ?? '').isNotEmpty) {
      _amount.text = widget.initialAmount!;
    }
  }

  @override
  void dispose() {
    _query.dispose();
    _identifier.dispose();
    _national.dispose();
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  String get _identifierType {
    final raw = (_method?['identifier_type']?.toString() ?? '').toLowerCase();
    if (raw == 'phone' || raw == 'email' || raw == 'generic') return raw;
    final fields = _method?['destination_fields'];
    if (fields is List) {
      final lower = fields.map((e) => e.toString().toLowerCase()).toSet();
      if (lower.contains('phone_number') || lower.contains('phone')) {
        return 'phone';
      }
      if (lower.contains('interac_email') || lower.contains('email')) {
        return 'email';
      }
    }
    return 'generic';
  }

  String get _placeholder {
    final fromApi = _method?['account_placeholder']?.toString().trim() ?? '';
    if (fromApi.isNotEmpty) return fromApi;
    final l10n = widget.l10n;
    switch (_identifierType) {
      case 'phone':
        return l10n.paymentPhonePlaceholder;
      case 'email':
        return l10n.paymentEmailPlaceholder;
      default:
        return l10n.paymentGenericPlaceholder;
    }
  }

  String get _identifierLabel {
    final l10n = widget.l10n;
    switch (_identifierType) {
      case 'phone':
        return l10n.paymentPhoneLabel;
      case 'email':
        return l10n.paymentEmailLabel;
      default:
        return l10n.paymentAccountIdentifierLabel;
    }
  }

  List<CountryBriefModel> get _dialCountries {
    final all = widget.countries
        .where((c) => (c.phoneCode ?? '').trim().isNotEmpty)
        .toList();
    final allowRaw = _method?['phone_country_codes'];
    if (allowRaw is! List || allowRaw.isEmpty) return all;
    final allow = allowRaw.map((e) => e.toString().toUpperCase()).toSet();
    return all
        .where((c) => allow.contains(c.isoCode2.toUpperCase()))
        .toList();
  }

  void _syncDialDefault() {
    final dials = _dialCountries;
    if (dials.isEmpty) {
      _dialIso = null;
      return;
    }
    if (_dialIso != null && dials.any((c) => c.isoCode2 == _dialIso)) {
      return;
    }
    final methodIso = _method?['country_code']?.toString().toUpperCase();
    CountryBriefModel? match;
    for (final c in dials) {
      if (c.isoCode2.toUpperCase() == methodIso) {
        match = c;
        break;
      }
    }
    _dialIso = match?.isoCode2 ?? dials.first.isoCode2;
  }

  String _resolvedIdentifier() {
    if (_identifierType != 'phone') {
      return _identifier.text.trim();
    }
    final national = _national.text.trim().replaceFirst(RegExp(r'^0+'), '');
    if (national.isEmpty) return '';
    CountryBriefModel? country;
    for (final c in _dialCountries) {
      if (c.isoCode2 == _dialIso) {
        country = c;
        break;
      }
    }
    final code = (country?.phoneCode ?? '').replaceFirst(RegExp(r'^\+'), '');
    if (code.isEmpty) {
      return national.startsWith('+') ? national : '+$national';
    }
    return '+$code$national';
  }

  Future<void> _loadMethods() async {
    setState(() {
      _loadingMethods = true;
      _error = null;
    });
    try {
      final rows = await sl<OrganizationRepository>().listPaymentMethods(
        operation: widget.operation,
        country: _countryId,
        methodType: _category,
        q: _query.text.trim().isEmpty ? null : _query.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _methods = rows;
        _loadingMethods = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _methods = const [];
        _loadingMethods = false;
        _error = displayErrorMessage(e is Object ? e : widget.l10n.paymentMethodsLoadError);
        if (_error == null || _error!.isEmpty) {
          _error = widget.l10n.paymentMethodsLoadError;
        }
      });
    }
  }

  String get _currency {
    final fixed = widget.fixedCurrencyCode?.trim();
    if (fixed != null && fixed.isNotEmpty) return fixed;
    final methodCcy = _method?['currency_code']?.toString();
    if (methodCcy != null && methodCcy.isNotEmpty) return methodCcy;
    return 'USD';
  }

  Widget _errorBanner(ColorScheme cs) {
    if (_error == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        _error!,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: cs.onErrorContainer),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.paymentCollectTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: List.generate(4, (i) {
              final active = _step > i;
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: i == 3 ? 0 : 4),
                  decoration: BoxDecoration(
                    color: active ? cs.primary : cs.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          Expanded(child: _buildStep(context)),
          _errorBanner(cs),
          Row(
            children: [
              if (_step > 1)
                TextButton(
                  onPressed: () => setState(() {
                    _error = null;
                    if (_step == 2) {
                      _step = 1;
                      _category = null;
                      _method = null;
                    } else if (_step == 3) {
                      _step = 2;
                    } else {
                      _step = 3;
                    }
                  }),
                  child: Text(l10n.commonBack),
                ),
              const Spacer(),
              if (_step == 3)
                FilledButton(
                  onPressed: () {
                    final id = _resolvedIdentifier();
                    if (id.isEmpty) {
                      setState(() => _error = l10n.paymentAccountRequired);
                      return;
                    }
                    if (_identifierType == 'email' && !id.contains('@')) {
                      setState(() => _error = l10n.paymentEmailInvalid);
                      return;
                    }
                    if (widget.showAmount &&
                        (_amount.text.trim().isEmpty ||
                            (double.tryParse(_amount.text.trim()) ?? 0) <= 0)) {
                      setState(() => _error = l10n.escrowTopUpAmount);
                      return;
                    }
                    setState(() {
                      _error = null;
                      _step = 4;
                    });
                  },
                  child: Text(l10n.paymentWizardReview),
                ),
              if (_step == 4)
                FilledButton(
                  onPressed: () {
                    final id = _method?['id']?.toString();
                    final account = _resolvedIdentifier();
                    if (id == null || id.isEmpty || account.isEmpty) return;
                    Navigator.of(context).pop((
                      methodId: id,
                      phone: account,
                      accountName: _name.text.trim().isEmpty
                          ? null
                          : _name.text.trim(),
                      currencyCode: _currency,
                      amount: widget.showAmount ? _amount.text.trim() : null,
                    ));
                  },
                  child: Text(l10n.paymentCollectSubmit),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep(BuildContext context) {
    final l10n = widget.l10n;
    if (_step == 1) {
      return GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.35,
        children: [
          for (final (code, label, icon) in _categories)
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _category = code;
                  _step = 2;
                  _method = null;
                });
                _loadMethods();
              },
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.all(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon),
                  const SizedBox(height: 8),
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
        ],
      );
    }
    if (_step == 2) {
      return Column(
        children: [
          if (widget.countries.isNotEmpty)
            DropdownButtonFormField<String?>(
              value: _countryId,
              decoration: InputDecoration(labelText: l10n.paymentWizardCountry),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(l10n.paymentWizardCountryAll),
                ),
                for (final c in widget.countries)
                  DropdownMenuItem<String?>(
                    value: c.id,
                    child: Text(c.name),
                  ),
              ],
              onChanged: (v) {
                setState(() {
                  _countryId = v;
                  _method = null;
                });
                _loadMethods();
              },
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _query,
            decoration: InputDecoration(
              labelText: l10n.paymentMethodLabel,
              prefixIcon: const Icon(Icons.search),
            ),
            onChanged: (_) {
              Future<void>.delayed(const Duration(milliseconds: 250), _loadMethods);
            },
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loadingMethods
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _methods.length,
                    itemBuilder: (context, i) {
                      final m = _methods[i];
                      final name = m['name']?.toString() ?? m['code']?.toString() ?? '';
                      final logo = m['logo_url']?.toString();
                      return ListTile(
                        leading: logo != null && logo.isNotEmpty
                            ? Image.network(logo, width: 36, height: 36, errorBuilder: (_, __, ___) {
                                return CircleAvatar(child: Text(name.isEmpty ? '?' : name[0]));
                              })
                            : CircleAvatar(child: Text(name.isEmpty ? '?' : name[0])),
                        title: Text(name),
                        subtitle: Text(
                          [
                            m['method_type'] is Map
                                ? (m['method_type'] as Map)['title']
                                : null,
                            m['country_code'],
                            m['currency_code'],
                          ].whereType<Object>().map((e) => e.toString()).join(' · '),
                        ),
                        onTap: () => setState(() {
                          _method = m;
                          _identifier.clear();
                          _national.clear();
                          _syncDialDefault();
                          _step = 3;
                        }),
                      );
                    },
                  ),
          ),
        ],
      );
    }
    if (_step == 3) {
      final name = _method?['name']?.toString() ?? '';
      final dials = _dialCountries;
      return ListView(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(_method?['code']?.toString() ?? ''),
          ),
          if (_identifierType == 'phone')
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _dialIso,
                    decoration: InputDecoration(labelText: l10n.paymentDialCode),
                    items: [
                      for (final c in dials)
                        DropdownMenuItem(
                          value: c.isoCode2,
                          child: Text('${c.isoCode2} +${c.phoneCode}'),
                        ),
                    ],
                    onChanged: (v) => setState(() => _dialIso = v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _national,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: _identifierLabel,
                      hintText: _placeholder,
                    ),
                  ),
                ),
              ],
            )
          else
            TextField(
              controller: _identifier,
              keyboardType: _identifierType == 'email'
                  ? TextInputType.emailAddress
                  : TextInputType.text,
              decoration: InputDecoration(
                labelText: _identifierLabel,
                hintText: _placeholder,
              ),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _name,
            decoration: InputDecoration(labelText: l10n.paymentAccountNameLabel),
          ),
          if (widget.showAmount) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _amount,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: l10n.escrowTopUpAmount),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: l10n.paymentWizardCurrency,
                    ),
                    child: Text(
                      _currency,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      );
    }
    // confirm
    final name = _method?['name']?.toString() ?? '';
    return ListView(
      children: [
        Text(l10n.paymentWizardConfirm, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 12),
        Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
        Text(_resolvedIdentifier()),
        if (_name.text.trim().isNotEmpty) Text(_name.text.trim()),
        if (widget.showAmount)
          Text('${_amount.text.trim()} $_currency'),
      ],
    );
  }
}
