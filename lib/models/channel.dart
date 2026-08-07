import 'package:flutter/material.dart';

class Channel {
  final String id;
  final String name;
  final String handle;
  final String description;
  final Color accentColor;
  final String category;
  final String focus;
  final String initials;

  /// Links this channel to one of the 60 "Business of Your Skill/Business/
  /// Profession" categories (see models/resource_category.dart), e.g.
  /// 'skill_01_tailoring_fashion_design'. Null for channels that haven't
  /// been mapped to a category yet — every existing channel stays null
  /// and behaves exactly as before. Used by FeedProvider to give a
  /// person's selected category's channels priority in the feed.
  final String? resourceCategoryId;

  const Channel({
    required this.id,
    required this.name,
    required this.handle,
    required this.description,
    required this.accentColor,
    required this.category,
    required this.focus,
    required this.initials,
    this.resourceCategoryId,
  });

  String get rssUrl =>
      'https://www.youtube.com/feeds/videos.xml?channel_id=$id';

  String get channelUrl => 'https://www.youtube.com/channel/$id';

  String get youtubeHandle => 'https://www.youtube.com/$handle';
}
