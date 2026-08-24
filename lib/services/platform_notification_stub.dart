/// Native fallback. Native notification delivery is handled by
/// flutter_local_notifications in NotificationService.
String get browserNotificationPermission => 'unsupported';

Future<bool> requestBrowserNotificationPermission() async => false;

Future<bool> showBrowserNotification({
  required String title,
  required String body,
  required String tag,
  String? iconUrl,
}) async => false;
