import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'web_iframe_view_stub.dart'
    if (dart.library.html) 'web_iframe_view_web.dart' as impl;

/// Embeds a URL in an iframe on Flutter web (in-platform, no redirect).
/// On mobile/desktop this widget should not be used; prefer InAppWebView.
class WebIframeView extends StatelessWidget {
  final String url;
  final String? title;

  const WebIframeView({
    required this.url,
    this.title,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return const SizedBox.shrink();
    }
    return impl.buildWebIframe(url, title: title);
  }
}
