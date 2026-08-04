import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vaxiil_mobile/core/di/injection_container.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';
import 'package:vaxiil_mobile/features/bookings/presentation/utils/booking_schedule_utils.dart';
import 'package:vaxiil_mobile/features/business/data/organization_repository.dart';
import 'package:vaxiil_mobile/features/business/data/provider_services_repository.dart';
import 'package:vaxiil_mobile/features/business/presentation/widgets/city_search_field.dart';
import 'package:vaxiil_mobile/features/services/data/service_catalog_models.dart';
import 'package:vaxiil_mobile/l10n/app_localizations.dart';
import 'package:vaxiil_mobile/shared/utils/responsive.dart';
import 'package:vaxiil_mobile/shared/widgets/soft_card.dart';
import 'package:vaxiil_mobile/shared/widgets/vaxiil_site_footer.dart';

/// Create or edit a service for a verified organization.
class BusinessServiceEditPage extends StatefulWidget {
  const BusinessServiceEditPage({
    required this.organizationId, super.key,
    this.serviceId,
  });

  final String organizationId;
  final String? serviceId;

  @override
  State<BusinessServiceEditPage> createState() =>
      _BusinessServiceEditPageState();
}

class _BusinessServiceEditPageState extends State<BusinessServiceEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _address = TextEditingController();
  final _postal = TextEditingController();
  final _picker = ImagePicker();

  List<_VariantRow> _variantRows = [_VariantRow()];

  String? _orgCountryId;
  String? _orgCountryName;
  String? _selectedCityId;
  String? _selectedCityName;
  String? _defaultCurrencyId;
  var _showLocationOnListing = true;
  var _hasVenueAddress = false;
  final Set<String> _acceptedLocationTypes = {
    ...kDefaultLocationTypeCodes,
  };

  String? _subCategoryId;
  final Set<String> _featureIds = {};
  List<ServiceSubCategoryBrief> _subs = [];
  List<ServiceFeatureItemModel> _features = [];
  String? _existingPrimaryImage;
  XFile? _pickedImage;
  var _loading = true;
  var _saving = false;
  String? _error;

  bool get _isEdit =>
      widget.serviceId != null && widget.serviceId!.isNotEmpty;

  bool get _hasImage =>
      _pickedImage != null ||
      (_existingPrimaryImage != null && _existingPrimaryImage!.isNotEmpty);

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  void _disposeVariantRows() {
    for (final r in _variantRows) {
      r.dispose();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _address.dispose();
    _postal.dispose();
    _disposeVariantRows();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (widget.organizationId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Missing organization id';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = sl<ProviderServicesRepository>();
      final orgRepo = sl<OrganizationRepository>();
      final subs = await repo.listSubcategories();
      final feats = await repo.listFeatures();
      final org = await orgRepo.getById(widget.organizationId);
      _subs = subs;
      _features = feats;
      _orgCountryId = org.countryId;
      _orgCountryName = org.country;
      _defaultCurrencyId = org.defaultCurrencyId;
      _hasVenueAddress = org.hasVenueAddress;
      _address.text = org.address;
      _selectedCityId = org.cityId;
      _selectedCityName = org.city;
      _postal.text = org.postalCode;
      if (!_hasVenueAddress) {
        _acceptedLocationTypes.remove('O');
      }
      if (_isEdit) {
        final d = await repo.getService(widget.organizationId, widget.serviceId!);
        _name.text = d.name;
        _description.text = d.description;
        _subCategoryId = d.subCategory.id;
        _existingPrimaryImage = d.primaryImage;
        _featureIds
          ..clear()
          ..addAll(d.featureMappings.map((m) => m.feature.id));
        _showLocationOnListing = d.showLocationOnListing;
        _acceptedLocationTypes
          ..clear()
          ..addAll(
            d.acceptedLocationTypes.isNotEmpty
                ? d.acceptedLocationTypes
                : kDefaultLocationTypeCodes,
          );
        if (!_hasVenueAddress) {
          _acceptedLocationTypes.remove('O');
        }
        _disposeVariantRows();
        _variantRows = d.variants.isEmpty
            ? [_VariantRow()]
            : d.variants.map((v) => _VariantRow.fromModel(v)).toList();
      } else if (_subs.isNotEmpty) {
        _subCategoryId = _subs.first.id;
      }
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is Failure ? e.message : e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2000,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;
    setState(() => _pickedImage = file);
  }

  Map<String, dynamic> _payload() {
    final body = <String, dynamic>{
      'name': _name.text.trim(),
      'sub_category': _subCategoryId,
      'description': _description.text.trim(),
      if (_defaultCurrencyId != null) 'accepted_currency': _defaultCurrencyId,
      if (_orgCountryId != null) 'country': _orgCountryId,
      'show_location_on_listing': _showLocationOnListing,
      'address': _address.text.trim(),
      if (_selectedCityId != null) 'city_id': _selectedCityId,
      'postal_code': _postal.text.trim(),
      'accepted_location_types': _acceptedLocationTypes.toList(),
    };
    final variants = <Map<String, dynamic>>[];
    for (var i = 0; i < _variantRows.length; i++) {
      final r = _variantRows[i];
      final vn = r.name.text.trim();
      final vd = int.tryParse(r.duration.text.trim()) ?? 60;
      final vp = num.tryParse(r.price.text.trim());
      if (vp == null || vp < 0) {
        continue;
      }
      variants.add({
        'name': vn.isEmpty ? 'Option ${i + 1}' : vn,
        'duration_minutes': vd,
        'duration_type': 'F',
        'price': vp.toString(),
        'is_popular': i == 0,
        'is_active': true,
      });
    }
    if (variants.isNotEmpty) {
      body['variants'] = variants;
    }
    if (_isEdit) {
      body['feature_mappings'] = _featureIds
          .map((id) => {'feature': id, 'is_required': false})
          .toList();
    } else if (_featureIds.isNotEmpty) {
      body['feature_mappings'] = _featureIds
          .map((id) => {'feature': id, 'is_required': false})
          .toList();
    }
    return body;
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (_formKey.currentState?.validate() != true) return;
    if (_subCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a subcategory')),
      );
      return;
    }
    if (!_hasImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.businessServiceImageRequired)),
      );
      return;
    }
    if (_variantRows.length >= 2) {
      for (final r in _variantRows) {
        if (r.name.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Name each option when you add more than one'),
            ),
          );
          return;
        }
      }
    }
    setState(() => _saving = true);
    try {
      final repo = sl<ProviderServicesRepository>();
      final body = _payload();
      late ServiceDetailModel saved;
      if (_isEdit) {
        saved = await repo.updateService(
          widget.organizationId,
          widget.serviceId!,
          body,
        );
      } else {
        saved = await repo.createService(widget.organizationId, body);
      }
      if (_pickedImage != null) {
        if (kIsWeb) {
          throw NetworkFailure(
            message: l10n.businessServiceImageWebUnsupported,
            code: 'NOT_SUPPORTED',
          );
        }
        await repo.uploadPrimaryImage(
          widget.organizationId,
          saved.id,
          _pickedImage!.path,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEdit ? 'Service updated' : 'Service created')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is Failure ? e.message : e.toString()),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (!_isEdit) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete service'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await sl<ProviderServicesRepository>().deleteService(
        widget.organizationId,
        widget.serviceId!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service deleted')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is Failure ? e.message : e.toString()),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _featureCard(ServiceFeatureItemModel f) {
    final sel = _featureIds.contains(f.id);
    final desc = (f.description ?? '').trim();
    final truncated = desc.length > 90 ? '${desc.substring(0, 90)}…' : desc;
    final iconName = (f.icon ?? '').trim();
    return Material(
      color: sel
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            if (sel) {
              _featureIds.remove(f.id);
            } else {
              _featureIds.add(f.id);
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: sel
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _materialIconFor(iconName),
                size: 28,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f.name,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (truncated.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        truncated,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (sel)
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _materialIconFor(String name) {
    switch (name) {
      case 'spa':
        return Icons.spa;
      case 'wifi':
        return Icons.wifi;
      case 'local_parking':
        return Icons.local_parking;
      case 'accessible':
        return Icons.accessible;
      case 'child_care':
        return Icons.child_care;
      case 'pets':
        return Icons.pets;
      case 'smoking_rooms':
      case 'smoke_free':
        return Icons.smoke_free;
      case 'water_drop':
        return Icons.water_drop;
      case 'self_improvement':
        return Icons.self_improvement;
      case 'volunteer_activism':
        return Icons.volunteer_activism;
      case 'health_and_safety':
        return Icons.health_and_safety;
      case 'clean_hands':
        return Icons.clean_hands;
      default:
        return Icons.star_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit service' : 'New service'),
        actions: [
          if (_isEdit)
            IconButton(
              onPressed: _saving ? null : _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ResponsiveContent(
                        narrowMaxWidth: 672,
                        padding: const EdgeInsets.all(16),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                controller: _name,
                                decoration: const InputDecoration(
                                  labelText: 'Service name',
                                ),
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'Required'
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                value: _subCategoryId,
                                decoration: const InputDecoration(
                                  labelText: 'Subcategory',
                                ),
                                items: _subs
                                    .map(
                                      (s) => DropdownMenuItem(
                                        value: s.id,
                                        child: Text(
                                          '${s.category.name} · ${s.name}',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _subCategoryId = v),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _description,
                                decoration: const InputDecoration(
                                  labelText: 'Description',
                                ),
                                maxLines: 4,
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'Required'
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                l10n.businessServiceImageLabel,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 8),
                              AspectRatio(
                                aspectRatio: 16 / 9,
                                child: SoftCard(
                                  padding: EdgeInsets.zero,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: _pickedImage != null && !kIsWeb
                                        ? Image.file(
                                            File(_pickedImage!.path),
                                            fit: BoxFit.cover,
                                          )
                                        : _existingPrimaryImage != null
                                            ? Image.network(
                                                _existingPrimaryImage!,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    const Center(
                                                  child: Icon(
                                                    Icons.broken_image,
                                                  ),
                                                ),
                                              )
                                            : Center(
                                                child: Text(
                                                  l10n.businessServiceImageHint,
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: _saving ? null : _pickImage,
                                icon: const Icon(Icons.photo_library_outlined),
                                label: Text(l10n.businessServiceImagePick),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                l10n.businessServicePriceFromOptions,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                l10n.businessServiceAcceptedVenues,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              if (!_hasVenueAddress) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Add a company venue address in settings before enabling At venue.',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: kDefaultLocationTypeCodes.map((code) {
                                  final labels = <String, String>{
                                    'O': l10n.bookingLocationOffice,
                                    'H': l10n.bookingLocationHome,
                                    'V': l10n.bookingLocationVirtual,
                                    'B': l10n.bookingLocationMobile,
                                  };
                                  final sel =
                                      _acceptedLocationTypes.contains(code);
                                  final disabled =
                                      code == 'O' && !_hasVenueAddress;
                                  return FilterChip(
                                    avatar: Icon(
                                      locationTypeIcon(code),
                                      size: 18,
                                    ),
                                    label: Text(labels[code] ?? code),
                                    selected: sel,
                                    onSelected: disabled
                                        ? null
                                        : (v) {
                                            setState(() {
                                              if (v) {
                                                _acceptedLocationTypes.add(code);
                                              } else if (_acceptedLocationTypes
                                                      .length >
                                                  1) {
                                                _acceptedLocationTypes
                                                    .remove(code);
                                              }
                                            });
                                          },
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 16),
                              SwitchListTile(
                                title: const Text(
                                  'Show address on public listing',
                                ),
                                value: _showLocationOnListing,
                                onChanged: (v) {
                                  setState(() => _showLocationOnListing = v);
                                },
                              ),
                              Text(
                                'Location',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _address,
                                decoration: InputDecoration(
                                  labelText: l10n.streetAddressLabel,
                                ),
                              ),
                              const SizedBox(height: 8),
                              CitySearchField(
                                countryId: _orgCountryId,
                                initialCityId: _selectedCityId,
                                initialCityName: _selectedCityName,
                                onSelected: (city) {
                                  setState(() {
                                    _selectedCityId = city?.id;
                                    _selectedCityName = city?.name;
                                  });
                                },
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _postal,
                                decoration: InputDecoration(
                                  labelText: l10n.postalCodeLabel,
                                ),
                              ),
                              const SizedBox(height: 8),
                              InputDecorator(
                                decoration: InputDecoration(
                                  labelText: l10n.countryLabel,
                                  border: const OutlineInputBorder(),
                                ),
                                child: Text(_orgCountryName ?? '—'),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Options (variants)',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall,
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _variantRows.add(_VariantRow());
                                      });
                                    },
                                    icon: const Icon(Icons.add, size: 20),
                                    label: const Text('Add option'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ...List.generate(_variantRows.length, (index) {
                                final r = _variantRows[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: SoftCard(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              'Option ${index + 1}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelLarge,
                                            ),
                                            const Spacer(),
                                            if (_variantRows.length > 1)
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.remove_circle_outline,
                                                ),
                                                onPressed: () {
                                                  setState(() {
                                                    r.dispose();
                                                    _variantRows
                                                        .removeAt(index);
                                                  });
                                                },
                                                tooltip: 'Remove',
                                              ),
                                          ],
                                        ),
                                        TextFormField(
                                          controller: r.name,
                                          decoration: const InputDecoration(
                                            labelText: 'Name (e.g. 60 min)',
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: TextFormField(
                                                controller: r.duration,
                                                decoration:
                                                    const InputDecoration(
                                                  labelText:
                                                      'Duration (minutes)',
                                                ),
                                                keyboardType:
                                                    TextInputType.number,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: TextFormField(
                                                controller: r.price,
                                                decoration:
                                                    const InputDecoration(
                                                  labelText: 'Price',
                                                ),
                                                keyboardType:
                                                    TextInputType.number,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                              const SizedBox(height: 16),
                              Text(
                                l10n.businessServiceFeaturesSection,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 8),
                              ..._features.map(
                                (f) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _featureCard(f),
                                ),
                              ),
                              const SizedBox(height: 24),
                              FilledButton(
                                onPressed: _saving ? null : _save,
                                child: _saving
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(_isEdit ? 'Save' : 'Create'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const VaxiilSiteFooter(),
                    ],
                  ),
                ),
    );
  }
}

class _VariantRow {
  _VariantRow()
      : name = TextEditingController(),
        duration = TextEditingController(text: '60'),
        price = TextEditingController();

  _VariantRow.fromModel(ServiceVariantDetailModel v)
      : name = TextEditingController(text: v.name),
        duration = TextEditingController(text: v.durationMinutes.toString()),
        price = TextEditingController(text: v.price.toString());

  final TextEditingController name;
  final TextEditingController duration;
  final TextEditingController price;

  void dispose() {
    name.dispose();
    duration.dispose();
    price.dispose();
  }
}
