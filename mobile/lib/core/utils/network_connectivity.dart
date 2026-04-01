import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

enum NetworkStatus {
  connected,
  disconnected,
  connecting,
}

class NetworkConnectivity {
  factory NetworkConnectivity() => _instance;
  NetworkConnectivity._internal();
  static final NetworkConnectivity _instance = NetworkConnectivity._internal();
  
  final StreamController<NetworkStatus> _statusController = 
      StreamController<NetworkStatus>.broadcast();
  
  NetworkStatus _currentStatus = NetworkStatus.disconnected;
  ConnectivityResult _lastResult = ConnectivityResult.none;
  StreamSubscription<ConnectivityResult>? _subscription;
  
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
    try {
      // Get current connectivity status
      _lastResult = await Connectivity().checkConnectivity();
      _updateStatus(_lastResult);
      
      // Listen for connectivity changes
      _subscription = Connectivity().onConnectivityChanged.listen(
        _onConnectivityChanged,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error initializing connectivity: $e');
      }
    }
  }
  
  // Handle connectivity changes
  void _onConnectivityChanged(ConnectivityResult result) {
    if (result != _lastResult) {
      _lastResult = result;
      _updateStatus(result);
    }
  }
  
  // Update network status
  void _updateStatus(ConnectivityResult result) {
    NetworkStatus newStatus;
    
    switch (result) {
      case ConnectivityResult.wifi:
      case ConnectivityResult.ethernet:
      case ConnectivityResult.mobile:
      case ConnectivityResult.vpn:
        newStatus = NetworkStatus.connected;
      case ConnectivityResult.bluetooth:
      case ConnectivityResult.other:
        newStatus = NetworkStatus.connecting;
      case ConnectivityResult.none:
        newStatus = NetworkStatus.disconnected;
    }
    
    if (_currentStatus != newStatus) {
      _currentStatus = newStatus;
      _statusController.add(newStatus);
      
      if (kDebugMode) {
        debugPrint('Network status changed to: $newStatus');
      }
    }
  }
  
  // Check connectivity manually
  Future<NetworkStatus> checkConnectivity() async {
    try {
      final result = await Connectivity().checkConnectivity();
      _lastResult = result;
      _updateStatus(result);
      return _currentStatus;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error checking connectivity: $e');
      }
      return NetworkStatus.disconnected;
    }
  }
  
  // Get connectivity result details
  ConnectivityResult get connectivityResult => _lastResult;
  
  // Check if WiFi is connected
  bool get isWifiConnected => _lastResult == ConnectivityResult.wifi;
  
  // Check if mobile data is connected
  bool get isMobileConnected => _lastResult == ConnectivityResult.mobile;
  
  // Check if ethernet is connected
  bool get isEthernetConnected => _lastResult == ConnectivityResult.ethernet;
  
  // Check if VPN is connected
  bool get isVpnConnected => _lastResult == ConnectivityResult.vpn;
  
  // Dispose resources
  void dispose() {
    _subscription?.cancel();
    _statusController.close();
  }
}

// Network connectivity mixin for widgets
mixin NetworkConnectivityMixin<T extends StatefulWidget> on State<T> {
  late StreamSubscription<NetworkStatus> _networkSubscription;
  NetworkStatus _currentNetworkStatus = NetworkStatus.disconnected;
  
  // Get current network status
  NetworkStatus get networkStatus => _currentNetworkStatus;
  
  // Check if connected
  bool get isNetworkConnected => _currentNetworkStatus == NetworkStatus.connected;
  
  @override
  void initState() {
    super.initState();
    _initializeNetworkMonitoring();
  }
  
  @override
  void dispose() {
    _networkSubscription.cancel();
    super.dispose();
  }
  
  // Initialize network monitoring
  void _initializeNetworkMonitoring() {
    _currentNetworkStatus = NetworkConnectivity().currentStatus;
    _networkSubscription = NetworkConnectivity().statusStream.listen(
      (status) {
        if (mounted) {
          setState(() {
            _currentNetworkStatus = status;
          });
          onNetworkStatusChanged(status);
        }
      },
    );
  }
  
  // Override this method to handle network status changes
  void onNetworkStatusChanged(NetworkStatus status) {
    // Override in subclasses
  }
  
  // Show network status dialog
  void showNetworkStatusDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Network Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _currentNetworkStatus == NetworkStatus.connected 
                  ? Icons.wifi 
                  : Icons.wifi_off,
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
              'Connection: ${NetworkConnectivity().connectivityResult.name}',
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
    _subscription = null;
  }
  
  // Dispose
  void dispose() {
    stop();
  }
}

// Network connectivity utilities
class NetworkUtils {
  // Check if network is available
  static Future<bool> isNetworkAvailable() async {
    final status = await NetworkConnectivity().checkConnectivity();
    return status == NetworkStatus.connected;
  }
  
  // Wait for network connection
  static Future<void> waitForConnection({Duration timeout = const Duration(seconds: 30)}) async {
    final completer = Completer<void>();
    
    if (NetworkConnectivity().isConnected) {
      completer.complete();
      return;
    }
    
    late StreamSubscription<NetworkStatus> subscription;
    subscription = NetworkConnectivity().statusStream.listen(
      (status) {
        if (status == NetworkStatus.connected) {
          subscription.cancel();
          if (!completer.isCompleted) {
            completer.complete();
          }
        }
      },
    );
    
    // Add timeout
    Timer(timeout, () {
      subscription.cancel();
      if (!completer.isCompleted) {
        completer.completeError(TimeoutException('Network connection timeout', timeout));
      }
    });
    
    return completer.future;
  }
  
  // Execute function only when network is available
  static Future<T> withNetwork<T>(
    Future<T> Function() function, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    await waitForConnection(timeout: timeout);
    return function();
  }
}
