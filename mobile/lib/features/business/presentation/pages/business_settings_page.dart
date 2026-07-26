import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart' as loc;
import 'package:path/path.dart' as p;
import 'package:vaxiil_mobile/core/constants/app_constants.dart';
import 'package:vaxiil_mobile/core/constants/stitch_images.dart';
import 'package:vaxiil_mobile/core/di/injection_container.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';
import 'package:vaxiil_mobile/features/business/data/organization_models.dart';
import 'package:vaxiil_mobile/features/business/data/organization_repository.dart';
import 'package:vaxiil_mobile/features/business/presentation/widgets/city_search_field.dart';
import 'package:vaxiil_mobile/l10n/app_localizations.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';
import 'package:vaxiil_mobile/shared/utils/responsive.dart';
import 'package:vaxiil_mobile/shared/widgets/choice_enum_widget.dart';
import 'package:vaxiil_mobile/shared/widgets/org_logo_avatar.dart';
import 'package:vaxiil_mobile/shared/widgets/soft_card.dart';

class BusinessSettingsPage extends StatefulWidget {
  const BusinessSettingsPage({required this.organizationId, super.key});

  final String organizationId;

  @override
  State<BusinessSettingsPage> createState() => _BusinessSettingsPageState();
}

class _BusinessSettingsPageState extends State<BusinessSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _description = TextEditingController();
  final _website = TextEditingController();
  final _address = TextEditingController();
  final _postal = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();

  final _picker = ImagePicker();

  Object? _loadError;
  var _loading = true;
  var _saving = false;
  String? _error;
  OrganizationModel? _org;
  String? _selectedCityId;
  String? _selectedCityName;
  double? _lat;
  double? _lng;
  Uint8List? _logoPreviewBytes;
  String? _logoPickFilename;
  var _requireClientName = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final repo = sl<OrganizationRepository>();
      final o = await repo.getById(widget.organizationId);
      if (!mounted) return;
      _applyFromOrg(o);
      setState(() {
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _loading = false;
      });
    }
  }

  void _applyFromOrg(OrganizationModel o) {
    _org = o;
    _name.text = o.name;
    _email.text = o.email;
    _phone.text = o.phone ?? '';
    _description.text = o.description ?? '';
    _website.text = o.website ?? '';
    _address.text = o.address;
    _selectedCityId = o.cityId;
    _selectedCityName = o.city;
    _postal.text = o.postalCode;
    _lat = o.latitude;
    _lng = o.longitude;
    _latController.text = o.latitude?.toString() ?? '';
    _lngController.text = o.longitude?.toString() ?? '';
    _requireClientName = o.requireClientName;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _description.dispose();
    _website.dispose();
    _address.dispose();
    _postal.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final x = await _picker.pickImage(source: ImageSource.gallery);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    if (!mounted) return;
    var fname = p.basename(x.path);
    if (fname.isEmpty || fname == '/') {
      fname = 'logo.jpg';
    }
    setState(() {
      _logoPreviewBytes = bytes;
      _logoPickFilename = fname;
    });
  }

  Future<void> _useCurrentLocation() async {
    if (kIsWeb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Location is not available on web in this build.')),
      );
      return;
    }
    final locationService = loc.Location();
    var serviceEnabled = await locationService.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await locationService.requestService();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please turn on location services.')),
        );
        return;
      }
    }
    var permission = await locationService.hasPermission();
    if (permission == loc.PermissionStatus.denied) {
      permission = await locationService.requestPermission();
    }
    if (permission != loc.PermissionStatus.granted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission is required.')),
      );
      return;
    }
    try {
      final locData = await locationService.getLocation();
      final lat = locData.latitude;
      final lng = locData.longitude;
      if (lat == null || lng == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read GPS coordinates.')),
        );
        return;
      }
      final places = await placemarkFromCoordinates(lat, lng);
      if (!mounted) return;
      if (places.isEmpty) {
        setState(() {
          _lat = lat;
          _lng = lng;
        });
        return;
      }
      final place = places.first;
      final line = [
        place.street,
        place.subThoroughfare,
        place.thoroughfare,
      ]
          .where((s) => s != null && s.trim().isNotEmpty)
          .map((s) => s!.trim())
          .join(', ');
      setState(() {
        _lat = lat;
        _lng = lng;
        _latController.text = lat.toString();
        _lngController.text = lng.toString();
        if (line.isNotEmpty) {
          _address.text = line;
        }
        if (place.postalCode != null && place.postalCode!.isNotEmpty) {
          _postal.text = place.postalCode!;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not get location: $e')),
      );
    }
  }

  Future<void> _showLocationDialog() async {
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.businessLocationDialogTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _address,
                decoration: InputDecoration(labelText: l10n.streetAddressLabel),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _postal,
                decoration: InputDecoration(labelText: l10n.postalCodeLabel),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _latController,
                decoration: InputDecoration(labelText: l10n.latitudeLabel),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _lngController,
                decoration: InputDecoration(labelText: l10n.longitudeLabel),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _lat = double.tryParse(_latController.text.trim());
              _lng = double.tryParse(_lngController.text.trim());
              Navigator.pop(ctx);
            },
            child: Text(l10n.doneLabel),
          ),
        ],
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final countryId = _org?.countryId;
    if (countryId == null || countryId.isEmpty) {
      setState(
          () => _error = 'Organization country is missing. Contact support.');
      return;
    }
    final cityId = _selectedCityId;
    if (cityId == null || cityId.isEmpty) {
      setState(() => _error = AppLocalizations.of(context).cityRequired);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final o = await sl<OrganizationRepository>().update(
        widget.organizationId,
        name: _name.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        description:
            _description.text.trim().isEmpty ? null : _description.text.trim(),
        website: _website.text.trim().isEmpty ? null : _website.text.trim(),
        defaultCurrencyId: _org?.defaultCurrencyId,
        primaryAddress: _address.text.trim(),
        primaryCityId: cityId,
        primaryPostalCode: _postal.text.trim(),
        primaryCountryId: countryId,
        primaryLatitude: double.tryParse(_latController.text.trim()) ?? _lat,
        primaryLongitude: double.tryParse(_lngController.text.trim()) ?? _lng,
        logoBytes: _logoPreviewBytes,
        logoFilename: _logoPickFilename,
        requireClientName: _requireClientName,
      );
      if (!mounted) return;
      _applyFromOrg(o);
      setState(() {
        _logoPreviewBytes = null;
        _logoPickFilename = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved')),
      );
      context.pop();
    } catch (e) {
      final msg = e is Failure ? e.message : e.toString();
      if (mounted) setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildSaveButton({bool fullWidth = true}) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.ctaFill,
        foregroundColor: AppTheme.onCtaFill,
        padding: const EdgeInsets.symmetric(vertical: 16),
        minimumSize: fullWidth ? const Size.fromHeight(56) : null,
      ),
      onPressed: _saving ? null : _save,
      icon: _saving
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const HeroIcon(
              HeroIcons.checkCircle,
              style: HeroIconStyle.outline,
              size: 22,
            ),
      label: Text(
        _saving ? 'Saving…' : 'Save changes',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildIdentitySection(TextTheme tt) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Company Identity',
            style: tt.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Update your business logo and visual anchor. Recommended size 512×512px.',
            style: tt.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _logoPreviewBytes != null
                  ? ClipOval(
                      child: Image.memory(
                        _logoPreviewBytes!,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                      ),
                    )
                  : OrgLogoAvatar(
                      logoUrl: _org?.logoUrl,
                      size: 72,
                    ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: _pickLogo,
                icon: const Icon(Icons.cloud_upload_outlined, size: 20),
                label: const Text('Update logo'),
              ),
            ],
          ),
          const SizedBox(height: 20),
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
              labelText: 'Email address',
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Required';
              }
              if (!v.contains('@')) return 'Invalid email';
              return null;
            },
          ),
          if (_org != null && !_org!.isVerified) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: AppTheme.warningColor,
                ),
                const SizedBox(width: 6),
                Text(
                  'Unverified',
                  style: tt.bodySmall?.copyWith(
                    color: AppTheme.warningColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: _phone,
            decoration: const InputDecoration(
              labelText: 'Phone number',
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _description,
            decoration: const InputDecoration(
              labelText: 'Business description',
            ),
            maxLines: 4,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _website,
            decoration: const InputDecoration(
              labelText: 'Website',
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Require client name for bookings'),
            subtitle: const Text(
              'Clients using a trust alias must share their name to book.',
            ),
            value: _requireClientName,
            onChanged: (value) => setState(() => _requireClientName = value),
          ),
          if (_org?.platformFees != null) ...[
            const SizedBox(height: 16),
            _buildPlatformFeesSection(tt),
          ],
        ],
      ),
    );
  }

  Widget _buildPlatformFeesSection(TextTheme tt) {
    final fees = _org!.platformFees!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Platform fees',
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Managed by Vaxiil staff. Read-only for your organization.',
              style: tt.bodySmall?.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            _PlatformFeeInfoRow(
              label: 'Rate',
              value: '${fees.platformFeeRate}%',
            ),
            if (fees.platformFeePayer != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Paid by',
                    style: tt.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ChoiceEnumWidget(data: fees.platformFeePayer!),
                ],
              ),
            ],
            if (fees.platformFeeSource != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Source',
                    style: tt.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ChoiceEnumWidget(data: fees.platformFeeSource!),
                ],
              ),
            ],
            if (fees.hasOrganizationOverride) ...[
              const SizedBox(height: 8),
              Text(
                'Organization override active',
                style: tt.bodySmall?.copyWith(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (fees.note != null && fees.note!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                fees.note!,
                style: tt.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSection(TextTheme tt) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Location',
                style: tt.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              if (_org?.isActive == true)
                Chip(
                  label: const Text('Active'),
                  backgroundColor: AppTheme.ctaFill,
                  labelStyle: const TextStyle(
                    color: AppTheme.onCtaFill,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 12),
          _LocationMapPreview(lat: _lat, lng: _lng),
          const SizedBox(height: 12),
          TextFormField(
            controller: _address,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).streetAddressLabel,
              prefixIcon: const Icon(Icons.location_on_outlined),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          CitySearchField(
            countryId: _org?.countryId,
            initialCityId: _selectedCityId,
            initialCityName: _selectedCityName,
            onSelected: (city) {
              setState(() {
                _selectedCityId = city?.id;
                _selectedCityName = city?.name;
              });
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _postal,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).postalCodeLabel,
            ),
          ),
          const SizedBox(height: 12),
          InputDecorator(
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).countryLabel,
              border: const OutlineInputBorder(),
            ),
            child: Text(
              _org?.country ?? '—',
              style: tt.bodyLarge?.copyWith(
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _latController,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).latitudeLabel,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  onChanged: (v) => _lat = double.tryParse(v.trim()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _lngController,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).longitudeLabel,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  onChanged: (v) => _lng = double.tryParse(v.trim()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton.icon(
                onPressed: _useCurrentLocation,
                icon: const HeroIcon(
                  HeroIcons.mapPin,
                  style: HeroIconStyle.outline,
                  size: 18,
                ),
                label: const Text('Use current location'),
              ),
              TextButton.icon(
                onPressed: _showLocationDialog,
                icon: const HeroIcon(
                  HeroIcons.map,
                  style: HeroIconStyle.outline,
                  size: 18,
                ),
                label: const Text('Add location'),
              ),
            ],
          ),
          if (_org?.updatedAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Last synced ${DateFormat.yMMMd().add_jm().format(_org!.updatedAt!.toLocal())}',
              style: tt.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSidebarSaveCard(TextTheme tt) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_org?.updatedAt != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Last synced ${DateFormat.yMMMd().add_jm().format(_org!.updatedAt!.toLocal())}',
                textAlign: TextAlign.center,
                style: tt.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          _buildSaveButton(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isWide = context.isLgUp;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _loadError is Failure
                          ? (_loadError! as Failure).message
                          : _loadError.toString(),
                    ),
                  ),
                )
              : Stack(
                  children: [
                    SafeArea(
                      child: Form(
                        key: _formKey,
                        child: ListView(
                          padding: EdgeInsets.fromLTRB(
                            AppConstants.defaultPadding,
                            12,
                            AppConstants.defaultPadding,
                            isWide ? 24 : 120,
                          ),
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                      Icons.arrow_back_ios_new_rounded),
                                  color: AppTheme.textPrimary,
                                  onPressed: () => context.pop(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Company Settings',
                              style: tt.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Refine your business identity and digital presence. '
                              'Changes reflect across your customer-facing wellness portal instantly.',
                              style: tt.bodyMedium?.copyWith(
                                color: AppTheme.textSecondary,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 24),
                            if (isWide)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 8,
                                    child: Column(
                                      children: [
                                        _buildIdentitySection(tt),
                                        if (_error != null) ...[
                                          const SizedBox(height: 12),
                                          Text(
                                            _error!,
                                            style: TextStyle(color: cs.error),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 32),
                                  Expanded(
                                    flex: 4,
                                    child: Column(
                                      children: [
                                        _buildLocationSection(tt),
                                        const SizedBox(height: 16),
                                        _buildSidebarSaveCard(tt),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            else ...[
                              _buildIdentitySection(tt),
                              const SizedBox(height: 16),
                              _buildLocationSection(tt),
                              if (_error != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  _error!,
                                  style: TextStyle(color: cs.error),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (!isWide)
                      Positioned(
                        left: AppConstants.defaultPadding,
                        right: AppConstants.defaultPadding,
                        bottom: 24,
                        child: SafeArea(
                          top: false,
                          child: _buildSaveButton(),
                        ),
                      ),
                  ],
                ),
    );
  }
}

class _PlatformFeeInfoRow extends StatelessWidget {
  const _PlatformFeeInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

/// Google Map when [AppConstants.googleMapsApiKey] and coordinates are set;
/// otherwise a Stitch-style gradient placeholder (incl. web).
class _LocationMapPreview extends StatelessWidget {
  const _LocationMapPreview({this.lat, this.lng});

  final double? lat;
  final double? lng;

  @override
  Widget build(BuildContext context) {
    final key = AppConstants.googleMapsApiKey;
    final lat0 = lat;
    final lng0 = lng;
    final useGoogleMap =
        !kIsWeb && key.isNotEmpty && lat0 != null && lng0 != null;

    if (useGoogleMap) {
      final pos = LatLng(lat0, lng0);
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.radiusCard),
        child: SizedBox(
          height: 160,
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: pos,
              zoom: AppConstants.defaultMapZoom,
            ),
            markers: {
              Marker(
                markerId: const MarkerId('primary'),
                position: pos,
              ),
            },
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            myLocationButtonEnabled: false,
            liteModeEnabled: defaultTargetPlatform == TargetPlatform.android,
          ),
        ),
      );
    }

    return _GradientLocationFallback(lat: lat, lng: lng);
  }
}

class _GradientLocationFallback extends StatelessWidget {
  const _GradientLocationFallback({this.lat, this.lng});

  final double? lat;
  final double? lng;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppConstants.radiusCard),
      child: SizedBox(
        height: 160,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              StitchImages.companyMapPreview,
              fit: BoxFit.cover,
              color: Colors.white.withOpacity(0.35),
              colorBlendMode: BlendMode.lighten,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryColor.withOpacity(0.12),
                    AppTheme.secondaryColor.withOpacity(0.18),
                  ],
                ),
              ),
            ),
            Center(
              child: HeroIcon(
                HeroIcons.map,
                style: HeroIconStyle.outline,
                size: 56,
                color: AppTheme.primaryVariant.withOpacity(0.85),
              ),
            ),
            if (lat != null && lng != null)
              Positioned(
                left: 12,
                bottom: 10,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Text(
                      '${lat!.toStringAsFixed(5)}, ${lng!.toStringAsFixed(5)}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
