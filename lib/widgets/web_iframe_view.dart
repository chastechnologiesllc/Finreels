import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'web_iframe_view_stub.dart'
    if (dart.library.html) 'web_iframe_view_web.dart' as impl;

/// Embeds a URL in an iframe on Flutter web (in-platform, no redirect).
/// On mobile/desktop this widget should not be used; prefer InAppWebView.
///
/// When [htmlContent] is provided the HTML is served via a blob: URL so
/// X-Frame-Options on the original publisher's server is bypassed entirely.
class WebIframeView extends StatelessWidget {
  final String url;
  final String? title;

  /// Pre-fetched HTML to render.  When set, a blob: URL is created from this
  /// content so the iframe is same-origin and framing restrictions don't apply.
  /// When null, [url] is loaded directly (books on frame-permitting sources).
  final String? htmlContent;

  const WebIframeView({
    required this.url,
    this.title,
    this.htmlContent,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();
    return impl.buildWebIframe(url, title: title, htmlContent: htmlContent);
  }
}
