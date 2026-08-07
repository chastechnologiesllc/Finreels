# ── Flutter ─────────────────────────────────────────────────────────────────
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ── Google Mobile Ads ────────────────────────────────────────────────────────
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.ads.** { *; }
-dontwarn com.google.android.gms.ads.**

# ── WorkManager ──────────────────────────────────────────────────────────────
-keep class androidx.work.** { *; }
-keep class com.google.gson.** { *; }
-keepnames class androidx.work.impl.** { *; }

# ── Billing / IAP ────────────────────────────────────────────────────────────
-keep class com.android.billingclient.** { *; }
-dontwarn com.android.billingclient.**

# ── General ──────────────────────────────────────────────────────────────────
-dontwarn org.xmlpull.v1.**
-keep class org.xmlpull.v1.** { *; }

# ── Google Play Core (deferred components) ───────────────────────────────────
# Flutter's own engine embedding (FlutterPlayStoreSplitApplication,
# PlayStoreDeferredComponentManager) references Play Core's split-install
# classes unconditionally, for Flutter's "deferred components" / dynamic
# feature delivery support. FinReels doesn't use deferred components — this
# app ships as one normal APK/AAB — so these classes are never actually
# reached at runtime. Since Google discontinued the unified play-core
# artifact that used to provide them, R8's missing-class check hard-fails
# the release build over this dead code path unless told it's expected.
# See: https://github.com/flutter/flutter/issues/165646 and many similar.
-dontwarn com.google.android.play.core.**

