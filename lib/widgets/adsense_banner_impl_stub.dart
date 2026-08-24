import 'package:flutter/material.dart';

Widget buildAdSenseUnit({
  required String clientId,
  required String slotId,
  required bool testMode,
  required double width,
  required double height,
}) {
  return const ColoredBox(
    color: Color(0x11000000),
    child: Center(
      child: Text('AdSense (web only)', style: TextStyle(fontSize: 11)),
    ),
  );
}
