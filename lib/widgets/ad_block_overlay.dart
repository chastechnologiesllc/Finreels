import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/ad_block_service.dart';
import '../services/connectivity_service.dart';
import '../theme/app_theme.dart';

class AdBlockOverlay extends StatefulWidget {
  final Widget child;
  const AdBlockOverlay({required this.child, super.key});

  @override
  State<AdBlockOverlay> createState() => _AdBlockOverlayState();
}

class _AdBlockOverlayState extends State<AdBlockOverlay> {
  AdBlockStatus _adStatus  = AdBlockStatus.checking;
  NetworkStatus  _netStatus = NetworkStatus.checking;
  bool _rechecking = false;

  @override
  void initState() {
    super.initState();
    _adStatus  = AdBlockService.instance.current;
    _netStatus = ConnectivityService.instance.current;
    AdBlockService.instance.statusStream.listen((s) {
      if (mounted) setState(() => _adStatus = s);
    });
    // Belt-and-suspenders: rebuild whenever network state changes so the
    // overlay can NEVER show while the device is offline, even if there's
    // a race between the connectivity stream emitting and AdBlockService
    // resetting its own status.
    ConnectivityService.instance.statusStream.listen((s) {
      if (mounted) setState(() => _netStatus = s);
    });
  }

  Future<void> _recheck() async {
    setState(() => _rechecking = true);
    // Ensure internet is actually up first
    await ConnectivityService.instance.retry();
    await AdBlockService.instance.runCheck();
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() => _rechecking = false);
  }

  @override
  Widget build(BuildContext context) {
    // Two-layer guard:
    // 1. AdBlockService only emits blocked after confirming neutral internet.
    // 2. We ALSO check netStatus here to cover any race between the
    //    connectivity stream and the adblock stream — if the device just
    //    went offline, we suppress the overlay immediately rather than
    //    waiting for AdBlockService to emit 'checking'.
    final blocked = _adStatus  == AdBlockStatus.blocked &&
                    _netStatus == NetworkStatus.online;

    return Stack(
      children: [
        widget.child,
        if (blocked)
          _AdBlockSheet(rechecking: _rechecking, onRecheck: _recheck)
              .animate()
              .fadeIn(duration: 300.ms),
      ],
    );
  }
}

class _AdBlockSheet extends StatelessWidget {
  final bool rechecking;
  final VoidCallback onRecheck;

  const _AdBlockSheet({required this.rechecking, required this.onRecheck});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkBg : AppTheme.lightBg;

    return Material(
      color: bg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              _buildIcon(),
              const SizedBox(height: 32),
              Text(
                'Ad Blocker Detected',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.gold.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppTheme.gold.withValues(alpha: 0.25)),
                ),
                child: Column(
                  children: [
                    Text(
                      'FinReels is free because of ads.',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'An ad blocker is active on your device or network. '
                      'Please disable it for FinReels, then tap "I\'ve Disabled It" below.',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _buildSteps(context),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: rechecking ? null : onRecheck,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.gold,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: rechecking
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.black, strokeWidth: 2.5),
                        )
                      : const Text("I've Disabled It — Check Again",
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
              const Spacer(flex: 3),
              Text(
                'FinReels by chAs Tech Group',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border:
            Border.all(color: AppTheme.error.withValues(alpha: 0.3), width: 1.5),
      ),
      child: const Icon(Icons.block_rounded, size: 48, color: AppTheme.error),
    ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(
        begin: 1.0, end: 1.06, duration: 1800.ms, curve: Curves.easeInOut);
  }

  Widget _buildSteps(BuildContext context) {
    const steps = [
      ('1', 'Open your ad blocker or browser settings'),
      ('2', 'Disable or whitelist FinReels'),
      ('3', 'Return here and tap the button below'),
    ];
    return Column(
      children: steps
          .map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                        color: AppTheme.gold, shape: BoxShape.circle),
                    child: Center(
                      child: Text(s.$1,
                          style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w800,
                              fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(s.$2,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
