import 'dart:async';
import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';

enum NetworkStatus {
  connected,
  disconnected,
}

class NetworkConnectivity {
  factory NetworkConnectivity() => _instance;
  NetworkConnectivity._internal();
  static final NetworkConnectivity _instance = NetworkConnectivity._internal();
  
  final StreamController<NetworkStatus> _statusController = 
      StreamController<NetworkStatus>.broadcast();
  
  NetworkStatus _currentStatus = NetworkStatus.connected;
  
  // Get current network status
  NetworkStatus get currentStatus => _currentStatus;
  
  // Get network status stream
  Stream<NetworkStatus> get statusStream => _statusController.stream;
  
  // Check if connected
  bool get isConnected => _currentStatus == NetworkStatus.connected;
  
  // Check if disconnected
  bool get isDisconnected => _currentStatus == NetworkStatus.disconnected;
  
  // Initialize connectivity monitoring
  Future<void> initialize() async {
    _currentStatus = NetworkStatus.connected;
    _statusController.add(_currentStatus);
  }
  
  // Check connectivity manually
  Future<NetworkStatus> checkConnectivity() async {
    return _currentStatus;
  }
  
  // Get connectivity result details
  String get connectivityResults => _currentStatus.name;
  
  // Check if WiFi is connected
  bool get isWifiConnected => _currentStatus == NetworkStatus.connected;
  
  // Check if mobile data is connected
  bool get isMobileConnected => _currentStatus == NetworkStatus.connected;
  
  // Check if ethernet is connected
  bool get isEthernetConnected => _currentStatus == NetworkStatus.connected;
  
  // Check if VPN is connected
  bool get isVpnConnected => _currentStatus == NetworkStatus.connected;
  
  // Dispose resources
  void dispose() {
    _statusController.close();
  }
}

// Network connectivity mixin for widgets
mixin NetworkConnectivityMixin<T extends StatefulWidget> on State<T> {
  NetworkStatus _currentNetworkStatus = NetworkStatus.connected;
  StreamSubscription<NetworkStatus>? _subscription;
  
  // Initialize network connectivity monitoring
  void initializeNetworkConnectivity() {
    _subscription = NetworkConnectivity().statusStream.listen((status) {
      setState(() {
        _currentNetworkStatus = status;
      });
      
      if (status == NetworkStatus.disconnected) {
        _showNetworkDialog();
      }
    });
  }
  
  // Show network connection dialog
  void _showNetworkDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('No Internet Connection'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HeroIcon(
              _currentNetworkStatus == NetworkStatus.connected
                  ? HeroIcons.wifi
                  : HeroIcons.signalSlash,
              style: HeroIconStyle.outline,
              size: 48,
              color: _currentNetworkStatus == NetworkStatus.connected
                  ? Colors.green
                  : Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Status: ${_currentNetworkStatus.name}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Connection: ${NetworkConnectivity().connectivityResults}',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  // Dispose network connectivity
  void disposeNetworkConnectivity() {
    _subscription?.cancel();
  }
  
  // Get current network status
  NetworkStatus get networkStatus => _currentNetworkStatus;
  
  // Check if connected
  bool get isNetworkConnected => _currentNetworkStatus == NetworkStatus.connected;
}

// Network connectivity listener for services
class NetworkConnectivityListener {
  
  NetworkConnectivityListener({required this.onStatusChanged});
  final Function(NetworkStatus) onStatusChanged;
  StreamSubscription<NetworkStatus>? _subscription;
  
  // Start listening
  void start() {
    _subscription = NetworkConnectivity().statusStream.listen(onStatusChanged);
  }
  
  // Stop listening
  void stop() {
    _subscription?.cancel();
  }
  
  // Dispose
  void dispose() {
    _subscription?.cancel();
  }
}

// Network connectivity utilities
class NetworkConnectivityUtils {
  // Check if network is available
  static bool isNetworkAvailable() {
    return NetworkConnectivity().isConnected;
  }
  
  // Wait for network connection
  static Future<void> waitForConnection({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final completer = Completer<void>();
    Timer? timer;
    StreamSubscription<NetworkStatus>? statusSubscription;
    
    timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        statusSubscription?.cancel();
        completer.completeError(
          TimeoutException('Network connection timeout', timeout),
        );
      }
    });
    
    statusSubscription = NetworkConnectivity().statusStream.listen((status) {
      if (status == NetworkStatus.connected) {
        timer?.cancel();
        statusSubscription?.cancel();
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    });
    
    // Check current status
    if (NetworkConnectivity().isConnected) {
      timer.cancel();
      statusSubscription.cancel();
      completer.complete();
    }
    
    return completer.future;
  }
  
  // Execute function with network check
  static Future<T> withNetworkCheck<T>(
    Future<T> Function() function, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    await waitForConnection(timeout: timeout);
    return function();
  }
}
