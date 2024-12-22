import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:developer' as dev;

class ConnectivityService {
  final Connectivity _connectivity;
  StreamSubscription? _subscription;
  
  ConnectivityService({Connectivity? connectivity}) 
    : _connectivity = connectivity ?? Connectivity() {
    _initConnectivity();
  }

  void _initConnectivity() {
    _subscription = _connectivity.onConnectivityChanged.listen((result) {
      dev.log('ConnectivityService: Connection status changed: $result');
    });
  }

  Future<bool> hasConnection() async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  Stream<bool> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged
        .map((result) => result != ConnectivityResult.none);
  }

  void dispose() {
    _subscription?.cancel();
  }
}

final connectivityProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  ref.onDispose(() => service.dispose());
  return service;
});