import 'package:flutter/material.dart';

Widget buildWebYoutubePlayer({
  required String videoId,
  required bool autoPlay,
  required bool mute,
  required bool loop,
  required bool isShort,
}) {
  return const ColoredBox(
    color: Colors.black,
    child: Center(
      child: Text('YouTube web player', style: TextStyle(color: Colors.white54)),
    ),
  );
}

void webYoutubeCommand(String videoId, String func, [List<Object>? args]) {}
