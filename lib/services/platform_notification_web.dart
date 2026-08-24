import 'dart:js_interop';

import 'package:web/web.dart' as web;

String get browserNotificationPermission {
  try {
    return web.Notification.permission.toString();
  } on Object {
    return 'unsupported';
  }
}

Future<bool> requestBrowserNotificationPermission() async {
  try {
    final permission = await web.Notification.requestPermission().toDart;
    return permission.toDart == 'granted';
  } on Object {
    return false;
  }
}

Future<bool> showBrowserNotification({
  required String title,
  required String body,
  required String tag,
  String? iconUrl,
}) async {
  if (browserNotificationPermission != 'granted') return false;
  try {
    web.Notification(
      title,
      web.NotificationOptions(
        body: body,
        tag: tag,
        icon: iconUrl ?? '',
      ),
    );
    return true;
  } on Object {
    return false;
  }
}
