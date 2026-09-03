import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'data/resource_category_data.dart';
import 'providers/feed_provider.dart';
import 'screens/main_shell.dart';
import 'screens/my_business_screen.dart';
import 'services/ad_block_service.dart';
import 'services/ad_service.dart';
import 'services/background_service.dart';
import 'services/connectivity_service.dart';
import 'services/engagement_service.dart';
import 'services/iap_service.dart';
import 'services/notification_service.dart';
import 'services/notification_store.dart';
import 'services/user_profile_service.dart';
import 'services/web_boot.dart';
import 'theme/app_theme.dart';
import 'widgets/ad_block_overlay.dart';
import 'widgets/connectivity_overlay.dart';

/// Startup stays minimal so runApp() fires on the first frame.
/// Heavy init (Hive, SDKs, providers) runs after the native initiation screen
/// has been displayed and in parallel with the first Flutter frame.
void main() {
  // runZonedGuarded + the two handlers below are the last line of defence
  // against a genuinely uncaught exception taking the whole app process
  // down with zero visibility into why. Framework-level errors (thrown
  // during build/layout/paint) go through FlutterError.onError; anything
  // else — a stray exception in an async callback, a Timer, a stream
  // listener outside a try/catch — is caught by the zone or by
  // PlatformDispatcher.onError. Every individual service already guards
  // itself defensively (see _safeInit below), so this is specifically the
  // net for whatever that couldn't anticipate.
  //
  // This does NOT send crash reports anywhere by itself — it only
  // prevents a hard crash and logs via debugPrint. Wire in Crashlytics,
  // Sentry, or similar here (both callbacks below) if/when you want
  // production crash analytics.
  runZonedGuarded(() async {
    // Must be the very first line — no await before this.
    WidgetsFlutterBinding.ensureInitialized();

    // Flutter Web keeps the semantics DOM opt-in for performance. Rumuo is
    // a public content app, so make screen-reader support available by default.
    if (kIsWeb) {
      SemanticsBinding.instance.ensureSemantics();
    }

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('[crash] Flutter error: ${details.exceptionAsString()}');
    };
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      debugPrint('[crash] Uncaught platform error: $error\n$stack');
      return true; // handled — do not let it crash the process
    };

    // Keep the main experience orientation-adaptive. Individual player routes
    // still request landscape or portrait when their media controls require it.
    if (!kIsWeb) {
      // Edge-to-edge: the app draws fully behind the status bar and
      // navigation bar/gesture area, with MediaQuery padding correctly
      // reporting those insets so SafeArea/Scaffold still lay content out
      // correctly. Combined with the transparent statusBarColor set below,
      // this is what lets the Scaffold's own background colour paint all
      // the way to the physical top of the screen instead of leaving a
      // visibly different strip behind the time/signal/battery icons.
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }

    // runApp immediately — the native initiation frame remains above Flutter.
    runApp(const RumuoApp());
  }, (Object error, StackTrace stack) {
    debugPrint('[crash] Uncaught zone error: $error\n$stack');
  });
}

class RumuoApp extends StatelessWidget {
  const RumuoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rumuo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: const _StartupGate(),
      // Wraps EVERY screen in the navigation stack — including ones with no
      // AppBar at all, like MainShell — so the status bar is always
      // transparent with correctly-contrasted icons, regardless of which
      // screen is currently showing. Screens WITH an AppBar additionally
      // get the same treatment from AppBarTheme.systemOverlayStyle; this
      // wrapper is what makes screens WITHOUT one consistent too.
      builder: (context, child) {
        final brightness = MediaQuery.platformBrightnessOf(context);
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: AppTheme.overlayStyleFor(brightness),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

/// Startup gate for initialization. Native platforms show their initiation
/// screen before Flutter; web continues to use its unchanged static boot layer.
class _StartupGate extends StatefulWidget {
  const _StartupGate();

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  bool _initDone = false;
  bool _webBootReadySent = false;
  bool _nativeLaunchReadySent = false;

  // Holds fully-initialised providers, set after init completes.
  FeedProvider? _feedProvider;

  @override
  void initState() {
    super.initState();
    // Fire-and-forget — native initiation remains visible while startup runs.
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    // Open Hive box for EPUB reading-progress persistence. Kept blocking —
    // it's a local-disk operation and typically resolves in single-digit ms.
    // Wrapped defensively: if Hive somehow fails (corrupted box, disk issue),
    // reading progress just won't persist — that must never be allowed to
    // strand the user on the native initiation screen forever.
    try {
      await Hive.initFlutter();
      await Hive.openBox<String>('reading_progress');
    } on Object catch (e) {
      debugPrint('[startup] Hive init failed (non-fatal): $e');
    }

    // ── Group A: lightweight first-screen prerequisites ─────────────────────
    // The category index, profile selection, and engagement preferences are
    // enough to render onboarding and construct the first feed provider. The
    // much larger verified-resource catalog hydrates in the background below
    // and triggers a quiet second refresh when it is ready.
    try {
      await Future.wait([
        _safeInit('ResourceCategories', ResourceCategoryData.loadCategories),
        _safeInit('UserProfile',        UserProfileService.instance.init),
        _safeInit('Engagement',         EngagementService.instance.init),
      ]).timeout(const Duration(seconds: 4));
    } on TimeoutException {
      debugPrint('[startup] lightweight startup prerequisites exceeded 4s; '
          'proceeding so the first screen can still open.');
    }

    // ── Group B: everything else — must never block FeedProvider ────────────
    // Ads/IAP/Notifications/Connectivity can be genuinely slow (external
    // SDKs, a flaky network call during setup) without that ever being a
    // reason FeedProvider should wait — so this group is fully
    // fire-and-forget with its own separate ceiling, run concurrently with
    // Group A above rather than after it (both start as soon as Hive is
    // ready), and never gates FeedProvider's construction or the
    // initiation-to-shell transition.
    unawaited(() async {
      try {
        await Future.wait([
          _safeInit('Connectivity',       ConnectivityService.instance.init),
          _safeInit('Background',         _initBackgroundServices),
          _safeInit('Notifications',      NotificationService.instance.init),
          // Load persisted notification inbox + unread count so the bell
          // badge is correct from the very first frame of the shell.
          _safeInit('NotificationStore',  NotificationStore.instance.init),
          _safeInit('Ads',                AdService.instance.init),
          _safeInit('IAP',                IapService.instance.init),
        ]).timeout(const Duration(seconds: 6));
      } on TimeoutException {
        debugPrint('[startup] Connectivity/Background/Notifications/Ads/IAP '
            'exceeded 6s — continuing without waiting further.');
      }
    }());
    unawaited(AdBlockService.instance.init());

    // Build the feed provider here so it can start fetching immediately.
    // Group A above is guaranteed to have either finished or hit its own
    // explicit timeout by this point — Group B is never a factor either way.
    final provider = FeedProvider();
    final providerInit = _safeInit('FeedProvider', provider.init);
    unawaited(providerInit);

    // Verified channels/blogs/books are intentionally not on the critical
    // path. Once the full local catalog finishes, wait for the initial feed
    // request and quietly refresh using the now-complete category scope.
    unawaited(() async {
      await _safeInit(
        'VerifiedResources',
        ResourceCategoryData.loadVerifiedResources,
      );
      await providerInit;
      if (mounted) {
        unawaited(provider.refresh(force: true, silent: true));
      }
    }());

    if (!mounted) return;
    setState(() {
      _feedProvider = provider;
      _initDone = true;
    });
    _maybeTransition();
  }

  /// BackgroundService.registerRssCheck() depends on init() having already
  /// run, so this pair must stay sequential relative to each other — but
  /// the pair as a whole runs in parallel with everything else above.
  Future<void> _initBackgroundServices() async {
    await BackgroundService.instance.init();
    await BackgroundService.instance.registerRssCheck();
  }

  /// Runs [fn] and swallows any error. A single misbehaving service (no
  /// Play Services, a flaky network call during setup, a misconfigured SDK
  /// key, etc.) must never be able to hang the native initiation screen forever or
  /// crash app startup — it should just be skipped, logged, and the app
  /// should continue without that feature until it can recover later.
  Future<void> _safeInit(String name, Future<void> Function() fn) async {
    try {
      await fn();
    } on Object catch (e, st) {
      debugPrint('[startup] $name init failed (non-fatal): $e\n$st');
    }
  }

  /// Transitions to the shell when initialization has produced a provider.
  void _maybeTransition() {
    if (_initDone && _feedProvider != null && mounted) {
      final signalWebBoot = kIsWeb && !_webBootReadySent;
      final signalNativeLaunch = !kIsWeb && !_nativeLaunchReadySent;
      if (signalWebBoot) _webBootReadySent = true;
      if (signalNativeLaunch) _nativeLaunchReadySent = true;
      setState(() {}); // Triggers the build that shows the shell.
      if (signalWebBoot) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) markWebBootReady();
        });
      }
      if (signalNativeLaunch) unawaited(_signalNativeLaunchReady());
    }
  }

  Future<void> _signalNativeLaunchReady() async {
    try {
      await const MethodChannel(
        'com.chastechgroup.rumuo/native_launch',
      ).invokeMethod<void>('ready');
    } on Object catch (e) {
      debugPrint('[startup] native launch handoff failed (non-fatal): $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Native initiation owns the pre-Flutter branded frame; Flutter shows the
    // shell as soon as initialization has produced its provider.
    if (_initDone && _feedProvider != null) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: _feedProvider!),
          ChangeNotifierProvider.value(value: IapService.instance),
          ChangeNotifierProvider.value(value: AdService.instance),
          ChangeNotifierProvider.value(value: UserProfileService.instance),
          ChangeNotifierProvider.value(value: EngagementService.instance),
        ],
        child: const ConnectivityOverlay(
          child: AdBlockOverlay(child: _AppRoot()),
        ),
      );
    }

    // Web keeps the static HTML boot screen over this transparent Flutter
    // first frame until _maybeTransition signals the first usable shell.
    // Android/iOS show their native initiation screen before Flutter and then
    // render the shell directly without a second Flutter splash.
    return const SizedBox.shrink();
  }
}

class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(NotificationService.instance.checkNow());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // A purchased ad-free window can lapse while the app sits in the
      // background — recheck against the wall clock on every resume so
      // ads correctly resume the moment it expires, not only on a full
      // app restart.
      unawaited(AdService.instance.refreshStatus());
      unawaited(AdService.instance.showAppOpenAd());
      // Forces a true network refresh (replacing each channel's cached 15
      // with whatever is genuinely latest on YouTube right now) — but only
      // if it's been a few minutes since the last one, to avoid hammering
      // the RSS endpoint on rapid app-switching.
      unawaited(context.read<FeedProvider>().refreshOnResume());
      // Check the same RSS sources for uploads discovered while the app was
      // suspended. NotificationService throttles this to one foreground poll
      // per ten minutes and shares in-flight work between lifecycle callers.
      unawaited(NotificationService.instance.checkNow());
      // Re-read the notification inbox from SharedPreferences so the bell
      // badge reflects any items the WorkManager background isolate wrote
      // while the app was suspended. The background task cannot reach the
      // main isolate's ValueNotifier directly, so we pull the latest count
      // from disk on every resume — this is the cross-isolate sync point.
      unawaited(NotificationStore.instance.reload());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!UserProfileService.instance.onboardingComplete) {
      return MyBusinessScreen(
        isOnboarding: true,
        // onboardingComplete flips inside MyBusinessScreen._save() before
        // this fires, so the rebuild below reliably picks the MainShell
        // branch instead of looping back into onboarding.
        onDone: () => setState(() {}),
      );
    }
    return const MainShell();
  }
}
