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
      ResourceCategoryData.loadCategories().then((_) {
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
    final awarenessItems = [
      (Icons.ondemand_video_rounded, 'Watch lessons',
          'Learn from clear videos and Shorts.'),
      (Icons.menu_book_rounded, 'Read free books',
          'Build useful skills at your own pace.'),
      (Icons.article_rounded, 'Follow useful blogs',
          'Find ideas and practical guidance.'),
    ];

    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 760;
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Semantics(
                          header: true,
                          child: Column(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: AppTheme.gold,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: const Icon(Icons.play_arrow_rounded,
                                    color: Colors.white, size: 38),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                'Welcome to FinReels',
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.4,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Learn money. Grow your work. Take your next step.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(
                                      color: AppTheme.textSecondary(context),
                                      height: 1.4,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          'Here is what you can do',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 12),
                        if (isWide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (var i = 0; i < awarenessItems.length; i++)
                                Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      right: i == awarenessItems.length - 1 ? 0 : 10,
                                    ),
                                    child: _AwarenessItem(
                                      icon: awarenessItems[i].$1,
                                      title: awarenessItems[i].$2,
                                      description: awarenessItems[i].$3,
                                    ),
                                  ),
                                ),
                            ],
                          )
                        else
                          Column(
                            children: [
                              for (final item in awarenessItems)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _AwarenessItem(
                                    icon: item.$1,
                                    title: item.$2,
                                    description: item.$3,
                                  ),
                                ),
                            ],
                          ),
                        const SizedBox(height: 20),
                        Text(
                          'First, tell us what you do',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Search your profession, skill, or business. This helps us show you better content.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textSecondary(context),
                                height: 1.4,
                              ),
                        ),
                        const SizedBox(height: 14),
                        _SearchField(onChanged: _setQuery),
                        const SizedBox(height: 10),
                        if (_query.isEmpty)
                          Text(
                            'Type a word to see matching choices. You can choose more than one, or start exploring now.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.textMuted(context),
                                  height: 1.35,
                                ),
                          )
                        else
                          _buildSearchResults(context),
                      ],
                    ),
                  ),
                ),
              );
            },
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
            widget.isOnboarding
                ? (_selected.isEmpty
                    ? 'Start exploring'
                    : 'Continue (${_selected.length} selected)')
                : (_selected.isEmpty
                    ? 'Skip for now'
                    : 'Save (${_selected.length} selected)'),
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

class _AwarenessItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _AwarenessItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$title. $description',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.dividerColor(context), width: 0.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppTheme.gold, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary(context), height: 1.3)),
                ],
              ),
            ),
          ],
        ),
      ),
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
      child: Semantics(
        textField: true,
        label: 'Search your profession, skill, or business',
        child: TextField(
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          style: TextStyle(color: AppTheme.textColor(context)),
          decoration: InputDecoration(
            labelText: 'Search your profession, skill, or business',
            hintText: 'Try “nurse”, “law”, “tailor”, or “solar”',
            hintStyle: TextStyle(color: AppTheme.textMuted(context)),
            prefixIcon: Icon(Icons.search_rounded,
                color: AppTheme.textMuted(context)),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
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
