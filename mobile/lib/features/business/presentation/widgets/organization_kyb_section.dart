import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vaxiil_mobile/core/di/injection_container.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';
import 'package:vaxiil_mobile/features/business/data/organization_models.dart';
import 'package:vaxiil_mobile/features/business/data/organization_repository.dart';
import 'package:vaxiil_mobile/shared/widgets/soft_card.dart';

/// Business verification (KYB) document upload for an organization.
class OrganizationKybSection extends StatefulWidget {
  const OrganizationKybSection({
    super.key,
    required this.organization,
    required this.onSubmitted,
  });

  final OrganizationModel organization;
  final VoidCallback onSubmitted;

  @override
  State<OrganizationKybSection> createState() => _OrganizationKybSectionState();
}

class _OrganizationKybSectionState extends State<OrganizationKybSection> {
  final _licenseCtrl = TextEditingController();
  final _taxCtrl = TextEditingController();
  final _picker = ImagePicker();
  File? _licenseDoc;
  File? _idDoc;
  var _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _licenseCtrl.text = widget.organization.businessLicenseNumber ?? '';
    _taxCtrl.text = widget.organization.taxId ?? '';
  }

  @override
  void dispose() {
    _licenseCtrl.dispose();
    _taxCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick({required bool license, required ImageSource source}) async {
    final x = await _picker.pickImage(source: source);
    if (x == null) return;
    setState(() {
      if (license) {
        _licenseDoc = File(x.path);
      } else {
        _idDoc = File(x.path);
      }
      _error = null;
    });
  }

  Future<void> _showSourceSheet({required bool license}) async {
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
      await _pick(license: license, source: source);
    }
  }

  Future<void> _submit() async {
    if (_licenseDoc == null || _idDoc == null) {
      setState(() => _error = 'Select both documents.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await sl<OrganizationRepository>().submitVerification(
        organizationId: widget.organization.id,
        businessLicensePath: _licenseDoc!.path,
        idDocumentPath: _idDoc!.path,
        businessLicenseNumber: _licenseCtrl.text.trim().isEmpty
            ? null
            : _licenseCtrl.text.trim(),
        taxId: _taxCtrl.text.trim().isEmpty ? null : _taxCtrl.text.trim(),
      );
      if (mounted) {
        widget.onSubmitted();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification documents submitted')),
        );
      }
    } catch (e) {
      final msg = e is Failure ? e.message : e.toString();
      if (mounted) setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return SoftCard(
        child: Text(
          'KYB upload is not available on web in this build.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    final cs = Theme.of(context).colorScheme;
    final st = widget.organization.verificationStatus;
    final verified = st?.value == 'V';

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Business verification (KYB)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Status: ${st?.title ?? 'Pending Verification'}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
          if (widget.organization.rejectionReason != null &&
              widget.organization.rejectionReason!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              widget.organization.rejectionReason!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.error,
                  ),
            ),
          ],
          if (verified) ...[
            const SizedBox(height: 8),
            Text(
              'This organization is verified.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ] else ...[
            const SizedBox(height: 12),
            TextField(
              controller: _licenseCtrl,
              decoration: const InputDecoration(
                labelText: 'Business license number (optional)',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _taxCtrl,
              decoration: const InputDecoration(
                labelText: 'Tax ID (optional)',
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: HeroIcon(
                HeroIcons.documentText,
                style: HeroIconStyle.outline,
                color: cs.primary,
              ),
              title: const Text('Business license document'),
              subtitle: Text(
                _licenseDoc?.path.split('/').last ?? 'Not selected',
              ),
              trailing: TextButton(
                onPressed: _submitting
                    ? null
                    : () => _showSourceSheet(license: true),
                child: const Text('Choose'),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: HeroIcon(
                HeroIcons.identification,
                style: HeroIconStyle.outline,
                color: cs.primary,
              ),
              title: const Text('Representative ID'),
              subtitle: Text(_idDoc?.path.split('/').last ?? 'Not selected'),
              trailing: TextButton(
                onPressed: _submitting
                    ? null
                    : () => _showSourceSheet(license: false),
                child: const Text('Choose'),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: cs.error),
                ),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit for review'),
            ),
          ],
        ],
      ),
    );
  }
}
