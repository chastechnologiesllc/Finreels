import 'package:flutter/material.dart';

import '../data/resource_category_data.dart';
import '../models/resource_category.dart';
import '../services/user_profile_service.dart';
import '../theme/app_theme.dart';
import '../utils/category_search.dart';

/// Lets the person tell FinReels what they actually do — their trade,
/// their side business, or their profession — without showing a default
/// category catalogue. Search matches the canonical category names and the
/// curated aliases in the 60-category research index.
///
/// The first prompt/search layout is intentionally stable. Matching categories
/// appear as compact selectable results beneath the search field; this screen
/// never navigates to or becomes the old full category-list page.
class MyBusinessScreen extends StatefulWidget {
  /// True when this is shown as part of first-run onboarding rather than
  /// opened from Settings → Personalize.
  final bool isOnboarding;

  /// Called after onboarding is saved so main.dart can enter the shell.
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

  void _setQuery(String raw) {
    final query = raw.trim().toLowerCase();
    if (query == _query) return;
    setState(() => _query = query);
  }

  void _toggle(String id) => setState(() {
        if (!_selected.remove(id)) _selected.add(id);
      });

  List<ResourceCategory> get _matches {
    if (_query.isEmpty || !ResourceCategoryData.isLoaded) {
      return const <ResourceCategory>[];
    }
    // Keep broad one-character queries compact while ensuring an exact
    // category name, such as "medicine", ranks first when entered.
    return CategorySearch.search(
      ResourceCategoryData.all,
      _query,
      limit: 8,
    );
  }

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
          : widget.isOnboarding
              ? _buildOnboardingBody(context)
              : _buildSettingsBody(context),
    );
  }

  Widget _buildOnboardingBody(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 110, 20, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.explore_rounded,
                        size: 46, color: AppTheme.gold),
                    const SizedBox(height: 20),
                    Text(
                      'What do you want to do with FinReels?',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Search your profession, skills and businesses',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary(context),
                            height: 1.45,
                          ),
                    ),
                    const SizedBox(height: 28),
                    _SearchField(onChanged: _setQuery),
                    if (_query.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildSearchResults(context),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        _buildSaveBar(context),
      ],
    );
  }

  Widget _buildSettingsBody(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Text(
            'Search your profession, skill or business so FinReels can '
            'prioritize content for you instead of generic advice.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppTheme.textSecondary(context)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _SearchField(onChanged: _setQuery),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _query.isEmpty
              ? const SizedBox.shrink()
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: _buildSearchResults(context),
                ),
        ),
        _buildSaveBar(context),
      ],
    );
  }

  Widget _buildSearchResults(BuildContext context) {
    final matches = _matches;
    if (matches.isEmpty) {
      return Text(
        'No matching category found yet.',
        textAlign: TextAlign.center,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: AppTheme.textMuted(context)),
      );
    }

    return Column(
      children: [
        for (final category in matches)
          _CategoryTile(
            category: category,
            selected: _selected.contains(category.id),
            onTap: () => _toggle(category.id),
          ),
      ],
    );
  }

  Widget _buildSaveBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: AppTheme.bgColor(context),
        border: Border(
          top: BorderSide(color: AppTheme.dividerColor(context), width: 0.5),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.gold,
            foregroundColor: Colors.black,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

/// "FinReels" + the same gold play-button mark used in home_screen.dart.
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
          child: const Icon(Icons.play_arrow_rounded,
              color: Colors.white, size: 22),
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
          hintText: 'Type what you do — e.g. "tailor", "law", "solar"…',
          hintStyle: TextStyle(color: AppTheme.textMuted(context)),
          prefixIcon: Icon(Icons.search_rounded,
              color: AppTheme.textMuted(context)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final ResourceCategory category;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
                    Text(
                      category.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      category.shortDescription,
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
