import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/notification_service.dart';
import '../theme/app_theme.dart';

/// Notification on/off toggle — reached via the gear icon in the inbox.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen>
    with WidgetsBindingObserver {
  bool _enabled = true;
  bool _loading = true;
  bool _saving = false;
  NotificationPermissionState _permission = NotificationPermissionState.unknown;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_saving) {
      _load();
    }
  }

  Future<void> _load() async {
    final service = NotificationService.instance;
    final enabled = await service.areNotificationsEnabled();
    final permission = await service.permissionState();
    if (mounted) {
      setState(() {
        _enabled = enabled && permission == NotificationPermissionState.granted;
        _permission = permission;
        _loading = false;
      });
    }
  }

  Future<void> _toggle(bool value) async {
    if (_saving) return;
    setState(() => _saving = true);
    final service = NotificationService.instance;
    final enabled = await service.setNotificationsEnabled(value);
    final permission = await service.permissionState();
    if (!mounted) return;
    setState(() {
      _enabled = enabled && value;
      _permission = permission;
      _saving = false;
    });
    if (value && !enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            kIsWeb
                ? 'Browser notifications were not enabled. Allow them in site settings and try again.'
                : 'Notifications are blocked. Allow FinReels in system notification settings.',
          ),
          action: kIsWeb
              ? null
              : SnackBarAction(
                  label: 'OPEN SETTINGS',
                  onPressed: () {
                    service.openSystemNotificationSettings();
                  },
                ),
        ),
      );
    }
  }

  String get _permissionDescription {
    switch (_permission) {
      case NotificationPermissionState.granted:
        return 'Permission granted';
      case NotificationPermissionState.denied:
        return kIsWeb ? 'Blocked by browser' : 'Blocked by system settings';
      case NotificationPermissionState.defaultState:
        return 'Permission not requested';
      case NotificationPermissionState.unsupported:
        return 'Notifications are not supported here';
      case NotificationPermissionState.unknown:
        return 'Permission status unavailable';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor(context),
      appBar: AppBar(
        backgroundColor: AppTheme.bgColor(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded,
              size: 20, color: AppTheme.textColor(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notification Settings',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.gold))
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _enabled
                        ? AppTheme.gold.withValues(alpha: 0.4)
                        : AppTheme.dividerColor(context),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _enabled
                            ? AppTheme.gold.withValues(alpha: 0.12)
                            : AppTheme.dividerColor(context)
                                .withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _enabled
                            ? Icons.notifications_active_rounded
                            : Icons.notifications_off_rounded,
                        color:
                            _enabled ? AppTheme.gold : AppTheme.textMuted(context),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'New video alerts',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '$_permissionDescription · ${kIsWeb ? 'Web foreground check' : 'OS background check'}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: AppTheme.textMuted(context),
                                ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _enabled,
                      onChanged: _saving ? null : _toggle,
                      activeThumbColor: AppTheme.gold,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
