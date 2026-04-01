import 'package:flutter/material.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';

class BookingsPage extends StatelessWidget {
  const BookingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bookings')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 64, color: AppTheme.primaryColor),
            SizedBox(height: 16),
            Text('Bookings Page', style: TextStyle(fontSize: 24)),
            SizedBox(height: 8),
            Text('Manage your wellness appointments'),
          ],
        ),
      ),
    );
  }
}
