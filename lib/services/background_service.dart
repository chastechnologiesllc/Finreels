import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';
import '../config/app_config.dart';
import 'notification_service.dart';

/// This function runs in a SEPARATE isolate — no Flutter widgets available.
/// Keep it top-level and annotated with vm:entry-point.
@pragma('vm:entry-point')
void workManagerCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    switch (taskName) {
      case AppConfig.rssCheckTaskName:
        await NotificationService.checkAndNotifyNewVideos();
        break;
    }
    return Future.value(true);
  });
}

class BackgroundService {
  BackgroundService._();
  static final BackgroundService instance = BackgroundService._();

  Future<void> init() async {
    // Workmanager is Android/iOS only — no browser background task API equivalent.
    if (kIsWeb) return;
    WidgetsFlutterBinding.ensureInitialized();
    await Workmanager().initialize(
      workManagerCallbackDispatcher,
    );
  }

  Future<void> registerRssCheck() async {
    if (kIsWeb) return;
    await Workmanager().registerPeriodicTask(
      AppConfig.rssCheckTaskId,
      AppConfig.rssCheckTaskName,
      frequency: AppConfig.rssCheckFrequency,
      initialDelay: const Duration(minutes: 1),
      // workmanager 0.9+ uses ExistingPeriodicWorkPolicy for periodic tasks
      // (ExistingWorkPolicy is only for one-off tasks).
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: false,
      ),
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(minutes: 5),
    );
  }

  Future<void> cancelAll() async {
    if (kIsWeb) return;
    await Workmanager().cancelAll();
  }
}
