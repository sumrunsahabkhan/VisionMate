import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ConnectionStatus { online, offline }

final connectivityStatusProvider = StreamProvider<ConnectionStatus>((ref) {
  final connectivity = Connectivity();
  
  return connectivity.onConnectivityChanged.map((results) {
    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      return ConnectionStatus.offline;
    } else {
      return ConnectionStatus.online;
    }
  });
});

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  Future<ConnectionStatus> checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      return ConnectionStatus.offline;
    }
    return ConnectionStatus.online;
  }
}
