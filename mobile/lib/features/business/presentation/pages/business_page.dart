import 'package:flutter/material.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';

class BusinessPage extends StatelessWidget {
  const BusinessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Business')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business_center, size: 64, color: AppTheme.primaryColor),
            SizedBox(height: 16),
            Text('Business Page', style: TextStyle(fontSize: 24)),
            SizedBox(height: 8),
            Text('Manage your wellness business'),
          ],
        ),
      ),
    );
  }
}
