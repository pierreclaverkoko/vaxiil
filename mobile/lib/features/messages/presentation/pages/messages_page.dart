import 'package:flutter/material.dart';
import 'package:vaxiil_mobile/shared/themes/vaxiil_text.dart';
import 'package:vaxiil_mobile/shared/utils/responsive.dart';
import 'package:vaxiil_mobile/shared/widgets/vaxiil_site_footer.dart';

/// Placeholder until messaging is implemented.
class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final vt = VaxiilText.of(context);
    final cs = Theme.of(context).colorScheme;
    final expanded = context.isExpandedShell;
    return Scaffold(
      primary: false,
      backgroundColor: cs.surface,
      appBar: expanded
          ? null
          : AppBar(
              title:
                  Text('Messages', style: vt.sectionTitle.copyWith(fontSize: 20)),
              backgroundColor: cs.surface,
              elevation: 0,
            ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Text(
                  'Messages',
                  style: vt.greeting.copyWith(fontSize: 36, color: cs.primary),
                ),
              ),
            ResponsiveContent(
              narrowMaxWidth: 672,
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.5,
                child: Center(
                  child: Text(
                    'Conversations will appear here.',
                    textAlign: TextAlign.center,
                    style: vt.discoverySubtitle,
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
