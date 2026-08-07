import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/connectivity_service.dart';
import '../theme/app_theme.dart';

/// Wraps the entire app. Shows a tiny, self-dismissing pill at the top-center
/// of the screen when network is unavailable. No retry button — the
/// ConnectivityService polls automatically and the pill disappears the moment
/// a real connection is detected.
///
/// Design rules:
///  • Width: wraps content only (MainAxisSize.min) — never full-width.
///  • Height: auto (~30 px) — icon + single short label.
///  • No retry button, no spinner — the service handles that internally.
///  • checking state: silent (sub-second, flashing it reads as a bug).
///  • App content behind it stays fully interactive at all times.
class ConnectivityOverlay extends StatefulWidget {
  final Widget child;
  const ConnectivityOverlay({required this.child, super.key});

  @override
  State<ConnectivityOverlay> createState() => _ConnectivityOverlayState();
}

class _ConnectivityOverlayState extends State<ConnectivityOverlay> {
  NetworkStatus _status = NetworkStatus.checking;

  @override
  void initState() {
    super.initState();
    _status = ConnectivityService.instance.current;
    ConnectivityService.instance.statusStream.listen((s) {
      if (mounted) setState(() => _status = s);
    });
  }

  @override
  Widget build(BuildContext context) {
    final show = _status == NetworkStatus.noNetwork ||
        _status == NetworkStatus.noInternet;

    return Stack(
      children: [
        widget.child,
        if (show)
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              bottom: false,
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: _NetworkPill(status: _status),
                ),
              ),
            ),
          )
              .animate()
              .slideY(begin: -1.0, end: 0,
                  duration: 260.ms, curve: Curves.easeOutCubic)
              .fadeIn(duration: 180.ms),
      ],
    );
  }
}

class _NetworkPill extends StatelessWidget {
  final NetworkStatus status;
  const _NetworkPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final isNoNet = status == NetworkStatus.noNetwork;
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isNoNet
                  ? Icons.wifi_off_rounded
                  : Icons.signal_wifi_statusbar_connected_no_internet_4_rounded,
              color: AppTheme.gold,
              size: 13,
            ),
            const SizedBox(width: 5),
            Text(
              isNoNet ? 'No network' : 'No internet',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
