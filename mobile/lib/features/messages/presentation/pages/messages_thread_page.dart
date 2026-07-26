import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vaxiil_mobile/core/di/injection_container.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';
import 'package:vaxiil_mobile/features/messages/data/messaging_models.dart';
import 'package:vaxiil_mobile/features/messages/data/messaging_repository.dart';
import 'package:vaxiil_mobile/l10n/app_localizations.dart';

class MessagesThreadPage extends StatefulWidget {
  const MessagesThreadPage({super.key, required this.conversationId});

  final String conversationId;

  @override
  State<MessagesThreadPage> createState() => _MessagesThreadPageState();
}

class _MessagesThreadPageState extends State<MessagesThreadPage> {
  final _repo = sl<MessagingRepository>();
  final _draft = TextEditingController();
  bool _loading = true;
  bool _sending = false;
  String? _error;
  ConversationSummary? _conversation;
  List<ConversationMessageModel> _messages = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final conv = await _repo.getConversation(widget.conversationId);
      final msgs = await _repo.listMessages(widget.conversationId);
      await _repo.markRead(widget.conversationId);
      if (!mounted) return;
      setState(() {
        _conversation = conv;
        _messages = msgs;
        _loading = false;
      });
    } on Failure catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _send() async {
    final body = _draft.text.trim();
    if (body.isEmpty || _conversation?.isBlocked == true) return;
    setState(() => _sending = true);
    try {
      final msg = await _repo.sendMessage(widget.conversationId, body);
      if (!mounted) return;
      setState(() {
        _messages = [..._messages, msg];
        _draft.clear();
        _sending = false;
      });
    } on Failure catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _sending = false;
      });
    }
  }

  Future<void> _toggleBlock() async {
    final conv = _conversation;
    if (conv == null) return;
    try {
      final updated = conv.isBlocked
          ? await _repo.unblock(conv.id)
          : await _repo.block(conv.id);
      if (!mounted) return;
      setState(() => _conversation = updated);
    } on Failure catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final blocked = _conversation?.isBlocked == true;

    return Scaffold(
      appBar: AppBar(
        title: Text(_conversation?.title ?? l10n.messagesThreadFallback),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'block') _toggleBlock();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'block',
                child: Text(blocked ? l10n.messagesUnblock : l10n.messagesBlock),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(_error!, style: TextStyle(color: cs.error)),
                  ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    l10n.messagesPrivacyChip,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) {
                      final msg = _messages[i];
                      final mine = msg.isMine;
                      return Align(
                        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * 0.8,
                          ),
                          decoration: BoxDecoration(
                            color: mine ? cs.primary : cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(20),
                              topRight: const Radius.circular(20),
                              bottomLeft: Radius.circular(mine ? 20 : 0),
                              bottomRight: Radius.circular(mine ? 0 : 20),
                            ),
                          ),
                          child: Text(
                            msg.body,
                            style: TextStyle(
                              color: mine ? cs.onPrimary : cs.onSurface,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (blocked)
                  Material(
                    color: cs.secondary,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.messagesBlockedBanner,
                              style: TextStyle(color: cs.onSecondary),
                            ),
                          ),
                          TextButton(
                            onPressed: _toggleBlock,
                            child: Text(l10n.messagesUnblock),
                          ),
                        ],
                      ),
                    ),
                  ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _draft,
                            enabled: !blocked && !_sending,
                            decoration: InputDecoration(
                              hintText: l10n.messagesComposerPlaceholder,
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(999),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onSubmitted: (_) => _send(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: blocked || _sending ? null : _send,
                          icon: const Icon(Icons.send),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
