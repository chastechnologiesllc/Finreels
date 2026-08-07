import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../services/paystack_service.dart';
import '../theme/app_theme.dart';

/// Presents Paystack's hosted Inline checkout inside an in-app WebView and
/// pops with the transaction reference (String) on success, or null if the
/// user closes/cancels. Used as the IAP fallback for installs that didn't
/// come from the Play Store — see IapService.purchaseViaPaystack and
/// SettingsScreen's pricing tiles.
class PaystackCheckoutScreen extends StatefulWidget {
  final String email;
  final int amountSubunits;
  final String reference;
  final String productId;
  final String title;

  const PaystackCheckoutScreen({
    required this.email,
    required this.amountSubunits,
    required this.reference,
    required this.productId,
    required this.title,
    super.key,
  });

  @override
  State<PaystackCheckoutScreen> createState() =>
      _PaystackCheckoutScreenState();
}

class _PaystackCheckoutScreenState extends State<PaystackCheckoutScreen> {
  bool _loading = true;
  bool _resolved = false;

  void _resolve(String? reference) {
    // Guards against double-pop if multiple navigation events fire in
    // quick succession (some WebView versions briefly re-navigate during
    // 3DS bank redirects).
    if (_resolved || !mounted) return;
    _resolved = true;
    Navigator.of(context).pop(reference);
  }

  @override
  Widget build(BuildContext context) {
    final html = PaystackService.buildCheckoutHtml(
      email: widget.email,
      amountSubunits: widget.amountSubunits,
      reference: widget.reference,
      productId: widget.productId,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _resolve(null);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0B0B),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0B0B0B),
          foregroundColor: Colors.white,
          title: Text(widget.title, style: const TextStyle(fontSize: 15)),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => _resolve(null),
          ),
          bottom: _loading
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(3),
                  child: LinearProgressIndicator(
                    color: AppTheme.gold,
                    backgroundColor: Colors.transparent,
                    minHeight: 3,
                  ),
                )
              : null,
        ),
        body: InAppWebView(
          initialData: InAppWebViewInitialData(
            data: html,
            baseUrl: WebUri(PaystackService.baseUrl),
          ),
          initialSettings: InAppWebViewSettings(
            allowsInlineMediaPlayback: true,
            useShouldOverrideUrlLoading: true,
          ),
          onLoadStop: (_, __) {
            if (mounted) setState(() => _loading = false);
          },
          // Intercepts the local "redirect" URLs the checkout HTML
          // navigates to on success/close (see PaystackService), and
          // otherwise allows normal https navigation through — Paystack's
          // own checkout routes through bank/3DS authorisation pages on
          // other https domains as part of a normal card charge.
          shouldOverrideUrlLoading: (_, action) async {
            final uri = action.request.url;
            if (uri == null) return NavigationActionPolicy.ALLOW;
            final url = uri.toString();

            if (url.startsWith(PaystackService.successUrl)) {
              final ref = uri.queryParameters['reference'];
              _resolve((ref != null && ref.isNotEmpty) ? ref : widget.reference);
              return NavigationActionPolicy.CANCEL;
            }
            if (url.startsWith(PaystackService.closeUrl)) {
              _resolve(null);
              return NavigationActionPolicy.CANCEL;
            }
            return uri.scheme == 'https'
                ? NavigationActionPolicy.ALLOW
                : NavigationActionPolicy.CANCEL;
          },
        ),
      ),
    );
  }
}
