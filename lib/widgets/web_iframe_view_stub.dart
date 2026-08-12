import 'package:flutter/material.dart';

/// Non-web stub.
Widget buildWebIframe(String url, {String? title, String? htmlContent}) {
  return ColoredBox(
    color: const Color(0xFF121212),
    child: Center(
      child: Text(
        title ?? url,
        style: const TextStyle(color: Colors.white70),
      ),
    ),
  );
}
