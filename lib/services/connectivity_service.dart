import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

enum NetworkStatus {
  checking,
  online,
  noNetwork, // No network interface active (airplane mode, no SIM, no WiFi)
  noInternet, // Interface connected but no actual data (captive portal, bad plan)
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

  /// Call once from main() / app init.
  Future<void> init() async {
    // Initial check
    await _runCheck();

    // Listen to OS-level connectivity changes
    _connectivitySub = Connectivity().onConnectivityChanged.listen((_) async {
      await _runCheck();
    });

    // Poll every 5 s when offline, 30 s when online (to catch captive portals)
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_current != NetworkStatus.online) {
        await _runCheck();
      }
    });

    // Slower background check when we think we're online
    _slowPollTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (_current == NetworkStatus.online) {
        await _runCheck();
      }
    });
  }

  Future<void> _runCheck() async {
    if (_disposed) return;

    final result = await Connectivity().checkConnectivity();
    final hasAdapter = result.any((r) => r != ConnectivityResult.none && r != ConnectivityResult.bluetooth);

    if (!hasAdapter) {
      _emit(NetworkStatus.noNetwork);
      return;
    }

    // Adapter is up — verify real data by probing multiple lightweight endpoints
    final hasData = await _verifyInternetAccess();
    _emit(hasData ? NetworkStatus.online : NetworkStatus.noInternet);
  }

  /// Returns true if at least ONE endpoint is reachable.
  /// Uses multiple endpoints to avoid false positives from a single CDN being down.
  Future<bool> _verifyInternetAccess() async {
    var successCount = 0;
    final futures = AppConfig.connectivityEndpoints.map((url) async {
      try {
        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 5));
        // generate_204 returns 204; favicon returns 200
        if (response.statusCode >= 200 && response.statusCode < 400) {
          successCount++;
        }
      } on Exception catch (_) {
        // endpoint unreachable
      }
    });

    await Future.wait(futures);
    return successCount >= 1; // even 1 success means internet is reachable
  }

  void _emit(NetworkStatus status) {
    if (_disposed) return;
    if (status != _current) {
      _current = status;
      _statusController.add(status);
    }
  }

  /// Force an immediate re-check (called from overlay retry button).
  Future<void> retry() => _runCheck();

  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    _slowPollTimer?.cancel();
    unawaited(_connectivitySub?.cancel());
    _statusController.close();
  }
}
