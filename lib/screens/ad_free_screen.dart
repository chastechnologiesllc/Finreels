import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../config/app_config.dart';
import '../screens/paystack_checkout_screen.dart';
import '../services/ad_service.dart';
import '../services/iap_service.dart';
import '../theme/app_theme.dart';
import '../widgets/banner_ad_widget.dart';

class AdFreeScreen extends StatelessWidget {
  const AdFreeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final iap = IapService.instance;
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[iap, AdService.instance]),
      builder: (context, _) {
        final adsGone = AdService.instance.adsRemoved;
        return Scaffold(
          backgroundColor: AppTheme.bgColor(context),
          appBar: AppBar(
            backgroundColor: AppTheme.bgColor(context),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: const Text('Go Ad-Free'),
          ),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 20, bottom: 24),
                  child: !adsGone
                      ? _RemoveAdsSection(iap: iap)
                      : _AdsRemovedCard(),
                ),
              ),
              if (!adsGone) const StickyBannerBar(),
            ],
          ),
        );
      },
    );
  }
}
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
