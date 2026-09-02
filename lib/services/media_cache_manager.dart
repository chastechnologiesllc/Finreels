import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// One disk cache shared by every image surface in the app.
///
/// A stable cache key and bounded object count let a thumbnail loaded on one
/// screen be reused on another screen and after a widget is recycled by a
/// scrolling list. The cache is persistent on native platforms and uses the
/// browser cache on Web through the same CachedNetworkImage contract.
class RumuoMediaCache {
  RumuoMediaCache._();

  static final CacheManager instance = CacheManager(
    Config(
      'rumuo-media-v1',
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 1800,
    ),
  );

  static const maxRememberedSelections = 2400;
  static final Map<String, int> _successfulSelection = <String, int>{};

  static int? selectedIndex(String key) => _successfulSelection[key];

  static void rememberSelection(String key, int index) {
    if (_successfulSelection.length >= maxRememberedSelections &&
        !_successfulSelection.containsKey(key)) {
      _successfulSelection.remove(_successfulSelection.keys.first);
    }
    _successfulSelection[key] = index;
  }
}
