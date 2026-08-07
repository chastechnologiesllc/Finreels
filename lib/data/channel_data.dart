import 'package:flutter/material.dart';

import '../models/channel.dart';
import 'resource_category_data.dart';

/// FinReels — 12 general-purpose channels, all IDs verified directly from
/// YouTube channel pages.
///
/// Root cause of "only 2 channels showing" (a historical bug in the
/// original, smaller channel list): most of the channel IDs on file were
/// WRONG — they did not correspond to the actual YouTube channels. Wrong
/// IDs return an empty XML feed (the channel exists but has no videos under
/// that ID), or a 404. Only Diary of A CEO and School of Hard Knocks had
/// correct IDs from the start.
///
/// All IDs below were confirmed by fetching the channel page directly and
/// reading the Channel ID from the page source / RSS link.
class ChannelData {
  ChannelData._();

  static const List<Channel> all = [
    Channel(
      // Verified: youtube.com/channel/UCGq-a57w-aPwyi3pW7XLiHw ✓
      id: 'UCGq-a57w-aPwyi3pW7XLiHw',
      name: 'The Diary Of A CEO',
      handle: '@thediaryofaceo',
      description:
          "Steven Bartlett interviews the world's most successful people — "
          'CEOs, founders and thought leaders on how they built empires.',
      accentColor: Color(0xFF0F172A),
      category: 'Entrepreneurship',
      focus: 'CEO interviews & success mindset',
      initials: 'DC',
    ),
    Channel(
      // Corrected: was UCeR0n8d_-y249rnQQye9_Sg (wrong)
      // Verified: youtube.com/channel/UCUyDOdBWhC1MCxEjC46d-zw ✓
      id: 'UCUyDOdBWhC1MCxEjC46d-zw',
      name: 'Alex Hormozi',
      handle: '@AlexHormozi',
      description:
          r'Built $100M+ businesses. Brutally honest advice on sales, '
          'offers and scaling. The best business content on YouTube.',
      accentColor: Color(0xFFEF4444),
      category: 'Sales & Business',
      focus: 'Offers, sales & business scaling',
      initials: 'AH',
    ),
    Channel(
      // Corrected: was UCpx-MG7wbF67nEiWuV9nO_g (wrong)
      // Verified: youtube.com/channel/UCQ4FNww3XoNgqIlkBqEAVCg ✓
      id: 'UCQ4FNww3XoNgqIlkBqEAVCg',
      name: 'Iman Gadzhi',
      handle: '@ImanGadzhi',
      description:
          'Built a multi-million agency by 18. Online business, '
          'agency building and steps to financial freedom.',
      accentColor: Color(0xFF0EA5E9),
      category: 'Entrepreneurship',
      focus: 'Online business & agency building',
      initials: 'IG',
    ),
    Channel(
      // Corrected: was UCZ2QJQzEKf2PUaS7RUQUTLQ (wrong)
      // Verified: youtube.com/c/MagnatesMedia → UCE4Gn00XZbpWvGUfIslT-tA ✓
      id: 'UCE4Gn00XZbpWvGUfIslT-tA',
      name: 'Magnates Media',
      handle: '@MagnatesMedia',
      description:
          "Documentary-style deep dives on how the world's biggest "
          'companies and entrepreneurs built their empires.',
      accentColor: Color(0xFF7C3AED),
      category: 'How They Got Rich',
      focus: 'Business documentaries & empire stories',
      initials: 'MM',
    ),
    Channel(
      // Corrected: was UCWpR4wMIlkE7JZnANqUMaQg (wrong)
      // Verified: youtube.com/@MyFirstMillionPod → UCyaN6mg5u8Cjy2ZI4ikWaug ✓
      id: 'UCyaN6mg5u8Cjy2ZI4ikWaug',
      name: 'My First Million',
      handle: '@MyFirstMillionPod',
      description:
          'Sam Parr and Shaan Puri break down how people made their first '
          'million — business ideas, case studies and wealth strategies.',
      accentColor: Color(0xFF10B981),
      category: 'Entrepreneurship',
      focus: 'Business ideas & wealth case studies',
      initials: 'MF',
    ),
    Channel(
      // Corrected: was UCGHbFkzNANwLy7GOdXs17Jg (wrong)
      // Verified: youtube.com/channel/UCVeuau7DLrg7zlAjxxDbdww ✓
      id: 'UCVeuau7DLrg7zlAjxxDbdww',
      name: 'HubSpot Marketing',
      handle: '@HubSpotMarketing',
      description:
          'Actionable marketing strategies and growth tactics from '
          "HubSpot — the world's leading CRM platform.",
      accentColor: Color(0xFFFF7A59),
      category: 'Sales & Marketing',
      focus: 'Marketing strategies & business growth',
      initials: 'HM',
    ),
    Channel(
      // Corrected: was UCVOeFxCnmHE2pqJ5XEPQ-pg (wrong)
      // Verified: youtube.com/c/NeilPatel → UCl-Zrl0QhF66lu1aGXaTbfw ✓
      id: 'UCl-Zrl0QhF66lu1aGXaTbfw',
      name: 'Neil Patel',
      handle: '@neilpatel',
      description:
          "The world's top digital marketer. SEO, content "
          'marketing and how to grow a business online from scratch.',
      accentColor: Color(0xFF2563EB),
      category: 'Sales & Marketing',
      focus: 'Digital marketing & SEO',
      initials: 'NP',
    ),
    Channel(
      // Corrected: was UCs_6DLTDKH6cFCzgm_C0Fog (wrong, off by a few chars)
      // Verified: youtube.com/c/DanLok → UCs_6DXZROU29pLvgQdCx4Ww ✓
      id: 'UCs_6DXZROU29pLvgQdCx4Ww',
      name: 'Dan Lok',
      handle: '@DanLok',
      description:
          'High ticket closer and serial entrepreneur. Premium sales '
          'skills and how to command high prices in any market.',
      accentColor: Color(0xFF1D4ED8),
      category: 'Sales & Marketing',
      focus: 'High ticket sales & closing',
      initials: 'DL',
    ),
    Channel(
      // Corrected: was UCOIhB9fpQE_2GlRSLIAGXUg (wrong)
      // Verified: youtube.com/channel/UCsQiYDzi0UtpdDIe7_DpcLw ✓
      id: 'UCsQiYDzi0UtpdDIe7_DpcLw',
      name: 'Jordan Platten',
      handle: '@jordanplatten',
      description:
          'Social media marketing agency expert. Build a 6-figure '
          'SMMA and get high-paying clients.',
      accentColor: Color(0xFFF59E0B),
      category: 'Sales & Marketing',
      focus: 'SMMA & social media marketing',
      initials: 'JP',
    ),
    Channel(
      // Verified: youtube.com/channel/UCmtBqvOp6xHlecDO0Un9O4w ✓
      id: 'UCmtBqvOp6xHlecDO0Un9O4w',
      name: 'School of Hard Knocks',
      handle: '@theschoolofhardknocks',
      description:
          'Raw interviews with self-made millionaires sharing exactly '
          'how they built their wealth — struggles, turning points and '
          'strategies that really worked.',
      accentColor: Color(0xFFD97706),
      category: 'How They Got Rich',
      focus: 'Millionaire interviews & wealth journeys',
      initials: 'SK',
    ),
    Channel(
      // Verified: youtube.com/@vthembekwayo → UC_Ktic72t5bDX_3go_9u_pg ✓
      id: 'UC_Ktic72t5bDX_3go_9u_pg',
      name: 'Vusi Thembekwayo',
      handle: '@vthembekwayo',
      description:
          'Global business strategist, venture capitalist and keynote speaker. '
          '480+ keynotes across 6 continents. Founder & CEO of MyGrowthFund. '
          'Unfiltered insights on leadership, disruption and the founder mindset.',
      accentColor: Color(0xFF16A34A),
      category: 'Entrepreneurship',
      focus: 'Leadership, strategy & disruption',
      initials: 'VT',
    ),
    Channel(
      // Verified: youtube.com/@marketing-explained → UCM_PsKK4kvrOTNrHlsgK6pQ ✓
      id: 'UCM_PsKK4kvrOTNrHlsgK6pQ',
      name: 'Marketing Explained',
      handle: '@marketing-explained',
      description:
          'Digital marketing explained simply — HubSpot tutorials, '
          'quick tips and strategies from Cyberclick. '
          'Inbound, SEO, paid media, social and more.',
      accentColor: Color(0xFFDB4437),
      category: 'Sales & Marketing',
      focus: 'Digital marketing tutorials & strategies',
      initials: 'ME',
    ),
  ];

  /// The 12 general-purpose channels above, PLUS every category-tagged
  /// channel that's been verified so far (see the per-category files under
  /// assets/data/resources/, loaded by ResourceCategoryData). This is what
  /// FeedProvider and everything else should actually read — [all] alone
  /// only has the original const 12.
  /// Combined list of all channels, deduplicated by channel ID.
  ///
  /// Without dedup, the same channel ID (e.g. BusinessDay Nigeria) appears up
  /// to 15× across _general.json + 14 category files, producing 655 Channel
  /// objects for only 458 unique IDs. This causes _sessionChannelOrder to
  /// carry duplicate IDs, makes _roundRobin emit the same video 15× per round,
  /// and fires up to 15 identical RSS fetches in refresh().
  ///
  /// First-wins priority: hardcoded 12 → category-specific verified channels
  /// → _general.json channels. A channel that is both category-specific and
  /// general keeps its category resourceCategoryId so _dateMixed can apply
  /// the 3-day boost when that category is selected.
  static List<Channel> get combined {
    final seen = <String>{};
    return [
      for (final ch in [...all, ...ResourceCategoryData.verifiedChannels])
        if (ch.id.isNotEmpty && seen.add(ch.id)) ch,
    ];
  }

  /// The subset of [combined] that should actually be fetched over the
  /// network for a person who has [selectedCategoryIds] selected as their
  /// "My Business": every general channel (resourceCategoryId == null),
  /// plus only the category-tagged channels they actually asked for.
  ///
  /// This is the one rule that lets ChannelData keep growing toward all 60
  /// categories without every launch — or every background notification
  /// check — getting slower and burning more data as it grows. Used by
  /// both FeedProvider.refresh() and the background new-upload checker in
  /// notification_service.dart, so they can't drift out of sync.
  static List<Channel> eagerFor(Set<String> selectedCategoryIds) => combined
      .where((c) =>
          c.resourceCategoryId == null || selectedCategoryIds.contains(c.resourceCategoryId))
      .toList();

  /// Lookup map by channel id — covers ALL channels including verified
  /// category channels (e.g. fashion design, barbing). Must be a live
  /// getter, not a static final field, because the verified channels come
  /// from ResourceCategoryData which is loaded asynchronously at startup.
  /// A static final would be computed at class init time (before that load
  /// completes) and only ever contain the 12 const channels.
  static Map<String, Channel> get byId => {
    for (final ch in combined) ch.id: ch,
  };

  static Channel get fallback => all.first;
}
