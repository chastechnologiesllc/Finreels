import 'dart:convert';

import '../config/app_config.dart';

/// Builds the local HTML payload used to drive Paystack's Inline.js popup
/// inside an in-app WebView — see PaystackCheckoutScreen. This needs ONLY
/// the Paystack PUBLIC key (safe to ship client-side) and requires no
/// backend call just to launch the charge UI itself — Paystack's Inline.js
/// product is designed to work exactly this way.
///
/// ── Verification trust model ────────────────────────────────────────────
/// Paystack's own success callback only fires after a real charge attempt
/// completes against their gateway, so it's meaningfully harder to spoof
/// than an app-only flag would be. Still, without a backend the app can't
/// perform the secret-key-gated server-side verification Paystack itself
/// recommends (`GET /transaction/verify/:reference`). If
/// [AppConfig.paystackVerifyEndpoint] is set, IapService verifies the
/// reference against it before granting access. If left empty (the
/// default), the app trusts the WebView's own success redirect directly.
/// See CHECKLIST.md → "Paystack Fallback" and /server in this repo for a
/// ready-to-deploy verification backend whenever you want the stronger
/// guarantee.
class PaystackService {
  PaystackService._();

  /// Same-origin "redirect" URLs the local HTML navigates to on
  /// success/close. Using https-looking URLs (rather than a raw custom
  /// scheme like `finreels://`) keeps this maximally compatible across
  /// WebView versions, some of which block non-http(s) navigation before
  /// shouldOverrideUrlLoading even fires.
  static const String successUrl = 'https://finreels-paystack.local/success';
  static const String closeUrl = 'https://finreels-paystack.local/close';
  static const String baseUrl = 'https://finreels-paystack.local/';

  static String buildCheckoutHtml({
    required String email,
    required int amountSubunits,
    required String reference,
    required String productId,
  }) {
    final key = jsonEncode(AppConfig.paystackPublicKey);
    final em = jsonEncode(email);
    final cur = jsonEncode(AppConfig.paystackCurrency);
    final ref = jsonEncode(reference);
    final pid = jsonEncode(productId);

    return '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=no">
<style>
  html, body { height: 100%; margin: 0; background: #0B0B0B; }
  body {
    font-family: -apple-system, Roboto, sans-serif;
    display: flex; align-items: center; justify-content: center;
    flex-direction: column;
  }
  .msg { color: #D4A84B; font-size: 14px; text-align: center; padding: 24px; }
  .spinner {
    width: 28px; height: 28px; margin-bottom: 14px;
    border: 3px solid rgba(212,168,75,0.25); border-top-color: #D4A84B;
    border-radius: 50%; animation: spin 0.8s linear infinite;
  }
  @keyframes spin { to { transform: rotate(360deg); } }
  .retry {
    margin-top: 14px; color: #0B0B0B; background: #D4A84B; border: none;
    padding: 10px 18px; border-radius: 8px; font-weight: 700; font-size: 13px;
  }
</style>
</head>
<body>
  <div id="status">
    <div class="spinner"></div>
    <div class="msg">Loading secure checkout…</div>
  </div>
  <script src="https://js.paystack.co/v1/inline.js"></script>
  <script>
    function showError(text) {
      document.getElementById('status').innerHTML =
        '<div class="msg">' + text + '</div>' +
        '<button class="retry" onclick="location.reload()">Try again</button>';
    }

    function launchCheckout() {
      if (typeof PaystackPop === 'undefined') {
        showError('Could not load the payment page. Check your connection and try again.');
        return;
      }
      try {
        var handler = PaystackPop.setup({
          key: $key,
          email: $em,
          amount: $amountSubunits,
          currency: $cur,
          ref: $ref,
          metadata: { product_id: $pid, app: 'finreels' },
          callback: function(response) {
            window.location.href =
              "$successUrl?reference=" + encodeURIComponent(response.reference);
          },
          onClose: function() {
            window.location.href = "$closeUrl";
          }
        });
        handler.openIframe();
      } catch (e) {
        showError('Something went wrong starting checkout. Please try again.');
      }
    }

    // Give inline.js up to 6s to arrive before declaring it unreachable.
    var waited = 0;
    var poll = setInterval(function () {
      if (typeof PaystackPop !== 'undefined') {
        clearInterval(poll);
        launchCheckout();
      } else if ((waited += 200) >= 6000) {
        clearInterval(poll);
        showError('Could not reach Paystack. Check your connection and try again.');
      }
    }, 200);
  </script>
</body>
</html>
''';
  }
}
