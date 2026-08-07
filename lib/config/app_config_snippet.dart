// ── Background Task ───────────────────────────────────────────────────────────
// IMPORTANT: On iOS the unique task ID MUST match an entry in
// Info.plist → BGTaskSchedulerPermittedIdentifiers.
// Replace the two lines in lib/config/app_config.dart with:

  static const String rssCheckTaskId   = 'com.chastechgroup.finreels.rsscheck';
  static const String rssCheckTaskName = 'rssCheckTask';
  static const Duration rssCheckFrequency = Duration(minutes: 15);
