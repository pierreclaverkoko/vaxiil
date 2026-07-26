import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vaxiil_mobile/core/constants/app_routes.dart';
import 'package:vaxiil_mobile/core/di/injection_container.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';
import 'package:vaxiil_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vaxiil_mobile/features/messages/data/messaging_repository.dart';
import 'package:vaxiil_mobile/l10n/app_localizations.dart';
import 'package:vaxiil_mobile/shared/themes/vaxiil_text.dart';

class MessagesInvitePage extends StatefulWidget {
  const MessagesInvitePage({super.key});

  @override
  State<MessagesInvitePage> createState() => _MessagesInvitePageState();
}

class _MessagesInvitePageState extends State<MessagesInvitePage> {
  final _repo = sl<MessagingRepository>();
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _ack;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty) return;
    setState(() {
      _submitting = true;
      _error = null;
      _ack = null;
    });
    try {
      String? email;
      String? phone;
      String? alias;
      if (raw.contains('@')) {
        email = raw;
      } else if (RegExp(r'^\+?[\d\s()-]{6,}$').hasMatch(raw)) {
        phone = raw.replaceAll(RegExp(r'\s'), '');
      } else {
        alias = raw;
      }
      final detail = await _repo.submitInvite(
        email: email,
        phone: phone,
        trustAlias: alias,
      );
      if (!mounted) return;
      setState(() {
        _ack = detail;
        _controller.clear();
        _submitting = false;
      });
    } on Failure catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final vt = VaxiilText.of(context);
    final cs = Theme.of(context).colorScheme;
    final alias = sl<AuthCubit>().state.user?.trustAlias;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.messagesInviteTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            l10n.messagesInviteLede,
            style: vt.discoverySubtitle,
          ),
          const SizedBox(height: 24),
          if (_error != null) Text(_error!, style: TextStyle(color: cs.error)),
          if (_ack != null) ...[
            Text(_ack!),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go(AppRoutes.messages),
              child: Text(l10n.messagesBackToInbox),
            ),
          ] else ...[
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: l10n.messagesInvitePlaceholder,
                prefixIcon: const Icon(Icons.search),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: Text(l10n.messagesSendInvite),
            ),
            const SizedBox(height: 24),
            Text(l10n.messagesInvitePrivacyCard),
          ],
          const SizedBox(height: 32),
          Text(l10n.messagesMyTrustAlias, style: vt.discoverySubtitle),
          Text(alias ?? '—', style: vt.sectionTitle),
        ],
      ),
    );
  }
}
