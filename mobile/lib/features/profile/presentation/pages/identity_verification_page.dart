import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:heroicons/heroicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vaxiil_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vaxiil_mobile/features/auth/presentation/cubit/auth_state.dart';
import 'package:vaxiil_mobile/shared/widgets/soft_card.dart';

class IdentityVerificationPage extends StatefulWidget {
  const IdentityVerificationPage({super.key});

  @override
  State<IdentityVerificationPage> createState() =>
      _IdentityVerificationPageState();
}

class _IdentityVerificationPageState extends State<IdentityVerificationPage> {
  File? _idFile;
  File? _selfieFile;
  final _picker = ImagePicker();

  Future<void> _pick({required bool id, required ImageSource source}) async {
    final x = await _picker.pickImage(source: source);
    if (x == null) return;
    setState(() {
      if (id) {
        _idFile = File(x.path);
      } else {
        _selfieFile = File(x.path);
      }
    });
  }

  Future<void> _showSourceSheet({required bool id}) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source != null && mounted) {
      await _pick(id: id, source: source);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = context.watch<AuthCubit>().state.user;
    final loading = context.watch<AuthCubit>().state.isLoading;
    final status = user?.verificationStatus;
    final rejection = user?.verificationRejectionReason;
    final verified = status?.value == 'V';

    return BlocListener<AuthCubit, AuthState>(
      listenWhen: (p, c) => p.errorMessage != c.errorMessage,
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!)),
          );
          context.read<AuthCubit>().clearError();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Identity verification'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Status: ${status?.title ?? 'Pending Verification'}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (verified) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: cs.primary, size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Your identity is verified.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (status?.value == 'R' &&
                      rejection != null &&
                      rejection.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Feedback',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rejection,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: cs.error,
                          ),
                    ),
                  ],
                  if (!verified) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Upload a government ID and a selfie. Max ~5MB per image. '
                      'Our team reviews submissions.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            if (verified) const SizedBox(height: 12),
            if (verified)
              SoftCard(
                child: Text(
                  'You do not need to submit documents again.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            if (!verified) ...[
              const SizedBox(height: 12),
              if (kIsWeb)
                SoftCard(
                  child: Text(
                    'Document upload is not available on web in this build.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              else ...[
                SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: HeroIcon(
                          HeroIcons.identification,
                          style: HeroIconStyle.outline,
                          color: cs.primary,
                        ),
                        title: const Text('ID document'),
                        subtitle: Text(
                          _idFile?.path.split('/').last ?? 'Not selected',
                        ),
                        trailing: TextButton(
                          onPressed: loading
                              ? null
                              : () => _showSourceSheet(id: true),
                          child: const Text('Choose'),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: HeroIcon(
                          HeroIcons.camera,
                          style: HeroIconStyle.outline,
                          color: cs.primary,
                        ),
                        title: const Text('Selfie'),
                        subtitle: Text(
                          _selfieFile?.path.split('/').last ?? 'Not selected',
                        ),
                        trailing: TextButton(
                          onPressed: loading
                              ? null
                              : () => _showSourceSheet(id: false),
                          child: const Text('Choose'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: loading || _idFile == null || _selfieFile == null
                      ? null
                      : () async {
                          await context.read<AuthCubit>().submitVerification(
                                idDocumentPath: _idFile!.path,
                                selfieDocumentPath: _selfieFile!.path,
                              );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Documents submitted for review'),
                              ),
                            );
                          }
                        },
                  child: const Text('Submit for review'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
