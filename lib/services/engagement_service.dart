import 'dart:convert';
import 'dart:math' show pow;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/video.dart';
import 'user_profile_service.dart';

/// Learns what *this* person actually watches, saves, and reads, and uses
/// it to quietly re-rank their own feed — more of what they engage with,
/// less of what they scroll past.
///
/// Scope, stated honestly: this is on-device implicit-feedback ranking
/// (weighted counts of view/save/open events, decaying over time), not a
/// trained model — FinReels has no backend to collect cross-user data or
/// train one. It's the same *family* of signal Facebook/YouTube use
/// (what you engage with predicts what you'll want more of), just running
/// entirely on this phone, for this one person, with simple weighted
/// counts instead of a neural network. Good enough to make the feed feel
/// like it's paying attention; not a claim to be YouTube's recommender.
///
/// Scores decay on load (see [_decayIfDue]) so a burst of interest in one
/// channel two months ago doesn't permanently dominate the feed — recent
/// behavior matters more than old behavior, same as any sane ranking
/// signal should work.
class EngagementService extends ChangeNotifier {
  EngagementService._();
  static final EngagementService instance = EngagementService._();

  Map<String, double> _channelScores = {};
  Map<String, double> _categoryScores = {};
  bool _loaded = false;

  static const _viewWeight = 1.0;
  static const _saveWeight = 3.0;
  static const _categoryContentWeight = 1.0; // playbook/blog open tied to a category
  static const _halfLifeDays = 21; // score halves roughly every 3 weeks

  bool get isLoaded => _loaded;

  Future<void> init() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _channelScores = _decode(prefs.getString(AppConfig.prefChannelEngagement));
    _categoryScores = _decode(prefs.getString(AppConfig.prefCategoryEngagement));
    await _decayIfDue(prefs);
    _loaded = true;
    notifyListeners();
  }

  Map<String, double> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, (v as num).toDouble()));
    } on Object {
      return {};
    }
  }

  Future<void> _decayIfDue(SharedPreferences prefs) async {
    final lastMs = prefs.getInt(AppConfig.prefEngagementDecayAt);
    final now = DateTime.now();
    if (lastMs != null) {
      final days = now.difference(DateTime.fromMillisecondsSinceEpoch(lastMs)).inDays;
      if (days > 0) {
        final factor = _decayFactor(days);
        _channelScores = _channelScores.map((k, v) => MapEntry(k, v * factor));
        _categoryScores = _categoryScores.map((k, v) => MapEntry(k, v * factor));
      }
    }
    await prefs.setInt(AppConfig.prefEngagementDecayAt, now.millisecondsSinceEpoch);
  }

  double _decayFactor(int days) => pow(0.5, days / _halfLifeDays).toDouble();

  /// Video opened/played — the lightest-weight positive signal.
  Future<void> recordView(Video video) async {
    _bump(_channelScores, video.channelId, _viewWeight);
    await _persistChannels();
    notifyListeners();
  }

  /// Video explicitly saved — a stronger signal than just opening.
  Future<void> recordSave(Video video) async {
    _bump(_channelScores, video.channelId, _saveWeight);
    await _persistChannels();
    notifyListeners();
  }

  /// A category's playbook or a category-tagged blog article was opened.
  Future<void> recordCategoryInterest(String categoryId) async {
    _bump(_categoryScores, categoryId, _categoryContentWeight);
    await _persistCategories();
    notifyListeners();
  }

  void _bump(Map<String, double> map, String key, double weight) {
    map[key] = (map[key] ?? 0) + weight;
  }

  Future<void> _persistChannels() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConfig.prefChannelEngagement, jsonEncode(_channelScores));
  }

  Future<void> _persistCategories() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConfig.prefCategoryEngagement, jsonEncode(_categoryScores));
  }

  double channelScore(String channelId) => _channelScores[channelId] ?? 0;
  double categoryScore(String categoryId) => _categoryScores[categoryId] ?? 0;

  /// Categories ranked by implicit interest — engagement score, and for
  /// anything the person explicitly selected as "My Business" (which
  /// carries real signal even before they've watched anything there yet).
  List<String> rankedCategoryIds() {
    final selected = UserProfileService.instance.selectedCategoryIds;
    final ids = {...selected, ..._categoryScores.keys}.toList();
    ids.sort((a, b) {
      final aScore = categoryScore(a) + (selected.contains(a) ? 1000 : 0);
      final bScore = categoryScore(b) + (selected.contains(b) ? 1000 : 0);
      return bScore.compareTo(aScore);
    });
    return ids;
  }

  /// Sorts [channelIds] by learned engagement, highest first, WITHOUT
  /// reshuffling ties — callers pre-shuffle for freshness among unknowns,
  /// this only reorders where there's an actual signal to act on.
  List<String> sortByEngagement(List<String> channelIds) {
    if (_channelScores.isEmpty) return channelIds;
    final withScore = channelIds.where((id) => channelScore(id) > 0).toList()
      ..sort((a, b) => channelScore(b).compareTo(channelScore(a)));
    final withoutScore = channelIds.where((id) => channelScore(id) <= 0).toList();
    return [...withScore, ...withoutScore];
  }
}
