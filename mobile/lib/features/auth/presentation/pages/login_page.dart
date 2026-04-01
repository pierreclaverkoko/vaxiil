import 'package:flutter/material.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.login, size: 64, color: AppTheme.primaryColor),
            SizedBox(height: 16),
            Text('Login Page', style: TextStyle(fontSize: 24)),
            SizedBox(height: 8),
            Text('Authentication will be implemented here'),
          ],
        ),
      ),
    );
  }
}
