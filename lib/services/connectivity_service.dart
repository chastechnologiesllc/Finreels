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
  final Connectivity _connectivity = Connectivity();
  Stream<NetworkStatus> get statusStream => _statusController.stream;

  NetworkStatus _current = NetworkStatus.checking;
  NetworkStatus get current => _current;

  Timer? _pollTimer;
  Timer? _slowPollTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _disposed = false;
  bool _initialized = false;
  Future<void>? _checkInFlight;

  Future<void> init() async {
    if (_initialized || _disposed) return;
    _initialized = true;
    await _runCheck();

    _connectivitySub = _connectivity.onConnectivityChanged.listen((_) {
      unawaited(_runCheck());
    });

    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_current != NetworkStatus.online) {
        unawaited(_runCheck());
      }
    });

    _slowPollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_current == NetworkStatus.online) {
        unawaited(_runCheck());
      }
    });
  }

  /// Coalesces connectivity events, retry taps, and timer ticks into one
  /// probe. A slow or flaky connection must not create overlapping batches of
  /// HTTP requests that compete with feed and blog traffic.
  Future<void> _runCheck() {
    if (_disposed) return Future<void>.value();
    final existing = _checkInFlight;
    if (existing != null) return existing;

    final future = _performCheck();
    _checkInFlight = future;
    return future;
  }

  Future<void> _performCheck() async {
    try {
      final result = await _connectivity.checkConnectivity();
    final hasAdapter = result.any(
      (r) => r != ConnectivityResult.none && r != ConnectivityResult.bluetooth,
    );

    if (!hasAdapter) {
      _emit(NetworkStatus.noNetwork);
      return;
    }

      final hasData = await _verifyInternetAccess();
      _emit(hasData ? NetworkStatus.online : NetworkStatus.noInternet);
    } on Object catch (_) {
      _emit(NetworkStatus.noInternet);
    } finally {
      _checkInFlight = null;
    }
  }

  Future<bool> _verifyInternetAccess() async {
    // Pick platform probe list (both AppConfig lists are compile-time const).
    const endpoints = kIsWeb
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
      final result = await _connectivity.checkConnectivity();
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
