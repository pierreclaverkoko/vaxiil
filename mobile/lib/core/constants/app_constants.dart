import 'package:flutter/material.dart';

class AppConstants {
  // App Information
  static const String appName = 'Vaxiil';
  static const String appVersion = '1.0.0';
  
  // API Configuration
  static const String baseUrl = 'http://localhost:8000';
  static const String apiVersion = 'v1';
  static const String apiBaseUrl = '$baseUrl/api/$apiVersion';
  
  // API Endpoints
  static const String authEndpoint = '/auth';
  static const String usersEndpoint = '/users';
  static const String organizationsEndpoint = '/organizations';
  static const String servicesEndpoint = '/services';
  static const String bookingsEndpoint = '/bookings';
  static const String paymentsEndpoint = '/payments';
  
  // Storage Keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userProfileKey = 'user_profile';
  static const String currentBusinessKey = 'current_business';
  static const String themeKey = 'theme_preference';
  static const String languageKey = 'language_preference';
  
  // App Settings
  static const Duration requestTimeout = Duration(seconds: 30);
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 30);
  
  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;
  
  // Cache Settings
  static const Duration cacheExpiration = Duration(hours: 1);
  static const Duration imageCacheExpiration = Duration(days: 7);
  
  // UI Constants
  static const double defaultPadding = 16;
  static const double smallPadding = 8;
  static const double largePadding = 24;
  static const double borderRadius = 12;
  static const double smallBorderRadius = 8;
  
  // Animation Durations
  static const Duration fastAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration slowAnimation = Duration(milliseconds: 500);
  
  // File Size Limits
  static const int maxImageSize = 5 * 1024 * 1024; // 5MB
  static const int maxFileSize = 10 * 1024 * 1024; // 10MB
  
  // Supported Image Formats
  static const List<String> supportedImageFormats = [
    'jpg', 'jpeg', 'png', 'gif', 'webp',
  ];
  
  // WebSocket Configuration
  static const String wsUrl = 'ws://localhost:8000/ws';
  
  // Map Configuration
  static const double defaultMapZoom = 14;
  static const double minMapZoom = 2;
  static const double maxMapZoom = 18;
  
  // Business Hours
  static const TimeOfDay defaultOpeningTime = TimeOfDay(hour: 9, minute: 0);
  static const TimeOfDay defaultClosingTime = TimeOfDay(hour: 17, minute: 0);
  
  // Booking Settings
  static const Duration minBookingDuration = Duration(minutes: 30);
  static const Duration maxBookingDuration = Duration(hours: 8);
  static const Duration bookingAdvanceTime = Duration(hours: 2);
  
  // Notification Settings
  static const Duration notificationShowTime = Duration(seconds: 4);
  static const int maxNotifications = 50;
}
