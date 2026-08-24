import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../data/resource_category_data.dart';
import '../screens/ad_free_screen.dart';
import '../screens/my_business_screen.dart';
import '../screens/privacy_policy_screen.dart';
import '../services/ad_service.dart';
import '../services/consent_service.dart';
import '../services/user_profile_service.dart';
import '../theme/app_theme.dart';
import '../widgets/banner_ad_widget.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _version = '';
  bool _privacyOptionsRequired = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _loadPrivacyOptionsRequirement();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _version = 'v${info.version.replaceAll('-debug', '')}';
      });
    }
  }

  /// Google UMP policy requires this entry point be shown ONLY for users
  /// where a privacy-options choice is actually applicable (EEA/UK/
  /// Switzerland, roughly) — everyone else should see nothing at all, per
  /// Google's own guidance. Checked once per screen visit; cheap local
  /// SDK call, no network round-trip.
  Future<void> _loadPrivacyOptionsRequirement() async {
    final required = await ConsentService.instance.isPrivacyOptionsRequired();
    if (mounted) setState(() => _privacyOptionsRequired = required);
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
    }
  }

  String _myBusinessSubtitle() {
    final selected = UserProfileService.instance.selectedCategoryIds;
    if (selected.isEmpty) {
      return 'Tell us your skill, business or profession';
    }
    final names = selected
        .map((id) => ResourceCategoryData.byId(id)?.name)
        .whereType<String>()
        .toList();
    if (names.isEmpty) return 'Tell us your skill, business or profession';
    return names.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final adsGone = context.watch<AdService>().adsRemoved;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppTheme.bgColor(context),
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                // ── Premium App Bar ─────────────────────────────────────────
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 110,
                  backgroundColor: AppTheme.bgColor(context),
                  surfaceTintColor: Colors.transparent,
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    title: Text(
                      'Profile',
                      style: TextStyle(
                        color: isDark
                            ? AppTheme.darkText
                            : AppTheme.lightText,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    expandedTitleScale: 1.0,
                  ),
                ),

                SliverToBoxAdapter(
                  child: Column(
                    children: [

                      // ── Profile ─────────────────────────────────────────
                      const _SectionHeader('Profile'),
                      _SettingsTile(
                        icon: adsGone
                            ? Icons.verified_rounded
                            : Icons.block_rounded,
                        iconColor: adsGone ? AppTheme.success : AppTheme.gold,
                        title: adsGone ? 'Ad-Free Active' : 'Go Ad-Free',
                        subtitle: adsGone
                            ? 'Enjoy uninterrupted FinReels content'
                            : 'Remove ads and explore FinReels without interruption',
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AdFreeScreen(),
                            ),
                          );
                          if (mounted) setState(() {});
                        },
                      ),

                      // ── Personalize ──────────────────────────────────────
                      const _SectionHeader('Personalize'),
                      _SettingsTile(
                        icon: Icons.storefront_rounded,
                        iconColor: AppTheme.gold,
                        title: 'My Business',
                        subtitle: _myBusinessSubtitle(),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const MyBusinessScreen()),
                          );
                          if (mounted) setState(() {});
                        },
                      ),

                      // ── Support ─────────────────────────────────────────
                      const _SectionHeader('Support'),
                      _SettingsTile(
                        icon: Icons.star_rounded,
                        iconColor: const Color(0xFFFBBF24),
                        title: 'Rate FinReels',
                        subtitle: 'Enjoying the app? Leave us a review!',
                        trailing: const Icon(Icons.chevron_right_rounded,
                            size: 20),
                        onTap: () async {
                          final review = InAppReview.instance;
                          if (await review.isAvailable()) {
                            unawaited(review.requestReview());
                          } else {
                            unawaited(review.openStoreListing(
                                appStoreId: AppConfig.packageName));
                          }
                        },
                      ),
                      _SettingsTile(
                        icon: Icons.headset_mic_rounded,
                        iconColor: const Color(0xFF60A5FA),
                        title: 'Contact Support',
                        subtitle: 'Need help, support, questions or issues',
                        trailing: const Icon(Icons.chevron_right_rounded,
                            size: 20),
                        onTap: () => _launch(
                            'mailto:chastechnologiesllc@gmail.com'
                            '?subject=FinReels%20Support'
                            '&body=Hi%2C%20I%20need%20help%20with%3A%20'),
                      ),

                      // ── Legal ───────────────────────────────────────────
                      const _SectionHeader('Legal'),
                      _SettingsTile(
                        icon: Icons.privacy_tip_rounded,
                        iconColor: AppTheme.gold,
                        title: 'Privacy Policy',
                        subtitle: 'How we collect and use your data',
                        trailing: const Icon(Icons.chevron_right_rounded,
                            size: 20),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const PrivacyPolicyScreen(),
                          ),
                        ),
                      ),
                      // Only shown when Google's UMP SDK reports it's
                      // actually applicable for this user (EEA/UK/
                      // Switzerland) — required so those users can revisit
                      // their ad-consent choice at any time, not just once.
                      if (_privacyOptionsRequired)
                        _SettingsTile(
                          icon: Icons.shield_outlined,
                          iconColor: AppTheme.gold,
                          title: 'Privacy Options',
                          subtitle: 'Manage your ad consent choices',
                          trailing: const Icon(Icons.chevron_right_rounded,
                              size: 20),
                          onTap: ConsentService.instance.showPrivacyOptionsForm,
                        ),
                      _SettingsTile(
                        icon: Icons.description_rounded,
                        iconColor: AppTheme.gold,
                        title: 'Terms of Service',
                        subtitle: 'App usage terms and conditions',
                        trailing: const Icon(Icons.chevron_right_rounded,
                            size: 20),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const TermsOfServiceScreen(),
                          ),
                        ),
                      ),
                      _SettingsTile(
                        icon: Icons.gavel_rounded,
                        iconColor: AppTheme.gold,
                        title: 'Content Disclaimer',
                        subtitle: 'Videos are for educational purposes only',
                        trailing: const Icon(Icons.chevron_right_rounded,
                            size: 20),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ContentDisclaimerScreen(),
                          ),
                        ),
                      ),

                      // ── About ───────────────────────────────────────────
                      const _SectionHeader('About'),
                      _AppInfoCard(version: _version),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Sticky banner at bottom for non-subscribers.
          if (!adsGone) const StickyBannerBar(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Remove Ads Section
// ─────────────────────────────────────────────────────────────────────────────


// ── App info card ─────────────────────────────────────────────────────────────

class _AppInfoCard extends StatelessWidget {
  final String version;
  const _AppInfoCard({required this.version});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: AppTheme.dividerColor(context), width: 0.5),
        ),
        child: Column(
          children: [
            Row(
              children: [
                // App icon — gradient rounded square, WHITE arrow.
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    gradient: const RadialGradient(
                      colors: [
                        AppTheme.goldLight,
                        AppTheme.gold,
                        AppTheme.goldDark,
                      ],
                      center: Alignment.topLeft,
                      radius: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    children: [
                      const Text('FinReels',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16)),
                      Text(
                        'Financial Literacy · Unlocked · $version',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared building blocks
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 10),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.gold,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: AppTheme.dividerColor(context), width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  children: [
                    Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                IconTheme(
                  data: IconThemeData(
                      color: AppTheme.textMuted(context), size: 20),
                  child: trailing!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
