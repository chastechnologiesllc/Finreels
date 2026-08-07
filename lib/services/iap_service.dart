import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';

import '../config/app_config.dart';
import 'ad_service.dart';
import 'install_source_service.dart';

/// Duration each product grants ad-free access.
const Map<String, Duration> _productDurations = {
  AppConfig.iapNoAds1Day: Duration(days: 1),
  AppConfig.iapNoAdsWeekly: Duration(days: 7),
  AppConfig.iapNoAdsMonthly: Duration(days: 31),
};

class IapService extends ChangeNotifier {
  IapService._();
  static final IapService instance = IapService._();

  final InAppPurchase _iap = InAppPurchase.instance;

  List<ProductDetails> _products = [];
  List<ProductDetails> get products => _products;

  bool _available = false;
  bool get available => _available;

  bool _purchasePending = false;
  bool get purchasePending => _purchasePending;

  String? _error;
  String? get error => _error;

  /// True once install-source detection has actually run (so the UI can
  /// avoid flashing the Play Billing placeholder tiles for the brief
  /// instant before we know which rail to use).
  bool _sourceChecked = false;
  bool get sourceChecked => _sourceChecked;

  /// True → use Google Play Billing. False → this install didn't come
  /// from the Play Store, so the Paystack fallback is used instead for
  /// the exact same products/durations. See InstallSourceService.
  bool _usePlayBilling = true;
  bool get usePlayBilling => _usePlayBilling;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  // ── Init ────────────────────────────────────────────────────────────────────
  Future<void> init() async {
    _usePlayBilling = await InstallSourceService.instance.isPlayStoreInstall();
    _sourceChecked = true;
    notifyListeners();

    if (!_usePlayBilling) {
      // Paystack fallback path — deliberately skip Play Billing entirely.
      // It has nothing real to talk to on a non-Play-Store install, and
      // querying it anyway risks a slow/hanging billing-client connection
      // on devices with broken or absent Play Services.
      _available = false;
      return;
    }

    _available = await _iap.isAvailable();
    if (!_available) {
      _error = 'In-app purchases not available on this device.';
      notifyListeners();
      return;
    }

    _purchaseSub = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (Object e) {
        _error = 'Purchase stream error: $e';
        notifyListeners();
      },
    );

    await _loadProducts();
    await _iap.restorePurchases();
  }

  // ── Load Products ───────────────────────────────────────────────────────────
  Future<void> _loadProducts() async {
    final response = await _iap.queryProductDetails(AppConfig.iapProductIds);
    if (response.error != null) {
      _error = 'Could not load products: ${response.error!.message}';
    }
    _products = response.productDetails
      ..sort((a, b) {
        const order = [
          AppConfig.iapNoAds1Day,
          AppConfig.iapNoAdsWeekly,
          AppConfig.iapNoAdsMonthly,
        ];
        return order.indexOf(a.id).compareTo(order.indexOf(b.id));
      });
    notifyListeners();
  }

  // ── Purchase ────────────────────────────────────────────────────────────────
  Future<void> purchase(ProductDetails product) async {
    _error = null;
    _purchasePending = true;
    notifyListeners();

    final param = PurchaseParam(productDetails: product);
    try {
      await _iap.buyNonConsumable(purchaseParam: param);
    } on Exception catch (e) {
      _purchasePending = false;
      _error = 'Purchase failed: $e';
      notifyListeners();
    }
  }

  /// Grants ad-free access for [productId] after a successful Paystack
  /// checkout — called by SettingsScreen once PaystackCheckoutScreen
  /// returns a non-null reference. If [AppConfig.paystackVerifyEndpoint]
  /// is configured, the reference is verified server-side first; otherwise
  /// the app trusts Paystack's own success redirect directly (see
  /// PaystackService's doc comment for the trust-model rationale).
  /// Returns true if ad-free access was granted.
  Future<bool> completePaystackPurchase({
    required String productId,
    required String reference,
  }) async {
    _error = null;
    _purchasePending = true;
    notifyListeners();

    final duration = _productDurations[productId];
    if (duration == null) {
      _purchasePending = false;
      _error = 'Unknown product.';
      notifyListeners();
      return false;
    }

    if (AppConfig.paystackVerifyEndpoint.isNotEmpty) {
      final verified = await _verifyPaystackReference(reference);
      if (!verified) {
        _purchasePending = false;
        _error = "We couldn't verify that payment. If you were charged, "
            'contact support and we will sort it out.';
        notifyListeners();
        return false;
      }
    }

    await AdService.instance.grantAdFree(duration);
    _purchasePending = false;
    notifyListeners();
    return true;
  }

  Future<bool> _verifyPaystackReference(String reference) async {
    try {
      final uri =
          Uri.parse('${AppConfig.paystackVerifyEndpoint}/$reference');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return false;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['verified'] == true;
    } on Object {
      return false;
    }
  }

  // ── Restore ─────────────────────────────────────────────────────────────────
  Future<void> restorePurchases() async {
    _error = null;
    _purchasePending = true;
    notifyListeners();
    await _iap.restorePurchases();
  }

  // ── Handle Updates ──────────────────────────────────────────────────────────
  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _purchasePending = true;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _purchasePending = false;
          await _fulfil(purchase);
        case PurchaseStatus.canceled:
          _purchasePending = false;
        case PurchaseStatus.error:
          _purchasePending = false;
          _error = purchase.error?.message ?? 'Purchase error';
      }
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
    notifyListeners();
  }

  // ── Fulfil ──────────────────────────────────────────────────────────────────
  Future<void> _fulfil(PurchaseDetails purchase) async {
    final duration = _productDurations[purchase.productID];
    if (duration != null) {
      await AdService.instance.grantAdFree(duration);
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  String friendlyName(String productId) {
    switch (productId) {
      case AppConfig.iapNoAds1Day:
        return 'Remove Ads – 24 Hours';
      case AppConfig.iapNoAdsWeekly:
        return 'Remove Ads – 1 Week';
      case AppConfig.iapNoAdsMonthly:
        return 'Remove Ads – 1 Month';
      default:
        return productId;
    }
  }

  String friendlyPrice(ProductDetails p) => p.price;

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    super.dispose();
  }
}
