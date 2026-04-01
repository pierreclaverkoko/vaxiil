import 'package:flutter/material.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.home, size: 64, color: AppTheme.primaryColor),
            SizedBox(height: 16),
            Text('Home Page', style: TextStyle(fontSize: 24)),
            SizedBox(height: 8),
            Text('Welcome to Vaxiil Wellness Platform'),
          ],
        ),
      ),
    );
  }
}
