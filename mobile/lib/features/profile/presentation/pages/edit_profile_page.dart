import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vaxiil_mobile/core/constants/app_routes.dart';
import 'package:vaxiil_mobile/core/di/injection_container.dart';
import 'package:vaxiil_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vaxiil_mobile/features/business/data/organization_models.dart';
import 'package:vaxiil_mobile/features/business/data/organization_repository.dart';
import 'package:vaxiil_mobile/l10n/app_localizations.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';
import 'package:vaxiil_mobile/shared/widgets/soft_card.dart';
import 'package:vaxiil_mobile/shared/widgets/vaxiil_site_footer.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _first;
  late final TextEditingController _last;
  late final TextEditingController _phone;
  late final TextEditingController _dateOfBirth;
  String? _sex;
  String? _defaultCountryId;
  List<CountryBriefModel> _countries = [];
  var _seeded = false;
  var _countriesLoaded = false;
  File? _pickedAvatar;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _first = TextEditingController();
    _last = TextEditingController();
    _phone = TextEditingController();
    _dateOfBirth = TextEditingController();
    _loadCountries();
  }

  Future<void> _loadCountries() async {
    try {
      final countries = await sl<OrganizationRepository>().listCountries();
      if (!mounted) return;
      setState(() {
        _countries = countries;
        _countriesLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _countriesLoaded = true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _seeded = true;
    final u = context.read<AuthCubit>().state.user;
    _first.text = u?.firstName ?? '';
    _last.text = u?.lastName ?? '';
    _phone.text = u?.phone ?? '';
    _dateOfBirth.text = u?.dateOfBirth ?? '';
    _sex = u?.sex?.value;
    _defaultCountryId = u?.defaultCountryId;
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _phone.dispose();
    _dateOfBirth.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final x = await _picker.pickImage(source: ImageSource.gallery);
    if (x != null) setState(() => _pickedAvatar = File(x.path));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthCubit>().state.user;
    final avatarUrl = user?.avatarUrl;
    final l10n = AppLocalizations.of(context);
    final countryIds = _countries.map((c) => c.id).toSet();
    final selectedCountryId =
        _defaultCountryId != null && countryIds.contains(_defaultCountryId)
            ? _defaultCountryId
            : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.editProfileTitle),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ResponsiveContent(
              narrowMaxWidth: 672,
              padding: const EdgeInsets.all(16),
              child: SoftCard(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 48,
                              backgroundColor: AppTheme.borderColor,
                              backgroundImage: _pickedAvatar != null
                                  ? FileImage(_pickedAvatar!)
                                  : (avatarUrl != null && avatarUrl.isNotEmpty
                                      ? CachedNetworkImageProvider(avatarUrl)
                                      : null),
                              child: _pickedAvatar == null &&
                                      (avatarUrl == null || avatarUrl.isEmpty)
                                  ? const HeroIcon(
                                      HeroIcons.user,
                                      style: HeroIconStyle.outline,
                                      size: 48,
                                      color: AppTheme.textSecondary,
                                    )
                                  : null,
                            ),
                            if (!kIsWeb)
                              IconButton.filled(
                                style: IconButton.styleFrom(
                                  backgroundColor: AppTheme.accentCta,
                                  foregroundColor: AppTheme.onAccentCta,
                                ),
                                onPressed: _pickAvatar,
                                icon: const HeroIcon(
                                  HeroIcons.camera,
                                  style: HeroIconStyle.outline,
                                  size: 20,
                                  color: AppTheme.onAccentCta,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _first,
                        decoration: InputDecoration(labelText: l10n.firstNameLabel),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _last,
                        decoration: InputDecoration(labelText: l10n.lastNameLabel),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phone,
                        decoration: InputDecoration(labelText: l10n.phoneLabel),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _dateOfBirth,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: l10n.dateOfBirthLabel,
                          suffixIcon: const Icon(Icons.calendar_today_outlined),
                        ),
                        onTap: () async {
                          final initial =
                              DateTime.tryParse(_dateOfBirth.text) ??
                                  DateTime(DateTime.now().year - 18);
                          final value = await showDatePicker(
                            context: context,
                            initialDate: initial,
                            firstDate: DateTime(1900),
                            lastDate: DateTime.now(),
                          );
                          if (value != null) {
                            setState(() {
                              _dateOfBirth.text =
                                  value.toIso8601String().substring(0, 10);
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _sex,
                        decoration: InputDecoration(labelText: l10n.sexLabel),
                        items: [
                          DropdownMenuItem(value: 'F', child: Text(l10n.sexFemale)),
                          DropdownMenuItem(value: 'M', child: Text(l10n.sexMale)),
                          DropdownMenuItem(value: 'X', child: Text(l10n.sexOther)),
                          DropdownMenuItem(
                            value: 'U',
                            child: Text(l10n.sexPreferNot),
                          ),
                        ],
                        onChanged: (value) => setState(() => _sex = value),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedCountryId ?? '',
                        decoration: InputDecoration(
                          labelText: l10n.defaultCountryLabel,
                          hintText: _countriesLoaded
                              ? l10n.defaultCountryHint
                              : l10n.loadingLabel,
                        ),
                        items: [
                          DropdownMenuItem<String>(
                            value: '',
                            child: Text(l10n.defaultCountryNone),
                          ),
                          ..._countries.map(
                            (c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            ),
                          ),
                        ],
                        onChanged: (value) => setState(
                          () => _defaultCountryId =
                              (value == null || value.isEmpty) ? null : value,
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: () async {
                          if (_formKey.currentState?.validate() != true) return;
                          final cubit = context.read<AuthCubit>();
                          final previous = user?.defaultCountryId;
                          await cubit.updateProfileFields(
                            firstName: _first.text.trim(),
                            lastName: _last.text.trim(),
                            phone: _phone.text.trim(),
                            dateOfBirth: _dateOfBirth.text.trim(),
                            sex: _sex,
                            defaultCountryId: _defaultCountryId,
                            clearDefaultCountry: previous != null &&
                                (_defaultCountryId == null ||
                                    _defaultCountryId!.isEmpty),
                          );
                          if (!context.mounted) return;
                          if (cubit.state.errorMessage != null) return;
                          if (_pickedAvatar != null && !kIsWeb) {
                            await cubit.uploadAvatar(_pickedAvatar!.path);
                            if (!context.mounted) return;
                            if (cubit.state.errorMessage != null) return;
                          }
                          await cubit.refreshProfile();
                          if (!context.mounted) return;
                          context.go(AppRoutes.profile);
                        },
                        child: Text(l10n.saveLabel),
                      ),
                    ],
                  ),
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
