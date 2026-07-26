import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vaxiil_mobile/core/constants/app_constants.dart';
import 'package:vaxiil_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vaxiil_mobile/features/auth/presentation/cubit/auth_state.dart';
import 'package:vaxiil_mobile/features/profile/data/sumsub_sdk.dart';
import 'package:vaxiil_mobile/shared/utils/responsive.dart';
import 'package:vaxiil_mobile/shared/widgets/soft_card.dart';
import 'package:vaxiil_mobile/shared/widgets/vaxiil_site_footer.dart';

class IdentityVerificationPage extends StatefulWidget {
  const IdentityVerificationPage({
    super.key,
    this.returnUrl,
    this.sumsubReturnJwt,
    this.sumsubReturnStatus,
    this.sumsubReturnSbx,
  });

  /// When set and the user is verified, navigate here (e.g. booking schedule).
  final String? returnUrl;

  /// Sumsub WebSDK redirect query params (Flutter web return route).
  final String? sumsubReturnJwt;
  final String? sumsubReturnStatus;
  final String? sumsubReturnSbx;

  @override
  State<IdentityVerificationPage> createState() =>
      _IdentityVerificationPageState();
}

class _IdentityVerificationPageState extends State<IdentityVerificationPage> {
  var _didRedirect = false;
  var _starting = false;
  var _processedReturn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _processSumsubReturn();
      _maybeReturn();
    });
  }

  Future<void> _processSumsubReturn() async {
    if (_processedReturn || !mounted) return;
    final jwt = widget.sumsubReturnJwt?.trim();
    if (jwt == null || jwt.isEmpty) return;
    _processedReturn = true;
    final cubit = context.read<AuthCubit>();
    final sbxRaw = widget.sumsubReturnSbx?.trim().toLowerCase();
    final sbx = sbxRaw == null || sbxRaw.isEmpty
        ? null
        : ['1', 'true', 'yes', 'on'].contains(sbxRaw);
    try {
      await cubit.completeSumsubReturn(
        jwt: jwt,
        status: widget.sumsubReturnStatus,
        sbx: sbx,
      );
    } catch (_) {
      if (mounted) {
        await cubit.refreshProfileAfterKyc();
      }
    }
  }

  void _maybeReturn() {
    if (_didRedirect || !mounted) return;
    final returnUrl = widget.returnUrl;
    if (returnUrl == null || returnUrl.isEmpty) return;
    final verified =
        context.read<AuthCubit>().state.user?.isVerified == true;
    if (!verified) return;
    _didRedirect = true;
    context.go(returnUrl);
  }

  Future<void> _startSumsub() async {
    if (_starting) return;
    setState(() => _starting = true);
    final cubit = context.read<AuthCubit>();
    try {
      if (kIsWeb) {
        final origin = AppConstants.resolveKycRedirectOrigin();
        final url = await cubit.createSumsubWebsdkLink(
          successUrl: '$origin/profile/verify/return?status=ok',
          rejectUrl: '$origin/profile/verify/return?status=reject',
        );
        final uri = Uri.parse(url);
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open verification link')),
          );
        }
        await cubit.refreshProfileAfterKyc();
      } else {
        final token = await cubit.fetchSumsubAccessToken();
        await launchSumsubSdk(
          accessToken: token,
          onTokenExpiration: () => cubit.fetchSumsubAccessToken(),
        );
        if (mounted) {
          await cubit.refreshProfileAfterKyc();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _starting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = context.watch<AuthCubit>().state.user;
    final loading = context.watch<AuthCubit>().state.isLoading || _starting;
    final status = user?.verificationStatus;
    final rejection = user?.verificationRejectionReason;
    final verified = status?.value == 'V';
    final inReview = status?.value == 'P';

    return BlocListener<AuthCubit, AuthState>(
      listenWhen: (p, c) =>
          p.errorMessage != c.errorMessage ||
          p.user?.verificationStatus?.value !=
              c.user?.verificationStatus?.value,
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!)),
          );
          context.read<AuthCubit>().clearError();
        }
        if (state.user?.isVerified == true) {
          _maybeReturn();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Identity verification'),
        ),
        body: ListView(
          children: [
            ResponsiveContent(
              narrowMaxWidth: 672,
              padding: const EdgeInsets.all(16),
              child: Column(
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
                              Icon(Icons.check_circle,
                                  color: cs.primary, size: 22),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Your identity is verified.',
                                  style:
                                      Theme.of(context).textTheme.bodyMedium,
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
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: cs.error,
                                ),
                          ),
                        ],
                        if (!verified) ...[
                          const SizedBox(height: 8),
                          Text(
                            inReview
                                ? 'Your verification is in progress. We will update '
                                    'your status when Sumsub finishes review.'
                                : 'Continue with Sumsub to verify your identity. '
                                    'You will be guided through ID and selfie checks.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
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
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: loading ? null : _startSumsub,
                      child: Text(
                        loading
                            ? 'Opening verification…'
                            : status?.value == 'R'
                                ? 'Try again with Sumsub'
                                : 'Continue with Sumsub',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const VaxiilSiteFooter(),
          ],
        ),
      ),
    );
  }
}
