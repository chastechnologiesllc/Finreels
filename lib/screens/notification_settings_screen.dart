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
    extends State<NotificationSettingsScreen> {
  bool _enabled = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled =
        await NotificationService.instance.areNotificationsEnabled();
    if (mounted) setState(() { _enabled = enabled; _loading = false; });
  }

  Future<void> _toggle(bool value) async {
    setState(() => _enabled = value);
    await NotificationService.instance.setNotificationsEnabled(value);
    if (value) await NotificationService.instance.requestPermission();
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
                      child: Text(
                        'New video alerts',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Switch(
                      value: _enabled,
                      onChanged: _toggle,
                      activeColor: AppTheme.gold,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
