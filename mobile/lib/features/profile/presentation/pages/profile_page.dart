import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vaxiil_mobile/core/biometric/biometric_service.dart';
import 'package:vaxiil_mobile/core/constants/app_constants.dart';
import 'package:vaxiil_mobile/core/constants/app_routes.dart';
import 'package:vaxiil_mobile/core/di/injection_container.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';
import 'package:vaxiil_mobile/core/storage/secure_storage_service.dart';
import 'package:vaxiil_mobile/core/theme/theme_manager.dart';
import 'package:vaxiil_mobile/features/auth/domain/entities/auth_user.dart';
import 'package:vaxiil_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vaxiil_mobile/features/bookings/data/bookings_repository.dart';
import 'package:vaxiil_mobile/l10n/app_localizations.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';
import 'package:vaxiil_mobile/shared/themes/vaxiil_text.dart';
import 'package:vaxiil_mobile/shared/utils/responsive.dart';
import 'package:vaxiil_mobile/shared/utils/shell_nav.dart';
import 'package:vaxiil_mobile/shared/widgets/vaxiil_app_drawer.dart';
import 'package:vaxiil_mobile/shared/widgets/vaxiil_frosted_top_bar.dart';
import 'package:vaxiil_mobile/shared/widgets/vaxiil_site_footer.dart';

/// Stitch profile: large avatar, trust alias, business, KYC, settings, appearance.
const double _kProfileAvatarRadius = 64;
const double _kTopBarBodyPadding = 56;

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _biometric = BiometricService();
  final _storage = SecureStorageService();
  var _biometricOn = false;
  var _biometricAvailable = false;
  RefundWalletSummary? _wallet;

  @override
  void initState() {
    super.initState();
    _loadBiometric();
    _loadWallet();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthCubit>().refreshProfile();
    });
  }

  Future<void> _loadWallet() async {
    try {
      final wallet = await sl<BookingsRepository>().getWallet();
      if (mounted) {
        setState(() => _wallet = wallet);
      }
    } catch (_) {
      // Wallet is optional on profile.
    }
  }

  Future<void> _loadBiometric() async {
    final enabled = await _storage.isBiometricEnabled();
    final can = await _biometric.canAuthenticate;
    if (mounted) {
      setState(() {
        _biometricOn = enabled;
        _biometricAvailable = can;
      });
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      final ok = await _biometric.authenticate(
        reason: 'Enable biometric unlock for Vaxiil',
      );
      if (!ok) return;
      await _storage.saveBiometricEnabled(true);
    } else {
      await _storage.saveBiometricEnabled(false);
    }
    setState(() => _biometricOn = value);
  }

  Future<void> _copySupportEmail(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: AppConstants.supportEmail));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${AppConstants.supportEmail} copied to clipboard'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthCubit>().state.user;
    final loading = context.watch<AuthCubit>().state.isLoading;
    final cs = Theme.of(context).colorScheme;
    final vt = VaxiilText.of(context);
    final topInset = MediaQuery.of(context).padding.top;
    final expanded = context.isExpandedShell;
    final barHeight = expanded ? 8.0 : topInset + _kTopBarBodyPadding;
    final bottomPad = MediaQuery.of(context).padding.bottom + 100;

    final verified = user?.verificationStatus?.value == 'V';
    final rejected = user?.verificationStatus?.value == 'R';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarBrightness: Brightness.light,
        statusBarIconBrightness: Brightness.dark,
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: cs.surface,
      ),
      child: Scaffold(
        key: _scaffoldKey,
        primary: false,
        backgroundColor: cs.surface,
        drawer: const VaxiilAppDrawer(),
        body: Stack(
          fit: StackFit.expand,
          children: [
            RefreshIndicator(
              color: cs.primary,
              onRefresh: () async {
                await context.read<AuthCubit>().refreshProfile();
                await _loadWallet();
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(
                  top: barHeight + 8,
                  bottom: context.isExpandedShell ? 32 : bottomPad,
                ),
                children: [
                  ResponsiveContent(
                    narrowMaxWidth: 672,
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ProfileHeader(
                          displayName: user?.displayName ?? 'Member',
                          email: user?.email ?? '',
                          avatarUrl: user?.avatarUrl,
                          verified: verified,
                          onEditAvatar: () => context.push(AppRoutes.editProfile),
                          cs: cs,
                        ),
                        const SizedBox(height: 24),
                        _TrustAliasCard(
                          trustAlias: user?.trustAlias,
                          hideRealIdentity: !(user?.showRealName ?? false),
                          loading: loading,
                          onChanged: (hide) {
                            context.read<AuthCubit>().updateProfileFields(
                                  showRealName: !hide,
                                );
                          },
                          onRegenerate: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Regenerate Trust Alias?'),
                                content: const Text(
                                  'Anyone who only knows your old alias will no longer find you.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Regenerate'),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true && context.mounted) {
                              await context.read<AuthCubit>().regenerateTrustAlias();
                            }
                          },
                          vt: vt,
                          cs: cs,
                        ),
                        const SizedBox(height: 16),
                        if (_wallet != null) ...[
                          _EscrowWalletCard(
                            wallet: _wallet!,
                            cs: cs,
                            onTopUpComplete: _loadWallet,
                          ),
                          const SizedBox(height: 16),
                        ],
                        _BusinessCard(
                          kycVerified: verified,
                          onOpen: () => context.go(AppRoutes.business),
                          cs: cs,
                          vt: vt,
                        ),
                        const SizedBox(height: 16),
                        if (verified)
                          _KycVerifiedCard(
                            verifiedAt: user?.verifiedAt,
                            onInfoTap: () => _showVerificationInfo(context, user),
                            cs: cs,
                            vt: vt,
                          )
                        else
                          _KycNotVerifiedCard(
                            rejected: rejected,
                            rejectionReason: user?.verificationRejectionReason,
                            onStartVerification: () =>
                                context.push(AppRoutes.identityVerification),
                            cs: cs,
                            vt: vt,
                          ),
                        const SizedBox(height: 24),
                        _SectionLabel(text: 'Account settings', cs: cs),
                        const SizedBox(height: 8),
                        _SettingsCard(
                          children: [
                            _SettingsTile(
                              icon: HeroIcons.user,
                              label: 'Personal information',
                              onTap: () => context.push(AppRoutes.editProfile),
                              cs: cs,
                            ),
                            _Divider(cs: cs),
                            _SettingsTile(
                              icon: HeroIcons.key,
                              label: 'Security & password',
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Use “Forgot password” on the login screen to reset your password.',
                                    ),
                                  ),
                                );
                              },
                              cs: cs,
                            ),
                            _Divider(cs: cs),
                            _SettingsTile(
                              icon: HeroIcons.bellAlert,
                              label: 'Notification preferences',
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Notification settings will be available in a future update.',
                                    ),
                                  ),
                                );
                              },
                              cs: cs,
                            ),
                            _Divider(cs: cs),
                            _SettingsTile(
                              icon: HeroIcons.informationCircle,
                              label: 'About Vaxiil',
                              onTap: () => context.push(AppRoutes.about),
                              cs: cs,
                            ),
                            if (_biometricAvailable) ...[
                              _Divider(cs: cs),
                              _SettingsTile(
                                icon: HeroIcons.fingerPrint,
                                label: 'Biometric unlock',
                                trailing: Switch.adaptive(
                                  value: _biometricOn,
                                  onChanged: _toggleBiometric,
                                  activeColor: cs.primary,
                                ),
                                onTap: () => _toggleBiometric(!_biometricOn),
                                cs: cs,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 24),
                        _SectionLabel(text: 'Appearance', cs: cs),
                        const SizedBox(height: 8),
                        ListenableBuilder(
                          listenable: ThemeManager(),
                          builder: (context, _) {
                            final tm = ThemeManagerProvider.of(context);
                            final darkOn = tm.isDarkTheme;
                            return _SettingsCard(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 4,
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    leading: HeroIcon(
                                      HeroIcons.moon,
                                      style: HeroIconStyle.outline,
                                      color: cs.primary,
                                    ),
                                    title: Text(
                                      'Dark mode',
                                      style: vt.body16OnSurface.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    trailing: Switch.adaptive(
                                      value: darkOn,
                                      onChanged: (v) async {
                                        await tm.setThemeMode(
                                          v
                                              ? ThemeModeOption.dark
                                              : ThemeModeOption.light,
                                        );
                                      },
                                      activeColor: cs.primary,
                                    ),
                                    onTap: () async {
                                      await tm.setThemeMode(
                                        darkOn
                                            ? ThemeModeOption.light
                                            : ThemeModeOption.dark,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => context.push(AppRoutes.theme),
                          child: const Text('More appearance options'),
                        ),
                        const SizedBox(height: 16),
                        _SupportBox(
                          verified: verified,
                          onContact: () => _copySupportEmail(context),
                          cs: cs,
                          vt: vt,
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: cs.error,
                            foregroundColor: cs.onError,
                            minimumSize: const Size.fromHeight(52),
                          ),
                          onPressed: () => context.read<AuthCubit>().logout(),
                          icon: HeroIcon(
                            HeroIcons.arrowRightOnRectangle,
                            style: HeroIconStyle.outline,
                            color: cs.onError,
                            size: 22,
                          ),
                          label: const Text('Sign out'),
                        ),
                      ],
                    ),
                  ),
                  const VaxiilSiteFooter(),
                ],
              ),
            ),
            if (!expanded)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: VaxiilFrostedTopBar(
                  topPadding: topInset,
                  onMenu: () => _scaffoldKey.currentState?.openDrawer(),
                  onAvatarTap: () => context.push(AppRoutes.editProfile),
                  avatarUrl: user?.avatarUrl,
                  selectedNavIndex: mainShellSelectedIndex(context),
                  onNavTap: (i) => goMainShellBranch(context, i),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showVerificationInfo(BuildContext context, AuthUser? user) {
    final cs = Theme.of(context).colorScheme;
    final verifiedAt = user?.verifiedAt;
    String? formatted;
    if (verifiedAt != null && verifiedAt.isNotEmpty) {
      try {
        formatted = DateFormat.yMMMd().format(DateTime.parse(verifiedAt));
      } catch (_) {
        formatted = verifiedAt;
      }
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Identity verification'),
        content: Text(
          formatted != null
              ? 'Verified on $formatted.'
              : 'Your identity is verified.',
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.displayName,
    required this.email,
    required this.avatarUrl,
    required this.verified,
    required this.onEditAvatar,
    required this.cs,
  });

  final String displayName;
  final String email;
  final String? avatarUrl;
  final bool verified;
  final VoidCallback onEditAvatar;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            _LargeAvatar(
              radius: _kProfileAvatarRadius,
              avatarUrl: avatarUrl,
              verified: verified,
              surfaceColor: cs.surfaceContainerHighest,
              onSurfaceVariant: cs.onSurfaceVariant,
              primary: cs.primary,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Material(
                color: cs.primary,
                shape: const CircleBorder(),
                elevation: 4,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onEditAvatar,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: HeroIcon(
                      HeroIcons.pencil,
                      style: HeroIconStyle.outline,
                      color: cs.onPrimary,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                displayName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 28,
                    ),
              ),
            ),
            if (verified) ...[
              const SizedBox(width: 6),
              HeroIcon(
                HeroIcons.checkBadge,
                style: HeroIconStyle.solid,
                color: cs.primary,
                size: 28,
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          email,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: cs.secondary,
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }
}

class _LargeAvatar extends StatelessWidget {
  const _LargeAvatar({
    required this.radius,
    required this.avatarUrl,
    required this.verified,
    required this.surfaceColor,
    required this.onSurfaceVariant,
    required this.primary,
  });

  final double radius;
  final String? avatarUrl;
  final bool verified;
  final Color surfaceColor;
  final Color onSurfaceVariant;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = avatarUrl?.trim();
    final iconSize = radius * 1.0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: scheme.surfaceContainerLowest,
              width: 4,
            ),
            boxShadow: AppTheme.editorialShadow,
          ),
          child: CircleAvatar(
            radius: radius,
            backgroundColor: surfaceColor,
            child: url != null && url.isNotEmpty
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: url,
                      width: radius * 2,
                      height: radius * 2,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => ColoredBox(
                        color: surfaceColor,
                        child: Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                : HeroIcon(
                    HeroIcons.user,
                    style: HeroIconStyle.outline,
                    size: iconSize,
                    color: onSurfaceVariant,
                  ),
          ),
        ),
        if (verified)
          Positioned(
            right: 4,
            bottom: 4,
            child: Material(
              color: primary,
              shape: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.check, size: 14, color: scheme.onPrimary),
              ),
            ),
          ),
      ],
    );
  }
}

class _TrustAliasCard extends StatelessWidget {
  const _TrustAliasCard({
    required this.trustAlias,
    required this.hideRealIdentity,
    required this.loading,
    required this.onChanged,
    required this.onRegenerate,
    required this.vt,
    required this.cs,
  });

  final String? trustAlias;
  final bool hideRealIdentity;
  final bool loading;
  final ValueChanged<bool> onChanged;
  final VoidCallback onRegenerate;
  final VaxiilText vt;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: HeroIcon(
                      HeroIcons.shieldCheck,
                      style: HeroIconStyle.solid,
                      color: cs.primary,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trust Alias',
                        style: vt.body16OnSurface.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Hide real identity during initial inquiries',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSecondaryContainer,
                            ),
                      ),
                      if (trustAlias != null && trustAlias!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          trustAlias!,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: cs.primary,
                                letterSpacing: 0.5,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (loading)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Switch.adaptive(
                    value: hideRealIdentity,
                    onChanged: onChanged,
                    activeColor: cs.primary,
                  ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: loading ? null : onRegenerate,
                child: const Text('Regenerate alias'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EscrowWalletCard extends StatefulWidget {
  const _EscrowWalletCard({
    required this.wallet,
    required this.cs,
    required this.onTopUpComplete,
  });

  final RefundWalletSummary wallet;
  final ColorScheme cs;
  final VoidCallback onTopUpComplete;

  @override
  State<_EscrowWalletCard> createState() => _EscrowWalletCardState();
}

class _EscrowWalletCardState extends State<_EscrowWalletCard> {
  final _amount = TextEditingController();
  var _submitting = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _topUp() async {
    final amount = _amount.text.trim();
    if (amount.isEmpty || (double.tryParse(amount) ?? 0) <= 0) {
      setState(() => _error = AppLocalizations.of(context).escrowTopUpAmount);
      return;
    }
    final currency = widget.wallet.balances.isNotEmpty
        ? widget.wallet.balances.first.currencyCode
        : 'USD';
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await sl<BookingsRepository>().createWalletTopUp(
        amount: amount,
        currencyCode: currency,
      );
      final url = result.url ?? '';
      if (url.isEmpty) {
        throw const NetworkFailure(
          message: 'Top-up link was empty',
          code: 'TOP_UP_EMPTY',
        );
      }
      final ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!ok && mounted) {
        setState(() => _error = 'Could not open the payment page.');
      } else {
        widget.onTopUpComplete();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is Failure ? e.message : e.toString();
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = widget.cs;
    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_outlined,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.escrowBalanceTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.escrowBalanceHint,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 12),
                      if (widget.wallet.balances.isEmpty)
                        Text(
                          '0.00',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        )
                      else
                        ...widget.wallet.balances.map(
                          (row) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '${row.balance} ${row.currencyCode}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              l10n.escrowTopUpHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.escrowTopUpAmount,
              ),
              enabled: !_submitting,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: cs.error),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _submitting ? null : _topUp,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.escrowTopUpSubmit),
            ),
          ],
        ),
      ),
    );
  }
}

class _BusinessCard extends StatelessWidget {
  const _BusinessCard({
    required this.kycVerified,
    required this.onOpen,
    required this.cs,
    required this.vt,
  });

  final bool kycVerified;
  final VoidCallback onOpen;
  final ColorScheme cs;
  final VaxiilText vt;

  @override
  Widget build(BuildContext context) {
    final title = kycVerified ? 'Business profile' : 'Business account';
    final subtitle = kycVerified
        ? 'Switch to your organizational workspace'
        : 'Register as a service provider or agency';

    return Material(
      color: cs.primaryContainer,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: cs.onPrimaryContainer.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: HeroIcon(
                  HeroIcons.buildingOffice2,
                  style: HeroIconStyle.solid,
                  color: cs.onPrimaryContainer,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: vt.body16OnSurface.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onPrimaryContainer.withOpacity(0.85),
                          ),
                    ),
                  ],
                ),
              ),
              HeroIcon(
                HeroIcons.arrowRight,
                style: HeroIconStyle.outline,
                color: cs.onPrimaryContainer.withOpacity(0.6),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KycNotVerifiedCard extends StatelessWidget {
  const _KycNotVerifiedCard({
    required this.rejected,
    required this.rejectionReason,
    required this.onStartVerification,
    required this.cs,
    required this.vt,
  });

  final bool rejected;
  final String? rejectionReason;
  final VoidCallback onStartVerification;
  final ColorScheme cs;
  final VaxiilText vt;

  @override
  Widget build(BuildContext context) {
    final orange = const Color(0xFFF57C00);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.editorialShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KYC verification',
                      style: vt.body16OnSurface.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: orange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: orange,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            rejected ? 'Rejected' : 'Not verified',
                            style: TextStyle(
                              color: orange,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                                letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              HeroIcon(
                HeroIcons.shieldCheck,
                style: HeroIconStyle.outline,
                color: orange.withOpacity(0.35),
                size: 40,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            rejected && (rejectionReason?.isNotEmpty ?? false)
                ? rejectionReason!
                : 'Unlock higher transaction limits and verified badges by completing our secure, privacy-first identity verification.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 12),
          Material(
            color: cs.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: onStartVerification,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: cs.primary.withOpacity(0.2),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  children: [
                    HeroIcon(
                      HeroIcons.fingerPrint,
                      style: HeroIconStyle.outline,
                      color: cs.primary,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Start personal verification',
                      style: vt.body16OnSurface.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Required for secure transactions',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.secondary,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KycVerifiedCard extends StatelessWidget {
  const _KycVerifiedCard({
    required this.verifiedAt,
    required this.onInfoTap,
    required this.cs,
    required this.vt,
  });

  final String? verifiedAt;
  final VoidCallback onInfoTap;
  final ColorScheme cs;
  final VaxiilText vt;

  @override
  Widget build(BuildContext context) {
    String? formatted;
    if (verifiedAt != null && verifiedAt!.isNotEmpty) {
      try {
        formatted = DateFormat.yMMMd().format(DateTime.parse(verifiedAt!));
      } catch (_) {
        formatted = verifiedAt;
      }
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.editorialShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KYC verification',
                      style: vt.body16OnSurface.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: cs.primary.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check,
                            size: 14,
                            color: cs.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Verified',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: cs.primary,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              HeroIcon(
                HeroIcons.shieldCheck,
                style: HeroIconStyle.solid,
                color: cs.primary,
                size: 40,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Your identity has been successfully verified. You now have access to higher transaction limits and enhanced platform features.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 12),
          Material(
            color: cs.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onInfoTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    HeroIcon(
                      HeroIcons.fingerPrint,
                      style: HeroIconStyle.outline,
                      color: cs.primary,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Identity managed',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: cs.primary,
                                ),
                          ),
                          if (formatted != null)
                            Text(
                              'Verified on $formatted',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: cs.secondary,
                                    fontSize: 10,
                                  ),
                            ),
                        ],
                      ),
                    ),
                    HeroIcon(
                      HeroIcons.informationCircle,
                      style: HeroIconStyle.outline,
                      color: cs.primary.withOpacity(0.4),
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, required this.cs});

  final String text;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: cs.secondary.withOpacity(0.6),
            ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: cs.outlineVariant.withOpacity(0.35),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.cs,
    this.trailing,
  });

  final HeroIcons icon;
  final String label;
  final VoidCallback onTap;
  final ColorScheme cs;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              HeroIcon(
                icon,
                style: HeroIconStyle.outline,
                color: cs.primary,
                size: 22,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              trailing ??
                  HeroIcon(
                    HeroIcons.chevronRight,
                    style: HeroIconStyle.outline,
                    color: cs.onSurfaceVariant.withOpacity(0.4),
                    size: 20,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportBox extends StatelessWidget {
  const _SupportBox({
    required this.verified,
    required this.onContact,
    required this.cs,
    required this.vt,
  });

  final bool verified;
  final VoidCallback onContact;
  final ColorScheme cs;
  final VaxiilText vt;

  @override
  Widget build(BuildContext context) {
    final title = verified
        ? 'Need to update your verification details?'
        : 'Need help with your verification?';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cs.primary.withOpacity(0.12),
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.secondary,
                ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onContact,
            child: Text(
              'Contact Vaxiil concierge',
              style: vt.viewAllLink.copyWith(
                decoration: TextDecoration.underline,
                decorationColor: cs.primary.withOpacity(0.35),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
