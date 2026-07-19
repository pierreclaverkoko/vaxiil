import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vaxiil_mobile/core/constants/app_routes.dart';
import 'package:vaxiil_mobile/features/auth/presentation/cubit/auth_cubit.dart';
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
  var _seeded = false;
  File? _pickedAvatar;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _first = TextEditingController();
    _last = TextEditingController();
    _phone = TextEditingController();
    _dateOfBirth = TextEditingController();
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit profile'),
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
                        decoration:
                            const InputDecoration(labelText: 'First name'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _last,
                        decoration:
                            const InputDecoration(labelText: 'Last name'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phone,
                        decoration: const InputDecoration(labelText: 'Phone'),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _dateOfBirth,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Date of birth',
                          suffixIcon: Icon(Icons.calendar_today_outlined),
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
                        decoration: const InputDecoration(labelText: 'Sex'),
                        items: const [
                          DropdownMenuItem(value: 'F', child: Text('Female')),
                          DropdownMenuItem(value: 'M', child: Text('Male')),
                          DropdownMenuItem(value: 'X', child: Text('Other')),
                          DropdownMenuItem(
                            value: 'U',
                            child: Text('Prefer not to say'),
                          ),
                        ],
                        onChanged: (value) => setState(() => _sex = value),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: () async {
                          if (_formKey.currentState?.validate() != true) return;
                          final cubit = context.read<AuthCubit>();
                          await cubit.updateProfileFields(
                            firstName: _first.text.trim(),
                            lastName: _last.text.trim(),
                            phone: _phone.text.trim(),
                            dateOfBirth: _dateOfBirth.text.trim(),
                            sex: _sex,
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
                        child: const Text('Save'),
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
