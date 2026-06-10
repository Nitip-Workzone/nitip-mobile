import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ConnectivityStatus { isConnected, isDisconnected, notDetermined }

class ConnectivityNotifier extends StateNotifier<ConnectivityStatus> {
  ConnectivityNotifier() : super(ConnectivityStatus.notDetermined) {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      _updateStatus(results);
    });
    _init();
  }

  Future<void> _init() async {
    final results = await Connectivity().checkConnectivity();
    _updateStatus(results);
  }

  void _updateStatus(List<ConnectivityResult> results) {
    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      state = ConnectivityStatus.isDisconnected;
    } else {
      state = ConnectivityStatus.isConnected;
    }
  }
}

final connectivityProvider = StateNotifierProvider<ConnectivityNotifier, ConnectivityStatus>((ref) {
  return ConnectivityNotifier();
});
