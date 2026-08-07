import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../data/channel_data.dart';
import '../data/resource_category_data.dart';
import '../models/channel.dart';
import '../models/feed_tab.dart';
import '../models/resource_category.dart' show VerifiedBook;
import '../models/video.dart';
import '../services/blog_rss_service.dart';
import '../services/engagement_service.dart';
import '../services/rss_service.dart';
import '../services/user_profile_service.dart';

enum FeedState { idle, loading, loaded, error }

class FeedProvider extends ChangeNotifier {
  /// Last constructed instance — VideoPlayerScreen is pushed as a route
  /// outside MultiProvider (sibling of home under MaterialApp's navigator),
  /// so context.read<FeedProvider>() fails there. Same pattern as
  /// AdService.instance / EngagementService.instance.
  static FeedProvider? instance;

  FeedProvider() {
    instance = this;
    // Both the book list and the channel priority order (Videos/Shorts)
    // now react live to a category-selection change — see
    // _onProfileChanged and _sessionChannelOrder's doc comment for why
    // that changed from "next launch only".
    UserProfileService.instance.addListener(_onProfileChanged);
  }

  /// Suggested long-form videos for the player "See more" row.
  /// Prefers other channels that share [categoryId]; falls back to the
  /// general long-form feed. Never returns the current video or shorts/books.
  List<Video> suggestedFor({
    required String excludeVideoId,
    String? excludeChannelId,
    String? categoryId,
    int limit = 12,
  }) {
    final byId = ChannelData.byId;
    final pool = allFeedVideos.where((v) {
      if (v.id == excludeVideoId) return false;
      if (v.isShort || v.channelId == 'books' || v.channelId == 'verified_book') {
        return false;
      }
      if (categoryId == null) return true;
      return byId[v.channelId]?.resourceCategoryId == categoryId;
    }).toList();
    // Prefer other channels first, then newest.
    pool.sort((a, b) {
      final aOther =
          (excludeChannelId != null && a.channelId == excludeChannelId) ? 1 : 0;
      final bOther =
          (excludeChannelId != null && b.channelId == excludeChannelId) ? 1 : 0;
      if (aOther != bOther) return aOther.compareTo(bOther);
      return b.publishedAt.compareTo(a.publishedAt);
    });
    if (pool.length >= limit) return pool.take(limit).toList(growable: false);
    // Top up from general long-form if category pool is thin.
    if (categoryId != null) {
      final extra = allFeedVideos.where((v) {
        if (v.id == excludeVideoId) return false;
        if (v.isShort || v.channelId == 'books' || v.channelId == 'verified_book') {
          return false;
        }
        return !pool.any((p) => p.id == v.id);
      }).toList()
        ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
      pool.addAll(extra.take(limit - pool.length));
    }
    return pool.take(limit).toList(growable: false);
  }

  void _onProfileChanged() {
    // Re-priority the channel order for the NEW selection — see
    // _sessionChannelOrder's doc comment for why this can no longer stay
    // frozen from launch. This alone only changes ordering; the actual
    // re-fetch (so a newly-selected category's channels have videos to
    // rank in the first place) is the refresh() call below.
    _sessionChannelOrder = _buildSessionChannelOrder();
    _tabCache.remove(FeedTab.books);
    // BlogRssService.combinedBlogFeeds is selection-scoped (general +
    // whatever categories are currently selected — see that file), so a
    // changed selection must drop its 10-minute cache too, or the Blogs tab
    // could keep showing the previous selection's articles for up to that
    // long after switching category.
    BlogRssService.instance.clearCache();
    notifyListeners();
    // Pulls in the newly-selected category's channels right away instead
    // of making the person wait for next app open. Silent = no loading
    // spinner flash; _eagerChannels() picks up the new selection itself.
    unawaited(refresh(force: true, silent: true));
  }

  @override
  void dispose() {
    UserProfileService.instance.removeListener(_onProfileChanged);
    super.dispose();
  }

  FeedState _state = FeedState.idle;
  FeedState get state => _state;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Map<String, List<Video>> _videosByChannel = {};
  final Map<FeedTab, List<Video>> _tabCache = {};

  FeedTab _activeTab = FeedTab.videos;
  FeedTab get activeTab => _activeTab;

  /// All cached video lists across every tab — used for deep-link lookup.
  List<List<Video>> get allVideos => FeedTab.values
      .map((t) => _tabCache[t] ?? _compute(t))
      .toList();

  // ── Session channel order ─────────────────────────────────────────────────
  // Built at FeedProvider construction (= app launch), and again whenever
  // the person's category selection changes (see _onProfileChanged) — not
  // "next launch only" any more. The scenario that mattered most, by far,
  // is completing onboarding for the very first time: FeedProvider is
  // already constructed before onboarding is even shown (main.dart builds
  // it unconditionally during the splash sequence), so without recomputing
  // here, a first-time person's just-selected category would never get
  // boosted to the top for their entire first session — it would only
  // start appearing prominently on their NEXT app launch. Recomputing on
  // every selection change (not just reading it once at construction) is
  // what makes a freshly-selected category behave the same way general
  // content always has: visible immediately, not "starting next time."
  // Stable between selection changes so a plain pull-to-refresh doesn't
  // reorder the feed on its own.
  //   1. Explicit "My Business" selection (UserProfileService) — strongest signal, the person said so directly.
  //   2. Learned engagement (EngagementService) — channels this person actually watches/saves rank higher.
  //   3. Shuffle — anything with no signal yet gets a fair, random shot at the top so discovery still happens.
  List<String> _sessionChannelOrder = _buildSessionChannelOrder();

  // ── Eager-fetch scope ─────────────────────────────────────────────────
  // See ChannelData.eagerFor — general channels always fetched, category-
  // tagged channels only fetched if the user selected that category.
  static List<Channel> _eagerChannels() =>
      ChannelData.eagerFor(UserProfileService.instance.selectedCategoryIds);

  static List<String> _buildSessionChannelOrder() {
    // Deduplicate channel IDs before shuffling — without this, a channel that
    // appears 15× in _eagerChannels() would appear 15× here, and _roundRobin
    // would then emit 15 copies of the same blog/video per round-robin pass.
    final uniqueIds = LinkedHashSet<String>.from(
      _eagerChannels().map((c) => c.id).where((id) => id.isNotEmpty),
    );
    final shuffled = uniqueIds.toList()..shuffle();
    final ranked = EngagementService.instance.sortByEngagement(shuffled);
    final selected = UserProfileService.instance.selectedCategoryIds;
    if (selected.isEmpty) return ranked;
    final boosted = ChannelData.combined
        .where((c) => selected.contains(c.resourceCategoryId))
        .map((c) => c.id)
        .toList();
    if (boosted.isEmpty) return ranked;
    ranked.removeWhere(boosted.contains);
    return [...boosted, ...ranked];
  }

  var _savedVideoIds = <String>{};

  List<Channel> get channels => ChannelData.combined;
  List<Video> getVideosFor(String channelId) => _videosByChannel[channelId] ?? [];

  /// All currently-loaded videos and shorts (excluding books) — used by
  /// ContentSearchScreen for in-app full-text search. Returns a flat list;
  /// the search screen filters by type (isShort, channelId, etc.) itself.
  List<Video> get allFeedVideos =>
      _videosByChannel.values.expand((v) => v).toList();

  /// All books currently in the Books tab — used by ContentSearchScreen.
  List<Video> get allBooksForSearch => _allBookVideos;

  // ── Per-tab cached list ───────────────────────────────────────────────────────

  List<Video> get feedVideos => _tabCache[_activeTab] ??= _compute(_activeTab);

  List<Video> _compute(FeedTab tab) {
    final raw = _videosByChannel.values.expand((v) => v).toList();

    // Deduplicate by YouTube video ID before any tab filtering.
    // Two different channel IDs can return the same video ID when a creator
    // cross-posts a Short to a second channel or a clip channel re-uploads
    // original content. Without this the same short appears once per channel
    // bucket it was stored in, causing the "same short three times" symptom.
    final seen = <String>{};
    final all  = [for (final v in raw) if (seen.add(v.id)) v];

    return switch (tab) {
      // Videos and Shorts: date-mixed (newest first globally, category
      // channels softly boosted, no more than 2 consecutive same-channel).
      // Replaces the old round-robin which interleaved by channel-slot rather
      // than by actual upload date, causing older content from some channels
      // to appear above newer content from others.
      FeedTab.videos =>
        _smartMix(all.where((v) => !v.isShort && !_isBook(v)).toList()),
      FeedTab.shorts =>
        _smartMix(all.where((v) => v.isShort  && !_isBook(v)).toList()),
      FeedTab.blogs  =>
        _roundRobin(all.where((v) => _isBlog(v) && !_isBook(v)).toList()),
      FeedTab.books  => List.unmodifiable(_allBookVideos),
    };
  }

  /// Feed ordering with explicit 3-to-1 category-vs-general ratio and strict
  /// no-consecutive-same-source guarantee.
  ///
  /// Algorithm (in order):
  /// 1. Split into two pools: category-tagged channels (user's selection) and
  ///    general channels.  Each pool is sorted newest-first independently so
  ///    the freshest content from each tier always surfaces first.
  /// 2. Weighted interleave at 3:1 — three category items, then one general,
  ///    then three category, etc.  When a pool is exhausted the other fills
  ///    the remainder.  If no category is selected (or category pool is empty)
  ///    the full list is just sorted by date.
  /// 3. Diversity pass — walk the merged list and, whenever two adjacent items
  ///    share the same channelId, find the nearest upcoming item from a
  ///    different channel and rotate it forward.  O(n) average for realistic
  ///    feeds; gracefully degrades to leaving ties as-is when no alternative
  ///    exists (e.g. a user subscribed to one channel only).
  List<Video> _smartMix(List<Video> videos) {
    if (videos.isEmpty) return const [];

    final selected  = UserProfileService.instance.selectedCategoryIds;
    final channelById = ChannelData.byId; // cache — byId builds a new Map each call

    bool isCategoryChannel(String channelId) {
      final ch = channelById[channelId];
      return ch?.resourceCategoryId != null &&
          selected.contains(ch!.resourceCategoryId);
    }

    // ── 1. Split + sort each pool newest first ──────────────────────────────
    final catPool = <Video>[];
    final genPool = <Video>[];
    for (final v in videos) {
      (isCategoryChannel(v.channelId) ? catPool : genPool).add(v);
    }
    catPool.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    genPool.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

    // Fallback: no selection or no category content → plain date sort
    if (selected.isEmpty || catPool.isEmpty) {
      final all = [...genPool, ...catPool]
        ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
      return List.unmodifiable(_diversify(all));
    }

    // ── 2. 3:1 weighted interleave ──────────────────────────────────────────
    // 3 from the category pool, then 1 from the general pool, repeat.
    // Each pool is consumed in newest-first order so recency is preserved
    // within each tier.
    final merged = <Video>[];
    var ci = 0;
    var gi = 0;
    while (ci < catPool.length || gi < genPool.length) {
      for (var slot = 0; slot < 3 && ci < catPool.length; slot++) {
        merged.add(catPool[ci++]);
      }
      if (gi < genPool.length) merged.add(genPool[gi++]);
    }

    // ── 3. Diversity pass — no two adjacent items from the same channel ─────
    return List.unmodifiable(_diversify(merged));
  }

  /// Rearranges [items] so no two adjacent elements share the same [channelId],
  /// disturbing the order as little as possible.
  ///
  /// For each consecutive-same-source pair at index i, we scan ahead for the
  /// nearest item with a different source and rotate it into position i.  This
  /// is O(n) on diverse feeds (where a different source is usually 1–2 steps
  /// ahead) and O(n²) only in degenerate inputs (single-channel feed).
  List<Video> _diversify(List<Video> items) {
    if (items.length <= 1) return items;
    final out = List<Video>.from(items);
    final n   = out.length;
    for (var i = 1; i < n; i++) {
      if (out[i].channelId != out[i - 1].channelId) continue;
      // Find the nearest upcoming item with a different channelId
      var j = i + 1;
      while (j < n && out[j].channelId == out[i - 1].channelId) {
        j++;
      }
      if (j < n) {
        // Rotate out[j] into position i, shifting i..j-1 right by 1
        final swap = out.removeAt(j);
        out.insert(i, swap);
      }
      // If j == n: the entire tail is the same channel — leave as-is
    }
    return out;
  }

  /// The original 10 hand-picked classics/playbooks, plus real named books
  /// pulled from assets/data/resources/{categoryId}.json — general ones
  /// (categoryId == null) always, and category-specific ones ONLY for
  /// categories the person actually selected (UserProfileService).
  ///
  /// This intentionally does NOT fall back to "show every category's books
  /// when nothing's selected" the way the old CategoryPlaybookData version
  /// did — a fashion designer must never see a doctor's books (or any other
  /// unselected category's) just because they haven't picked one yet.
  /// Skipping onboarding simply means "general books only" until they do.
  ///
  /// Selected-category books come first (the same "your stuff first"
  /// priority every other tab already gives a selected category), then the
  /// general library. No CategoryPlaybookData here any more — that generated
  /// "Business of X" content still exists (see CategoryDetailScreen's own
  /// "Read the Business Playbook" card, clearly labelled as FinReels
  /// Research) but it stopped being presented as a Book here, since it was
  /// close to identical filler for every Skill category and isn't a
  /// substitute for a real, named book.
  List<Video> get _allBookVideos {
    final selected = UserProfileService.instance.selectedCategoryIds;
    final verified = ResourceCategoryData.verifiedBooks.where(
      (b) => b.categoryId == null || selected.contains(b.categoryId),
    );
    final mine = <VerifiedBook>[];
    final general = <VerifiedBook>[];
    for (final b in verified) {
      (b.categoryId == null ? general : mine).add(b);
    }
    return [
      ...mine.map(_videoFromVerifiedBook),
      ..._bookVideos,
      ...general.map(_videoFromVerifiedBook),
    ];
  }

  static Video _videoFromVerifiedBook(VerifiedBook b) {
    final slug = '${b.categoryId ?? 'general'}_${b.title}'
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), '_');
    final id = 'vbook_$slug';
    return Video(
      id: id,
      title: b.title,
      description: b.freeSourceNote != null
          ? '${b.author} · ${b.freeSourceNote}'
          : b.author,
      channelId: 'verified_book',
      channelName: b.author,
      publishedAt: _epoch,
      // coverUrl from the JSON — Open Library ISBN URL, publisher CDN, etc.
      // Empty string when not set; BookCoverImage handles that gracefully.
      thumbnailUrl: b.coverUrl ?? '',
      freeSourceUrl: b.freeSourceUrl,
      freeSourceType: b.freeSourceType,
      sourceCategoryId: b.categoryId,
    );
  }

  List<Video> _roundRobin(List<Video> videos) {
    if (videos.isEmpty) return const [];
    final grouped = <String, List<Video>>{};
    for (final v in videos) { (grouped[v.channelId] ??= []).add(v); }
    for (final l in grouped.values) { l.sort((a, b) => b.publishedAt.compareTo(a.publishedAt)); }
    // Use the session channel order (shuffled once at launch, stable during session).
    // Filter to only channels that have content of this type, preserving session order.
    // Deduplicate keys — _sessionChannelOrder is already deduped at build time,
    // but this guard ensures correctness even if a stale cached order has dupes.
    final keysSeen = <String>{};
    final keys = <String>[
      for (final id in _sessionChannelOrder)
        if (grouped.containsKey(id) && keysSeen.add(id)) id,
      for (final id in grouped.keys)
        if (!_sessionChannelOrder.contains(id) && keysSeen.add(id)) id,
    ];
    final maxLen = grouped.values.map((l) => l.length).fold(0, (a, b) => a > b ? a : b);
    final result = <Video>[];
    for (var i = 0; i < maxLen; i++) {
      for (final k in keys) {
        final l = grouped[k]!;
        if (i < l.length) result.add(l[i]);
      }
    }
    // Apply diversity pass so no two consecutive blog articles are from the
    // same channel (e.g. Seth Godin posting 5 times shouldn't monopolise
    // consecutive slots in the Blogs search results).
    return List.unmodifiable(_diversify(result));
  }

  // ── Content detection ─────────────────────────────────────────────────────────

  bool _isBlog(Video v) {
    if (v.isShort || _isBook(v)) return false;
    final t = v.title.toLowerCase();
    return t.startsWith('how to') || t.startsWith('why ') || t.startsWith('what ') ||
        RegExp(r'^\d+ (ways|tips|things|rules|reasons|lessons|steps|mistakes)').hasMatch(t) ||
        t.contains(' tips') || t.contains(' guide') || t.contains(' rules') ||
        t.contains(' lessons') || t.contains(' mistakes');
  }

  bool _isBook(Video v) => v.channelId == 'books' || v.channelId == 'verified_book';

  // ── Books ─────────────────────────────────────────────────────────────────────

  static final _epoch = DateTime(2000);

  // static final → created exactly once, not on every access.
  static final List<Video> _bookVideos = [
    // ── Public domain classics — read in full via EPUB, free, no login ──────
    Video(id:'book_richest_man',
      title:'The Richest Man in Babylon — George S. Clason',
      description:'Timeless laws of money: pay yourself first, make money work for you.',
      channelId:'books',channelName:'Free Finance Library',publishedAt:_epoch,
      thumbnailUrl:'https://covers.openlibrary.org/b/isbn/9780451205360-L.jpg'),
    Video(id:'book_think_grow',
      title:'Think and Grow Rich — Napoleon Hill',
      description:"13 principles of wealth distilled from 500+ of history's most successful people.",
      channelId:'books',channelName:'Free Finance Library',publishedAt:_epoch,
      thumbnailUrl:'https://covers.openlibrary.org/b/isbn/9781585424337-L.jpg'),
    Video(id:'book_science_rich',
      title:'The Science of Getting Rich — Wallace D. Wattles',
      description:'The original 1910 law-of-attraction wealth blueprint that inspired The Secret.',
      channelId:'books',channelName:'Free Finance Library',publishedAt:_epoch,
      thumbnailUrl:'https://archive.org/services/img/science_gettingrich_1005_librivox'),
    Video(id:'book_art_money',
      title:'The Art of Money Getting — P. T. Barnum',
      description:"20 golden rules for making money from America's greatest showman (1880).",
      channelId:'books',channelName:'Free Finance Library',publishedAt:_epoch,
      thumbnailUrl:'https://www.globalgreyebooks.com/content/book-covers/p-t-barnum_art-of-money-getting.jpg'),
    Video(id:'book_as_man_thinketh',
      title:'As a Man Thinketh — James Allen',
      description:'How your thoughts shape your wealth, health, and circumstances (1903).',
      channelId:'books',channelName:'Free Finance Library',publishedAt:_epoch,
      thumbnailUrl:'https://covers.openlibrary.org/b/id/14828006-L.jpg'),
    Video(id:'book_eight_pillars',
      title:'Eight Pillars of Prosperity — James Allen',
      description:'Energy, economy, integrity, and five more virtues that build lasting wealth (1911).',
      channelId:'books',channelName:'Free Finance Library',publishedAt:_epoch,
      thumbnailUrl:'https://archive.org/services/img/eightpillarsofprosperity_1411_librivox'),
    Video(id:'book_master_key',
      title:'The Master Key System — Charles F. Haanel',
      description:'A 24-week course on mastering the mind to attract wealth and success (1912).',
      channelId:'books',channelName:'Free Finance Library',publishedAt:_epoch,
      thumbnailUrl:'https://covers.openlibrary.org/b/olid/OL25601790M-L.jpg'),
    Video(id:'book_popular_delusions',
      title:'Extraordinary Popular Delusions — Charles Mackay',
      description:'The tulip mania, South Sea bubble and how crowds go financially mad (1841).',
      channelId:'books',channelName:'Free Finance Library',publishedAt:_epoch,
      thumbnailUrl:'https://covers.openlibrary.org/b/id/8100251-L.jpg'),

    // ── Bundled masterclass playbooks — ship inside the app, fully offline ──
    Video(id:'book_five_buckets_playbook',
      title:'The Five Buckets: Build What They Can Never Take From You',
      description:'An encyclopedic masterclass on Knowledge, Skills, Network, Resources & Reputation — inspired by Steven Bartlett\'s 5-Bucket framework.',
      channelId:'books',channelName:'Masterclass Playbooks',publishedAt:_epoch,
      thumbnailUrl:'assets/books/five_buckets_playbook_cover.jpg'),
    Video(id:'book_five_buckets_complete',
      title:'The Five Buckets: A Field Manual for Unstoppable Success',
      description:'How to build unshakeable knowledge, master high-value skills, engineer powerful networks, command strategic resources, and forge a reputation that opens doors before you knock.',
      channelId:'books',channelName:'Masterclass Playbooks',publishedAt:_epoch,
      thumbnailUrl:'assets/books/five_buckets_complete_cover.jpg'),
  ];

  // ── Init ──────────────────────────────────────────────────────────────────────

  Future<void> init() async {
    await _loadSaved();

    // 1. Load disk cache → instant first render (whatever we last had).
    await _loadDiskCache();
    final hasCached = _videosByChannel.isNotEmpty;

    // 2. ALWAYS force a true network refresh on app open. YouTube's RSS
    // feed always returns exactly the latest 15 videos per channel — this
    // forced refresh is what guarantees that "latest 15" window is
    // genuinely up to date every time the user opens the app, rather than
    // potentially serving a stale cached 15 from up to 30 minutes ago.
    // silent: true when we already have something on screen, so this
    // happens quietly in the background with no spinner flash.
    await refresh(force: true, silent: hasCached);
  }

  Future<void> _loadDiskCache() async {
    final snap = <String, List<Video>>{};
    for (final ch in ChannelData.combined) {
      final cached = await RssService.instance.getCached(ch.id);
      if (cached.isNotEmpty) snap[ch.id] = cached;
    }
    if (snap.isNotEmpty) {
      _videosByChannel = Map.unmodifiable(snap);
      _tabCache.clear();
      _state = FeedState.loaded;
      notifyListeners();
    }
  }

  // ── Tab ───────────────────────────────────────────────────────────────────────

  void setTab(FeedTab tab) {
    if (_activeTab == tab) return;
    _activeTab = tab;
    notifyListeners();
  }

  // ── Refresh ───────────────────────────────────────────────────────────────────

  DateTime? _lastForcedRefreshAt;

  /// [silent] = true → skip loading spinner, update quietly in background.
  /// Used on app resume and on init when cache is already visible.
  Future<void> refresh({bool force = false, bool silent = false}) async {
    if (!silent) {
      _state = FeedState.loading;
      _errorMessage = null;
      notifyListeners();
    }

    // Deduplicate channels by ID before fetching — a channel listed in both
    // _general.json (null categoryId) and a selected category's JSON can appear
    // multiple times in _eagerChannels(). Prefer the category-specific version
    // so _dateMixed's 3-day boost fires correctly, and skip empty IDs entirely.
    final seenChannelIds = <String>{};
    final channels = <Channel>[];
    for (final ch in _eagerChannels()) {
      if (ch.id.isEmpty) continue;
      if (seenChannelIds.add(ch.id)) {
        channels.add(ch);
      } else if (ch.resourceCategoryId != null) {
        // Upgrade null-category entry to category-specific so boost fires.
        final idx = channels.indexWhere((c) => c.id == ch.id);
        if (idx >= 0 && channels[idx].resourceCategoryId == null) {
          channels[idx] = ch;
        }
      }
    }

    final snap = <String, List<Video>>{};

    // Staggered parallel: channel[i] waits i×50 ms before its first request.
    // All run concurrently inside Future.wait — total time ≈ slowest fetch.
    // 50 ms stagger is enough separation to avoid hammering YouTube;
    // 200 ms (the old value) added 2.2 s of unnecessary overhead for 12 channels.
    await Future.wait(
      List.generate(channels.length, (i) async {
        final ch = channels[i];
        snap[ch.id] = await RssService.instance.fetchVideos(
          ch.id,
          forceRefresh: force,
          staggerMs:    i * 50,
        );
      }),
    );

    final total = snap.values.fold(0, (s, l) => s + l.length);

    // snap COMPLETELY REPLACES _videosByChannel (not merged/appended) — this
    // is what ensures each channel's video list is always exactly its
    // current latest 15 from YouTube's RSS feed, never a stale mix of old
    // and new entries.
    _videosByChannel = Map.unmodifiable(snap);
    _tabCache.clear();
    _state = total > 0 ? FeedState.loaded : FeedState.error;
    _errorMessage = total == 0 ? 'Could not load content. Check your connection.' : null;

    if (force) _lastForcedRefreshAt = DateTime.now();

    notifyListeners();
  }

  /// Called when the app resumes from the background. Forces a true
  /// network refresh — but only if it's been a while since the last one,
  /// so rapid app-switching (checking a notification and coming straight
  /// back, for example) doesn't hammer YouTube's RSS endpoint with repeat
  /// requests every few seconds.
  Future<void> refreshOnResume() async {
    final last = _lastForcedRefreshAt;
    final dueForRefresh = last == null ||
        DateTime.now().difference(last) > const Duration(minutes: 3);
    if (!dueForRefresh) return;
    await refresh(force: true, silent: true);
  }

  // ── Saved ─────────────────────────────────────────────────────────────────────

  bool isVideoSaved(String id) => _savedVideoIds.contains(id);

  Future<void> toggleSaved(Video video) async {
    final wasSaved = _savedVideoIds.contains(video.id);
    wasSaved ? _savedVideoIds.remove(video.id) : _savedVideoIds.add(video.id);
    if (!wasSaved) {
      // Saving (not un-saving) is a stronger signal than just opening.
      unawaited(EngagementService.instance.recordSave(video));
    }
    await _persistSaved();
    notifyListeners();
  }

  List<Video> get savedVideos => _videosByChannel.values
      .expand((v) => v)
      .where((v) => _savedVideoIds.contains(v.id))
      .toList()
    ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    _savedVideoIds = (prefs.getStringList(AppConfig.prefSavedVideos) ?? []).toSet();
  }

  Future<void> _persistSaved() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(AppConfig.prefSavedVideos, _savedVideoIds.toList());
  }
}
