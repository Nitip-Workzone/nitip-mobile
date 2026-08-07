import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ConnectivityStatus { isConnected, isDisconnected, notDetermined }

class ConnectivityState {
  final ConnectivityStatus status;
  final bool isPoorConnection;

  ConnectivityState({
    required this.status,
    this.isPoorConnection = false,
  });

  ConnectivityState copyWith({
    ConnectivityStatus? status,
    bool? isPoorConnection,
  }) {
    return ConnectivityState(
      status: status ?? this.status,
      isPoorConnection: isPoorConnection ?? this.isPoorConnection,
    );
  }
}

class ConnectivityNotifier extends StateNotifier<ConnectivityState> {
  ConnectivityNotifier() : super(ConnectivityState(status: ConnectivityStatus.notDetermined)) {
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
      state = state.copyWith(status: ConnectivityStatus.isDisconnected, isPoorConnection: false);
    } else {
      state = state.copyWith(status: ConnectivityStatus.isConnected);
    }
  }

  void setPoorConnection(bool isPoor) {
    if (state.isPoorConnection != isPoor) {
      state = state.copyWith(isPoorConnection: isPoor);
    }
  }
}

final connectivityProvider = StateNotifierProvider<ConnectivityNotifier, ConnectivityState>((ref) {
  return ConnectivityNotifier();
});
