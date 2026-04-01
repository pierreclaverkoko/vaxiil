import 'package:flutter/material.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';

class ServicesPage extends StatelessWidget {
  const ServicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Services')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.spa, size: 64, color: AppTheme.primaryColor),
            SizedBox(height: 16),
            Text('Services Page', style: TextStyle(fontSize: 24)),
            SizedBox(height: 8),
            Text('Browse and search wellness services'),
          ],
        ),
      ),
    );
  }
}
