import 'package:flutter/material.dart';
import 'package:vaxiil_mobile/shared/themes/vaxiil_text.dart';

/// Placeholder until messaging is implemented.
class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final vt = VaxiilText.of(context);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      primary: false,
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text('Messages', style: vt.sectionTitle.copyWith(fontSize: 20)),
        backgroundColor: cs.surface,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Conversations will appear here.',
            textAlign: TextAlign.center,
            style: vt.discoverySubtitle,
          ),
        ),
      ),
    );
  }
}
