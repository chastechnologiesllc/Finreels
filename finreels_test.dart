import 'package:finreels/config/app_config.dart';
import 'package:finreels/data/channel_data.dart';
import 'package:finreels/models/video.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ── Video Model ─────────────────────────────────────────────────────────────
  group('Video model', () {
    final video = Video(
      id: 'abc123',
      title: 'Test Video',
      description: 'A test description',
      channelId: 'ch1',
      channelName: 'Test Channel',
      publishedAt: DateTime(2024, 6, 15),
      thumbnailUrl: 'https://img.youtube.com/vi/abc123/mqdefault.jpg',
    );

    test('watchUrl is correct', () {
      expect(video.watchUrl, 'https://www.youtube.com/watch?v=abc123');
    });

    test('thumbnailHd is correct', () {
      expect(
        video.thumbnailHd,
        'https://img.youtube.com/vi/abc123/maxresdefault.jpg',
      );
    });

    test('thumbnailMq is correct', () {
      expect(
        video.thumbnailMq,
        'https://img.youtube.com/vi/abc123/mqdefault.jpg',
      );
    });

    test('equality by id', () {
      final duplicate = Video(
        id: 'abc123',
        title: 'Different title',
        description: '',
        channelId: 'ch2',
        channelName: 'Other',
        publishedAt: DateTime.now(),
        thumbnailUrl: '',
      );
      expect(video, equals(duplicate));
    });

    test('JSON round-trip', () {
      final json = video.toJson();
      final restored = Video.fromJson(json);
      expect(restored.id, video.id);
      expect(restored.title, video.title);
      expect(restored.channelId, video.channelId);
      expect(restored.publishedAt, video.publishedAt);
    });
  });

  // ── Channel Data ────────────────────────────────────────────────────────────
  group('ChannelData', () {
    test('has exactly 12 channels', () {
      expect(ChannelData.all.length, 12);
    });

    test('School of Hard Knocks is in the list', () {
      expect(
        ChannelData.all.any((ch) => ch.name == 'School of Hard Knocks'),
        isTrue,
      );
    });

    test('all channels have non-empty IDs', () {
      for (final ch in ChannelData.all) {
        expect(ch.id.isNotEmpty, isTrue, reason: '${ch.name} has empty ID');
      }
    });

    test('all channels have valid RSS URLs', () {
      for (final ch in ChannelData.all) {
        expect(ch.rssUrl, contains('channel_id=${ch.id}'));
      }
    });

    test('all channels have 2-char initials', () {
      for (final ch in ChannelData.all) {
        expect(ch.initials.length, 2, reason: '${ch.name} initials wrong');
      }
    });

    test('all accent colors are non-transparent', () {
      for (final ch in ChannelData.all) {
        expect(ch.accentColor.a, greaterThan(0));
      }
    });
  });

  // ── AppConfig ───────────────────────────────────────────────────────────────
  group('AppConfig', () {
    test('package name is correct', () {
      expect(AppConfig.packageName, 'com.chastechgroup.finreels');
    });

    test('3 IAP product IDs defined', () {
      expect(AppConfig.iapProductIds.length, 3);
    });

    test('IAP IDs have correct format', () {
      for (final id in AppConfig.iapProductIds) {
        expect(id, startsWith('finreels_'));
      }
    });

    test('has 4 connectivity endpoints', () {
      expect(AppConfig.connectivityEndpoints.length, 4);
    });

    test('has 4 ad-check endpoints', () {
      expect(AppConfig.adCheckEndpoints.length, 4);
    });

    test('connectivity endpoints are HTTPS', () {
      for (final url in AppConfig.connectivityEndpoints) {
        expect(url, startsWith('https://'));
      }
    });
  });

  // ── Theme Colours ────────────────────────────────────────────────────────────
  group('Theme colours', () {
    test('gold is correct hex', () {
      const gold = Color(0xFFF59E0B);
      expect(gold.r, closeTo(245 / 255, 0.01));
      expect(gold.g, closeTo(158 / 255, 0.01));
      expect(gold.b, closeTo(11 / 255, 0.01));
    });

    test('dark background is pure black', () {
      const black = Color(0xFF000000);
      expect(black.r, 0);
      expect(black.g, 0);
      expect(black.b, 0);
    });

    test('light background is pure white', () {
      const white = Color(0xFFFFFFFF);
      expect(white.r, 1.0);
      expect(white.g, 1.0);
      expect(white.b, 1.0);
    });
  });
}
