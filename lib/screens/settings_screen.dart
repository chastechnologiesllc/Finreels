import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../data/resource_category_data.dart';
import '../screens/my_business_screen.dart';
import '../screens/paystack_checkout_screen.dart';
import '../screens/privacy_policy_screen.dart';
import '../services/ad_service.dart';
import '../services/consent_service.dart';
import '../services/iap_service.dart';
import '../services/user_profile_service.dart';
import '../theme/app_theme.dart';
import '../widgets/banner_ad_widget.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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
    final iap     = context.watch<IapService>();
    final adsGone = context.watch<AdService>().adsRemoved;
    final isDark  = Theme.of(context).brightness == Brightness.dark;

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
                      'Settings',
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

                      // ── Remove Ads ──────────────────────────────────────
                      if (!adsGone) ...[
                        const _SectionHeader('✦  Go Ad-Free'),
                        _RemoveAdsSection(iap: iap),
                      ] else ...[
                        const _SectionHeader('Subscription'),
                        _AdsRemovedCard(),
                      ],

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

class _RemoveAdsSection extends StatelessWidget {
  final IapService iap;
  const _RemoveAdsSection({required this.iap});

  // ── Paystack helpers ─────────────────────────────────────────────────────

  /// Generates a unique reference for each payment attempt:
  /// `finreels_<productId-suffix>_<timestamp>_<4-random-hex-chars>`.
  static String _makeRef(String productId) {
    final suffix = productId.split('_').last; // "1day", "weekly", "monthly"
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rand = Random.secure().nextInt(0xFFFF).toRadixString(16).padLeft(4, '0');
    return 'finreels_${suffix}_${ts}_$rand';
  }

  Future<void> _launchPaystack(
    BuildContext ctx,
    String productId,
    String title,
  ) async {
    final amount = AppConfig.paystackAmounts[productId];
    if (amount == null) return;

    // Ask for email — required by Paystack Inline to pre-fill the checkout
    // form and to appear in the Paystack dashboard transaction log.
    final email = await _askEmail(ctx);
    if (email == null || !ctx.mounted) return;

    final ref = _makeRef(productId);

    final result = await Navigator.of(ctx).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PaystackCheckoutScreen(
          email: email,
          amountSubunits: amount,
          reference: ref,
          productId: productId,
          title: title,
        ),
      ),
    );

    if (!ctx.mounted) return;

    if (result != null) {
      final granted = await IapService.instance.completePaystackPurchase(
        productId: productId,
        reference: result,
      );
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(
              granted
                  ? '✓ Ad-free access activated!'
                  : 'Payment received — could not activate yet. '
                      'Contact support if this persists.',
            ),
            backgroundColor: granted
                ? const Color(0xFF166534)
                : AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<String?> _askEmail(BuildContext ctx) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor(ctx),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Enter your email',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onSubmitted: (v) => Navigator.of(dCtx).pop(v.trim()),
          decoration: InputDecoration(
            hintText: 'you@example.com',
            hintStyle:
                TextStyle(color: AppTheme.textMuted(ctx), fontSize: 13),
            filled: true,
            fillColor: AppTheme.bgColor(ctx),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.gold)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.gold,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(dCtx).pop(ctrl.text.trim()),
            child: const Text('Continue',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // While the install-source check is still in-flight (completes in a few
    // ms at startup) show a compact loader so the pricing section never
    // flickers between Play / Paystack states mid-render.
    if (!iap.sourceChecked) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: CircularProgressIndicator(
              color: AppTheme.gold, strokeWidth: 2),
        ),
      );
    }

    if (iap.usePlayBilling) {
      return _PlayBillingSection(iap: iap);
    } else {
      return _PaystackSection(iap: iap, launcher: this);
    }
  }
}

// ── Play Billing sub-section ──────────────────────────────────────────────────

class _PlayBillingSection extends StatelessWidget {
  final IapService iap;
  const _PlayBillingSection({required this.iap});

  @override
  Widget build(BuildContext context) {
    void showUnavailable() {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'This offer is not currently available. Please try again later.'),
          backgroundColor: AppTheme.surfaceColor(context),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );
    }

    final hasRealProducts = iap.available && iap.products.isNotEmpty;

    return Column(
      children: [
        _PromoCard(),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: hasRealProducts
                ? iap.products
                    .map((p) => _PricingTile(product: p, iap: iap))
                    .toList()
                : [
                    _PricingTile.placeholder(
                      title: '24 Hours Ad-Free',
                      price: r'$0.99',
                      icon: Icons.timer_outlined,
                      iap: iap,
                      productId: AppConfig.iapNoAds1Day,
                      onUnavailable: showUnavailable,
                    ),
                    _PricingTile.placeholder(
                      title: '1 Week Ad-Free',
                      price: r'$2.99',
                      icon: Icons.calendar_view_week_rounded,
                      iap: iap,
                      productId: AppConfig.iapNoAdsWeekly,
                      onUnavailable: showUnavailable,
                    ),
                    _PricingTile.placeholder(
                      title: '1 Month Ad-Free',
                      price: r'$7.99',
                      icon: Icons.calendar_month_rounded,
                      iap: iap,
                      productId: AppConfig.iapNoAdsMonthly,
                      highlight: true,
                      onUnavailable: showUnavailable,
                    ),
                  ],
          ),
        ),
        // Restore button — only meaningful for Play Billing.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed:
                  iap.purchasePending ? null : iap.restorePurchases,
              child: Text(
                'Restore Previous Purchase',
                style: TextStyle(
                    color: AppTheme.textMuted(context), fontSize: 13),
              ),
            ),
          ),
        ),
        if (iap.error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              iap.error!,
              style: const TextStyle(
                  color: AppTheme.error, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        // Legal micro-copy required by Google Play for one-time purchases.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Text(
            'Payment will be charged to your Google Play account. '
            'Access is granted for the selected period. '
            'Purchases are one-time payments and are non-refundable.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

// ── Paystack sub-section ──────────────────────────────────────────────────────

class _PaystackSection extends StatelessWidget {
  final IapService iap;
  final _RemoveAdsSection launcher;
  const _PaystackSection(
      {required this.iap, required this.launcher});

  // Displayed price is intentionally USD — same figures shown to Play
  // Store users — so pricing reads consistently across both rails no
  // matter which one a given install happens to route through. The
  // ACTUAL charge still runs in Naira (AppConfig.paystackAmounts), since
  // that's what Paystack's checkout is configured to settle in — the USD
  // figure here is a display label only, not sent anywhere.
  static const _tiles = [
    (
      id: AppConfig.iapNoAds1Day,
      title: '24 Hours Ad-Free',
      usdPrice: r'$0.99',
      icon: Icons.timer_outlined,
      highlight: false,
    ),
    (
      id: AppConfig.iapNoAdsWeekly,
      title: '1 Week Ad-Free',
      usdPrice: r'$2.99',
      icon: Icons.calendar_view_week_rounded,
      highlight: false,
    ),
    (
      id: AppConfig.iapNoAdsMonthly,
      title: '1 Month Ad-Free',
      usdPrice: r'$7.99',
      icon: Icons.calendar_month_rounded,
      highlight: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PromoCard(),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: _tiles.map((t) {
              return _PaystackTile(
                title: t.title,
                price: t.usdPrice,
                icon: t.icon,
                highlight: t.highlight,
                loading: iap.purchasePending,
                onTap: () =>
                    launcher._launchPaystack(context, t.id, t.title),
              );
            }).toList(),
          ),
        ),
        if (iap.error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              iap.error!,
              style: const TextStyle(
                  color: AppTheme.error, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Text(
            'Secure payment powered by Paystack. '
            'Access is granted for the selected period. '
            'Payments are one-time and non-refundable.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _PaystackTile extends StatelessWidget {
  final String title;
  final String price;
  final IconData icon;
  final bool highlight;
  final bool loading;
  final VoidCallback onTap;

  const _PaystackTile({
    required this.title,
    required this.price,
    required this.icon,
    required this.highlight,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: highlight
            ? AppTheme.gold.withValues(alpha: 0.07)
            : AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight
              ? AppTheme.gold.withValues(alpha: 0.5)
              : AppTheme.dividerColor(context),
          width: highlight ? 1.5 : 0.5,
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.gold.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppTheme.gold, size: 20),
        ),
        title: Row(
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14)),
            if (highlight) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.gold,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('BEST VALUE',
                    style: TextStyle(
                        color: Colors.black,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5)),
              ),
            ],
          ],
        ),
        subtitle: Text(
          'Removes all ads for the full period',
          style: TextStyle(
              fontSize: 11, color: AppTheme.textMuted(context)),
        ),
        trailing: loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color: AppTheme.gold, strokeWidth: 2))
            : FilledButton(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.gold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(price,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 13)),
              ),
      ),
    );
  }
}


// ── Promo hero card ───────────────────────────────────────────────────────────

class _PromoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A1208), Color(0xFF2C1F06)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: AppTheme.gold.withValues(alpha: 0.35)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.block_rounded,
                      color: AppTheme.gold, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Go Ad-Free',
                  style: TextStyle(
                    color: AppTheme.gold,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Go ad-free and explore all of FinReels without interruption — '
              'videos, shorts, blogs, and 690+ books across 60 business, '
              'skill, and profession categories. No banners. No pop-ups.',
              style: TextStyle(
                color: Color(0xFFD4A84B),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            const Row(
              children: [
                _PromoFeature('No banner ads'),
                SizedBox(width: 16),
                _PromoFeature('No interstitials'),
                SizedBox(width: 16),
                _PromoFeature('No auto-renewal'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PromoFeature extends StatelessWidget {
  final String label;
  const _PromoFeature(this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle_rounded,
            color: AppTheme.gold, size: 14),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                color: Color(0xFFD4A84B),
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ── Pricing tile ──────────────────────────────────────────────────────────────

class _PricingTile extends StatelessWidget {
  final ProductDetails? product;
  final IapService iap;
  final String? _title;
  final String? _price;
  final IconData? _icon;
  final String? _productId;
  final bool highlight;
  final VoidCallback? _onUnavailable;

  const _PricingTile({
    required this.product,
    required this.iap,
  })  : _title = null,
        _price = null,
        _icon = null,
        _productId = null,
        highlight = false,
        _onUnavailable = null;

  const _PricingTile.placeholder({
    required String title,
    required String price,
    required IconData icon,
    required this.iap,
    required String productId,
    this.highlight = false,
    VoidCallback? onUnavailable,
  })  : product = null,
        _title = title,
        _price = price,
        _icon = icon,
        _productId = productId,
        _onUnavailable = onUnavailable;

  static const _meta = <String, (String, IconData)>{
    AppConfig.iapNoAds1Day:
        ('24 Hours Ad-Free', Icons.timer_outlined),
    AppConfig.iapNoAdsWeekly:
        ('1 Week Ad-Free', Icons.calendar_view_week_rounded),
    AppConfig.iapNoAdsMonthly:
        ('1 Month Ad-Free', Icons.calendar_month_rounded),
  };

  @override
  Widget build(BuildContext context) {
    final id    = product?.id ?? _productId ?? '';
    final meta  = _meta[id];
    final title = meta?.$1 ?? _title ?? product?.title ?? id;
    final icon  = meta?.$2 ?? _icon  ?? Icons.shopping_bag_outlined;
    final price = product?.price ?? _price ?? '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: highlight
            ? AppTheme.gold.withValues(alpha: 0.07)
            : AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight
              ? AppTheme.gold.withValues(alpha: 0.5)
              : AppTheme.dividerColor(context),
          width: highlight ? 1.5 : 0.5,
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: AppTheme.gold.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppTheme.gold, size: 20),
        ),
        title: Row(
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14)),
            if (highlight) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.gold,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('BEST VALUE',
                    style: TextStyle(
                        color: Colors.black,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5)),
              ),
            ],
          ],
        ),
        subtitle: Text(
          'Removes all ads for the full period',
          style: TextStyle(
              fontSize: 11, color: AppTheme.textMuted(context)),
        ),
        trailing: iap.purchasePending
            ? const SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(
                    color: AppTheme.gold, strokeWidth: 2))
            : FilledButton(
                onPressed: product != null
                    ? () => unawaited(iap.purchase(product!))
                    : _onUnavailable,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.gold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(price,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 13)),
              ),
      ),
    );
  }
}

// ── Ads removed card ──────────────────────────────────────────────────────────

class _AdsRemovedCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF052E16), Color(0xFF064E3B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: AppTheme.success.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppTheme.success, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                children: [
                  const Text('Ad-Free Active ✓',
                      style: TextStyle(
                          color: AppTheme.success,
                          fontWeight: FontWeight.w800,
                          fontSize: 15)),
                  const SizedBox(height: 3),
                  Text("You're enjoying uninterrupted financial content.",
                      style: TextStyle(
                          color: AppTheme.success.withValues(alpha: 0.8),
                          fontSize: 12,
                          height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
