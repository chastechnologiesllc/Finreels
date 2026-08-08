import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../theme/app_theme.dart';
import 'adsense_banner_impl_stub.dart'
    if (dart.library.html) 'adsense_banner_impl_web.dart' as impl;

/// Web-only AdSense banner using the official test client/slot by default.
/// Mirrors [LabelledBannerAd] placement on Android/iOS.
class AdSenseBanner extends StatelessWidget {
  final double height;

  const AdSenseBanner({super.key, this.height = 90});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            'Ad',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.textMuted(context),
                  fontSize: 10,
                ),
          ),
        ),
        SizedBox(
          width: double.infinity,
          height: height,
          child: impl.buildAdSenseUnit(
            clientId: AppConfig.adsenseClientId,
            slotId: AppConfig.adsenseTestSlot,
            testMode: AppConfig.adsenseTestMode,
          ),
        ),
      ],
    );
  }
}
