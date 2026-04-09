import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vaxiil_mobile/core/di/injection_container.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';
import 'package:vaxiil_mobile/features/business/data/organization_models.dart';
import 'package:vaxiil_mobile/features/business/data/organization_repository.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';
import 'package:vaxiil_mobile/shared/widgets/soft_list_divider.dart';

/// Business verification (KYB) — Stitch “KYB Submission” layout.
class OrganizationKybSection extends StatefulWidget {
  const OrganizationKybSection({
    required this.organization,
    required this.onSubmitted,
    super.key,
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

  Future<void> _pick({
    required bool license,
    required ImageSource source,
  }) async {
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
        businessLicenseNumber:
            _licenseCtrl.text.trim().isEmpty ? null : _licenseCtrl.text.trim(),
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
      return _KybShell(
        child: Text(
          'KYB upload is not available on web in this build.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    final cs = Theme.of(context).colorScheme;
    final st = widget.organization.verificationStatus;
    final code = st?.value ?? '';
    final verified = code == 'V';
    final suspended = code == 'S';
    final pendingReview =
        code == 'P' && widget.organization.kybSubmittedAt != null;

    return _KybShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'KYB submission',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.primary,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Status: ${st?.title ?? 'Pending Verification'}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
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
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HeroIcon(
                  HeroIcons.checkCircle,
                  style: HeroIconStyle.solid,
                  color: cs.primary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This organization is verified.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ] else if (suspended) ...[
            const SizedBox(height: 16),
            Text(
              'This organization is suspended. Contact support.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ] else if (pendingReview) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.primaryFixed.withOpacity(0.25),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HeroIcon(
                    HeroIcons.clock,
                    style: HeroIconStyle.outline,
                    color: cs.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Documents submitted. Waiting for verification.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            height: 1.4,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 20),
            TextField(
              controller: _licenseCtrl,
              decoration: InputDecoration(
                labelText: 'Business license number (optional)',
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _taxCtrl,
              decoration: InputDecoration(
                labelText: 'Tax ID (optional)',
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Documents',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 10),
            _KybUploadPanel(
              title: 'Business license document',
              subtitle: 'PDF, JPG or PNG (max. 10MB)',
              icon: HeroIcons.documentText,
              fileLabel: _licenseDoc?.path.split('/').last ?? 'Not selected',
              onTap: _submitting ? null : () => _showSourceSheet(license: true),
            ),
            const SizedBox(height: 12),
            const SoftListDivider(),
            const SizedBox(height: 12),
            _KybUploadPanel(
              title: 'Representative ID',
              subtitle: 'Passport or government-issued ID',
              icon: HeroIcons.identification,
              fileLabel: _idDoc?.path.split('/').last ?? 'Not selected',
              onTap:
                  _submitting ? null : () => _showSourceSheet(license: false),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: cs.error),
                ),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit for review'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _KybShell extends StatelessWidget {
  const _KybShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final panelFill = Color.lerp(
      AppTheme.backgroundColor,
      cs.surfaceContainer,
      0.42,
    )!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: panelFill,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.editorialShadow,
      ),
      child: child,
    );
  }
}

class _KybUploadPanel extends StatelessWidget {
  const _KybUploadPanel({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.fileLabel,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final HeroIcons icon;
  final String fileLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const radius = 16.0;
    final mutedDash = cs.outline.withOpacity(0.38);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              Ink(
                decoration: const BoxDecoration(
                  color: AppTheme.surfaceColor,
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: cs.primaryFixed.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: HeroIcon(
                          icon,
                          style: HeroIconStyle.outline,
                          color: cs.primary,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              fileLabel,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: cs.primary,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: onTap,
                        child: const Text('Choose'),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _KybDashedRRectPainter(
                      color: mutedDash,
                      borderRadius: radius,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Muted dashed stroke for document upload tiles (no solid outline).
class _KybDashedRRectPainter extends CustomPainter {
  _KybDashedRRectPainter({
    required this.color,
    required this.borderRadius,
    this.strokeWidth = 1,
  });

  final Color color;
  final double borderRadius;
  final double strokeWidth;

  static const double _dashLength = 4;
  static const double _gapLength = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final half = strokeWidth / 2;
    final rect = Rect.fromLTWH(
      half,
      half,
      math.max(0, size.width - strokeWidth),
      math.max(0, size.height - strokeWidth),
    );
    final rr = math.min(borderRadius - half, rect.shortestSide / 2);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(rr));
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    for (final metric in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        final seg = math.min(_dashLength, metric.length - dist);
        canvas.drawPath(metric.extractPath(dist, dist + seg), paint);
        dist += _dashLength + _gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _KybDashedRRectPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.strokeWidth != strokeWidth;
}
