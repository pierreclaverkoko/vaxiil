import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vaxiil_mobile/core/constants/app_routes.dart';
import 'package:vaxiil_mobile/core/di/injection_container.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';
import 'package:vaxiil_mobile/features/messages/data/messaging_models.dart';
import 'package:vaxiil_mobile/features/messages/data/messaging_repository.dart';
import 'package:vaxiil_mobile/l10n/app_localizations.dart';
import 'package:vaxiil_mobile/shared/themes/vaxiil_text.dart';
import 'package:vaxiil_mobile/shared/utils/responsive.dart';
import 'package:vaxiil_mobile/shared/widgets/vaxiil_site_footer.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final _repo = sl<MessagingRepository>();
  bool _loading = true;
  String? _error;
  int _tab = 0;
  List<ConversationSummary> _conversations = [];
  List<ConversationInviteModel> _invites = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final conv = await _repo.listConversations();
      final inv = await _repo.listIncomingInvites();
      if (!mounted) return;
      setState(() {
        _conversations = conv;
        _invites = inv;
        _loading = false;
      });
    } on Failure catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _initials(String? title) {
    final parts = (title ?? '?').replaceAll('_', ' ').trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length.clamp(0, 2)).toUpperCase();
    }
    return ('${parts[0][0]}${parts[1][0]}').toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final vt = VaxiilText.of(context);
    final cs = Theme.of(context).colorScheme;
    final expanded = context.isExpandedShell;

    return Scaffold(
      primary: false,
      backgroundColor: cs.surface,
      appBar: expanded
          ? null
          : AppBar(
              title: Text(l10n.messagesInboxTitle, style: vt.sectionTitle.copyWith(fontSize: 20)),
              backgroundColor: cs.surface,
              elevation: 0,
              actions: [
                IconButton(
                  tooltip: l10n.messagesComposeAria,
                  onPressed: () => context.push(AppRoutes.messagesInvite),
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (expanded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.messagesInboxTitle,
                              style: vt.greeting.copyWith(fontSize: 36, color: cs.primary),
                            ),
                            Text(l10n.messagesInboxSubtitle, style: vt.discoverySubtitle),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => context.push(AppRoutes.messagesInvite),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ],
                  ),
                ),
              ResponsiveContent(
                narrowMaxWidth: 672,
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    SegmentedButton<int>(
                      segments: [
                        ButtonSegment(value: 0, label: Text(l10n.messagesTabConversations)),
                        ButtonSegment(
                          value: 1,
                          label: Text(
                            _invites.isEmpty
                                ? l10n.messagesTabInvitations
                                : '${l10n.messagesTabInvitations} (${_invites.length})',
                          ),
                        ),
                      ],
                      selected: {_tab},
                      onSelectionChanged: (s) => setState(() => _tab = s.first),
                    ),
                    const SizedBox(height: 24),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(48),
                        child: CircularProgressIndicator(),
                      )
                    else if (_error != null)
                      Text(_error!, style: TextStyle(color: cs.error))
                    else if (_tab == 0 && _conversations.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          l10n.messagesEmptyConversations,
                          textAlign: TextAlign.center,
                          style: vt.discoverySubtitle,
                        ),
                      )
                    else if (_tab == 1 && _invites.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          l10n.messagesEmptyInvites,
                          textAlign: TextAlign.center,
                          style: vt.discoverySubtitle,
                        ),
                      )
                    else if (_tab == 0)
                      ..._conversations.map(
                        (c) => Card(
                          elevation: 0,
                          color: c.unread
                              ? cs.surfaceContainerLow
                              : cs.surfaceContainerLowest,
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(child: Text(_initials(c.peerTrustAlias ?? c.title))),
                            title: Text(c.title),
                            subtitle: Text(
                              c.lastMessagePreview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: c.unread
                                ? Text(l10n.messagesNew, style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold, fontSize: 11))
                                : null,
                            onTap: () => context.push('${AppRoutes.messages}/${c.id}'),
                          ),
                        ),
                      )
                    else
                      ..._invites.map(
                        (inv) => Card(
                          elevation: 0,
                          color: cs.surfaceContainerLowest,
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  inv.initiatorTrustAlias ?? l10n.messagesSomeone,
                                  style: vt.sectionTitle,
                                ),
                                const SizedBox(height: 8),
                                Text(l10n.messagesInvitePrivacyNote),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    FilledButton(
                                      onPressed: () async {
                                        final conv = await _repo.acceptInvite(inv.id);
                                        if (context.mounted) {
                                          context.push('${AppRoutes.messages}/${conv.id}');
                                        }
                                      },
                                      child: Text(l10n.messagesAccept),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton(
                                      onPressed: () async {
                                        await _repo.declineInvite(inv.id);
                                        await _load();
                                      },
                                      child: Text(l10n.messagesDecline),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const VaxiilSiteFooter(),
            ],
          ),
        ),
      ),
    );
  }
}
