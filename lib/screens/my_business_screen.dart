import 'package:flutter/material.dart';

import '../data/resource_category_data.dart';
import '../models/resource_category.dart';
import '../services/user_profile_service.dart';
import '../theme/app_theme.dart';
import '../utils/category_search.dart';

/// Lets the person tell FinReels what they actually do — their trade,
/// their side business, their profession — from the 60-category research
/// (see resource_category.dart). This is the one piece of information the
/// app was missing to turn "broad, unfiltered content for everyone" into
/// "the specific stuff that answers *your* pain point" — the exact gap
/// described in the founding notes.
///
/// Multi-select on purpose: someone can be a nurse who also does makeup
/// artistry on the side, and both should get priority.
///
/// Two ways to find your category, both always available:
///  1. Browse — Professions, then Skills & Trades, then Businesses (see
///     CategorySearch.sectionOrder). Only the first
///     [CategorySearch.defaultVisiblePerSection] of each show up front so
///     the first screen isn't a 60-item wall — the rest are one search away.
///  2. Search — type what you do ("sew", "POS", "fridge repair"...) and it
///     matches against each category's name AND its curated search
///     keywords/aliases (see CategorySearch.matches), across all 60, not
///     just the ones currently visible.
/// "Others" is always pinned at the end of the list — for a trade that
/// genuinely isn't one of the 60, or while FinReels doesn't have a keyword
/// match yet. Picking it is a safe no-op everywhere content is filtered by
/// category (ChannelData.eagerFor, BlogRssService, FeedProvider's Books
/// tab): nothing has that id, so it simply resolves to general content.
///
/// Built entirely from existing AppTheme colors/typography/spacing —
/// no new visual language, just this app's existing look applied to a
/// new screen.
class MyBusinessScreen extends StatefulWidget {
  /// True when this is shown as part of first-run onboarding (no screen to
  /// pop back to yet) rather than opened from Settings. Changes what
  /// happens on save/skip and softens the copy accordingly.
  final bool isOnboarding;

  /// Called instead of Navigator.pop() when [isOnboarding] is true, after
  /// the selection is saved and onboarding is marked complete — lets the
  /// caller (main.dart) decide how to enter the shell without this screen
  /// needing to import MainShell itself (main_shell.dart -> settings_screen.dart
  /// -> my_business_screen.dart already forms a chain; this avoids turning
  /// it into a cycle).
  final VoidCallback? onDone;

  const MyBusinessScreen({this.isOnboarding = false, this.onDone, super.key});

  @override
  State<MyBusinessScreen> createState() => _MyBusinessScreenState();
}

class _MyBusinessScreenState extends State<MyBusinessScreen> {
  late Set<String> _selected;
  String _query = '';
  bool _loading = !ResourceCategoryData.isLoaded;

  @override
  void initState() {
    super.initState();
    _selected = {...UserProfileService.instance.selectedCategoryIds};
    if (_loading) {
      ResourceCategoryData.load().then((_) {
        if (mounted) setState(() => _loading = false);
      });
    }
  }

  void _toggle(String id) => setState(() {
        if (!_selected.remove(id)) _selected.add(id);
      });

  Future<void> _save() async {
    await UserProfileService.instance.setSelection(_selected);
    if (!mounted) return;
    if (widget.isOnboarding) {
      await UserProfileService.instance.completeOnboarding();
      if (!mounted) return;
      widget.onDone?.call();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor(context),
      appBar: AppBar(
        backgroundColor: AppTheme.bgColor(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        leading: widget.isOnboarding
            ? null
            : IconButton(
                icon: Icon(Icons.arrow_back_ios_rounded,
                    color: AppTheme.textColor(context), size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
        title: widget.isOnboarding
            ? const _OnboardingBrand()
            : Text('My Business',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.gold))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: Text(
                    'Pick your profession, skill or business — or just search '
                    'for what you do — so FinReels can prioritize content for '
                    'you instead of generic advice.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary(context)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _SearchField(
                    onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(child: _buildList(context)),
                _buildSaveBar(context),
              ],
            ),
    );
  }

  Widget _buildList(BuildContext context) {
    final hasQuery = _query.isNotEmpty;
    final children = <Widget>[];
    var matchedAnyRealCategory = false;

    for (final section in CategorySearch.sectionOrder) {
      final all = ResourceCategoryData.bySection(section);
      final items = hasQuery
          ? CategorySearch.search(all, _query)
          : all.take(CategorySearch.defaultVisiblePerSection).toList();
      if (items.isEmpty) continue;
      matchedAnyRealCategory = true;
      children.add(_SectionLabel(section.pluralLabel));
      for (final c in items) {
        children.add(_CategoryTile(
          name: c.name,
          description: c.shortDescription,
          selected: _selected.contains(c.id),
          onTap: () => _toggle(c.id),
        ));
      }
    }

    // Every search that comes up empty against the real 60 categories still
    // gets a productive next step — Others below — instead of a dead end.
    if (hasQuery && !matchedAnyRealCategory) {
      children.add(_NoMatchNote(query: _query));
    }

    // Always present, regardless of query — the permanent catch-all.
    children.add(const _SectionLabel('Others'));
    children.add(_CategoryTile(
      name: CategorySearch.othersName,
      description: CategorySearch.othersDescription,
      selected: _selected.contains(CategorySearch.othersId),
      onTap: () => _toggle(CategorySearch.othersId),
    ));

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: children,
    );
  }

  Widget _buildSaveBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: AppTheme.bgColor(context),
        border: Border(top: BorderSide(color: AppTheme.dividerColor(context), width: 0.5)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.gold,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: Text(
            _selected.isEmpty ? 'Skip for now' : 'Save (${_selected.length} selected)',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
        ),
      ),
    );
  }
}

/// "FinReels" + the same gold play-button mark used in home_screen.dart's
/// _AppHeader — same 34x34 size, same corner radius, same icon, same text
/// style. Deliberately not shared code with home_screen.dart's private
/// _AppHeader (that one also lays out search/refresh actions that don't
/// belong in an AppBar title), but every visual value below must stay
/// identical to it if that header ever changes.
class _OnboardingBrand extends StatelessWidget {
  const _OnboardingBrand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
              color: AppTheme.gold, borderRadius: BorderRadius.circular(9)),
          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 10),
        Text('FinReels',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800, letterSpacing: -0.5)),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _SearchField({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.dividerColor(context), width: 0.5),
      ),
      child: TextField(
        onChanged: onChanged,
        style: TextStyle(color: AppTheme.textColor(context)),
        decoration: InputDecoration(
          hintText: 'Type what you do — e.g. "tailor", "POS", "solar"…',
          hintStyle: TextStyle(color: AppTheme.textMuted(context)),
          prefixIcon: Icon(Icons.search_rounded, color: AppTheme.textMuted(context)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  const _SectionLabel(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.gold,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
      ),
    );
  }
}

/// A friendly next step instead of a dead end when a search matches none of
/// the 60 real categories — Others (always rendered right after this) is
/// the answer, so this note points straight at it rather than just saying
/// "no results".
class _NoMatchNote extends StatelessWidget {
  final String query;
  const _NoMatchNote({required this.query});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Text(
        'No exact match for "$query" yet — pick Others below and '
        "FinReels will keep things general for you.",
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: AppTheme.textMuted(context), fontStyle: FontStyle.italic),
      ),
    );
  }
}

/// Renders one selectable row — used for all 60 real categories AND for
/// the "Others" catch-all, which isn't a [ResourceCategory] at all. Taking
/// plain strings (rather than a ResourceCategory) is what lets both share
/// this exact same look with no special-casing.
class _CategoryTile extends StatelessWidget {
  final String name;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.name,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.gold.withValues(alpha: 0.10)
                : AppTheme.surfaceColor(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppTheme.gold : AppTheme.dividerColor(context),
              width: selected ? 1.2 : 0.5,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary(context)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected ? AppTheme.gold : AppTheme.textMuted(context),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
