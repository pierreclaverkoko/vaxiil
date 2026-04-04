import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaxiil_mobile/shared/widgets/soft_list_divider.dart';

void main() {
  testWidgets('SoftListDivider renders a Divider', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Text('above'),
              SoftListDivider(),
              Text('below'),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(Divider), findsOneWidget);
  });
}
