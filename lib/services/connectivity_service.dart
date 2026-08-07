import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

enum NetworkStatus {
  checking,
  online,
  noNetwork,
  noInternet,
}

class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final _statusController = StreamController<NetworkStatus>.broadcast();
  Stream<NetworkStatus> get statusStream => _statusController.stream;

  NetworkStatus _current = NetworkStatus.checking;
  NetworkStatus get current => _current;

  Timer? _pollTimer;
  Timer? _slowPollTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _disposed = false;

  Future<void> init() async {
    await _runCheck();

    _connectivitySub = Connectivity().onConnectivityChanged.listen((_) async {
      await _runCheck();
    });

    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_current != NetworkStatus.online) {
        await _runCheck();
      }
    });

    _slowPollTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (_current == NetworkStatus.online) {
        await _runCheck();
      }
    });
  }

  Future<void> _runCheck() async {
    if (_disposed) return;

    final result = await Connectivity().checkConnectivity();
    final hasAdapter = result.any(
      (r) => r != ConnectivityResult.none && r != ConnectivityResult.bluetooth,
    );

    if (!hasAdapter) {
      _emit(NetworkStatus.noNetwork);
      return;
    }

    final hasData = await _verifyInternetAccess();
    _emit(hasData ? NetworkStatus.online : NetworkStatus.noInternet);
  }

  Future<bool> _verifyInternetAccess() async {
    final endpoints = kIsWeb
        ? AppConfig.connectivityEndpointsWeb
        : AppConfig.connectivityEndpoints;

    var successCount = 0;
    final futures = endpoints.map((url) async {
      try {
        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 5));
        if (response.statusCode >= 200 && response.statusCode < 400) {
          successCount++;
        }
      } on Exception catch (_) {}
    });

    await Future.wait(futures);

    // Web: if CORS-friendly probes all fail but browser reports a live adapter,
    // prefer online so feed loading is not blocked by a false offline state.
    if (kIsWeb && successCount == 0) {
      final result = await Connectivity().checkConnectivity();
      return result.any((r) => r != ConnectivityResult.none);
    }

    return successCount >= 1;
  }

  void _emit(NetworkStatus status) {
    if (_disposed) return;
    if (status != _current) {
      _current = status;
      _statusController.add(status);
    }
  }

  Future<void> retry() => _runCheck();

  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    _slowPollTimer?.cancel();
    unawaited(_connectivitySub?.cancel());
    _statusController.close();
  }
}
