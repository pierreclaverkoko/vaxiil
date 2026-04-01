import 'package:flutter/material.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_add, size: 64, color: AppTheme.primaryColor),
            SizedBox(height: 16),
            Text('Register Page', style: TextStyle(fontSize: 24)),
            SizedBox(height: 8),
            Text('User registration will be implemented here'),
          ],
        ),
      ),
    );
  }
}
