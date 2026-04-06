import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:vaxiil_mobile/core/constants/app_routes.dart';
import 'package:vaxiil_mobile/core/di/injection_container.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';
import 'package:vaxiil_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vaxiil_mobile/features/business/data/organization_models.dart';
import 'package:vaxiil_mobile/features/business/data/organization_repository.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';
import 'package:vaxiil_mobile/shared/widgets/soft_card.dart';

class BusinessSetupPage extends StatefulWidget {
  const BusinessSetupPage({super.key});

  @override
  State<BusinessSetupPage> createState() => _BusinessSetupPageState();
}

class _BusinessSetupPageState extends State<BusinessSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _description = TextEditingController();
  final _website = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _postal = TextEditingController();

  List<OrganizationTypeOption> _types = [];
  OrganizationTypeOption? _selectedType;
  List<CountryBriefModel> _countries = [];
  CountryBriefModel? _selectedCountry;
  String? _loadError;
  var _submitting = false;
  final _picker = ImagePicker();
  XFile? _logoFile;
  Uint8List? _logoPreview;

  @override
  void initState() {
    super.initState();
    _loadReferenceData();
  }

  Future<void> _loadReferenceData() async {
    try {
      final repo = sl<OrganizationRepository>();
      final types = await repo.listTypes();
      final countries = await repo.listCountries();
      if (mounted) {
        setState(() {
          _types = types;
          _countries = countries;
          _loadError = null;
          if (_selectedType == null && types.isNotEmpty) {
            _selectedType = types.first;
          }
          if (_selectedCountry == null && countries.isNotEmpty) {
            CountryBriefModel? us;
            for (final c in countries) {
              if (c.isoCode2 == 'US') {
                us = c;
                break;
              }
            }
            _selectedCountry = us ?? countries.first;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e is Failure ? e.message : e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _description.dispose();
    _website.dispose();
    _address.dispose();
    _city.dispose();
    _postal.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final x = await _picker.pickImage(source: ImageSource.gallery);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    if (!mounted) return;
    setState(() {
      _logoFile = x;
      _logoPreview = bytes;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Business setup'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SoftCard(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const HeroIcon(
                      HeroIcons.buildingOffice2,
                      style: HeroIconStyle.outline,
                      color: AppTheme.primaryVariant,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Organization',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (_loadError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _loadError!,
                      style: const TextStyle(color: AppTheme.errorColor),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Company logo',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Required — square (1:1) image works best.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _pickLogo,
                      customBorder: const CircleBorder(),
                      child: Ink(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cs.surfaceContainerHighest,
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: _logoPreview != null
                            ? ClipOval(
                                child: Image.memory(
                                  _logoPreview!,
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate_outlined,
                                    size: 36,
                                    color: cs.primary,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tap to add',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (_types.isNotEmpty)
                  DropdownButtonFormField<OrganizationTypeOption>(
                    value: _selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Business type',
                    ),
                    items: _types
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(t.displayName),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedType = v),
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Business name',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Contact email',
                  ),
                  validator: (v) =>
                      (v == null || !v.contains('@')) ? 'Valid email required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _website,
                  decoration: const InputDecoration(
                    labelText: 'Website (optional)',
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Location',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _address,
                  decoration: const InputDecoration(
                    labelText: 'Street address',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _city,
                  decoration: const InputDecoration(
                    labelText: 'City',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _postal,
                  decoration: const InputDecoration(
                    labelText: 'Postal code',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<CountryBriefModel>(
                  value: _selectedCountry,
                  decoration: const InputDecoration(
                    labelText: 'Country',
                  ),
                  items: _countries
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(c.name),
                        ),
                      )
                      .toList(),
                  onChanged: (c) => setState(() => _selectedCountry = c),
                  validator: (c) => c == null ? 'Select a country' : null,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _submitting || _selectedType == null || _selectedCountry == null
                      ? null
                      : () async {
                          if (_formKey.currentState?.validate() != true) {
                            return;
                          }
                          if (_logoFile == null || _logoPreview == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please add a company logo'),
                              ),
                            );
                            return;
                          }
                          setState(() => _submitting = true);
                          try {
                            var fname = p.basename(_logoFile!.path);
                            if (fname.isEmpty || fname == '/') {
                              fname = 'logo.jpg';
                            }
                            await sl<OrganizationRepository>().create(
                              typeId: _selectedType!.id,
                              name: _name.text.trim(),
                              email: _email.text.trim(),
                              address: _address.text.trim(),
                              city: _city.text.trim(),
                              postalCode: _postal.text.trim(),
                              countryId: _selectedCountry!.id,
                              logoBytes: _logoPreview!,
                              logoFilename: fname,
                              phone: _phone.text.trim().isEmpty
                                  ? null
                                  : _phone.text.trim(),
                              description: _description.text.trim().isEmpty
                                  ? null
                                  : _description.text.trim(),
                              website: _website.text.trim().isEmpty
                                  ? null
                                  : _website.text.trim(),
                            );
                            await context.read<AuthCubit>().refreshProfile();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Business created'),
                                ),
                              );
                              context.go(AppRoutes.business);
                            }
                          } catch (e) {
                            if (context.mounted) {
                              final msg = e is Failure
                                  ? e.message
                                  : e.toString();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(msg)),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _submitting = false);
                          }
                        },
                  child: _submitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create business'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
