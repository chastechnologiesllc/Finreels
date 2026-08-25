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
  bool _searchFocused = false;
  final _searchKey = GlobalKey();
  late final FocusNode _searchFocusNode;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchFocusNode = FocusNode()..addListener(_handleSearchFocus);
    _searchController = TextEditingController();
    _selected = {...UserProfileService.instance.selectedCategoryIds};
    if (_loading) {
      ResourceCategoryData.loadCategories().then((_) {
        if (mounted) setState(() => _loading = false);
      });
    }
  }

  @override
  void dispose() {
    _searchFocusNode
      ..removeListener(_handleSearchFocus)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchFocus() {
    if (!mounted) return;
    final focused = _searchFocusNode.hasFocus;
    if (focused == _searchFocused) return;
    setState(() => _searchFocused = focused);
    if (focused) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final searchContext = _searchKey.currentContext;
        if (searchContext == null || !mounted) return;
        Scrollable.ensureVisible(
          searchContext,
          alignment: 0.08,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
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
    final compact = _searchFocused || _query.isNotEmpty;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, compact ? 18 : 64, 20, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!compact)
                      Semantics(
                        header: true,
                        child: Column(
                          children: [
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
                            const SizedBox(height: 18),
                            Text(
                              'First, tell us what you’re interested in exploring',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Search your profession, skill, or business.',
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
                    if (!compact) const SizedBox(height: 42),
                    Container(
                      key: _searchKey,
                      child: _SearchField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        onChanged: _setQuery,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (!compact && _query.isEmpty)
                      Text(
                        'Type a word to see matching choices. You can choose more than one, or start exploring now.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textMuted(context),
                              height: 1.35,
                            ),
                      ),
                    if (_query.isNotEmpty) _buildSearchResults(context),
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
        if (!_searchFocused)
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
          )
        else
          const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            key: _searchKey,
            child: _SearchField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: _setQuery,
            ),
          ),
        ),
        _buildSelectedCategories(context),
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

  Widget _buildSelectedCategories(BuildContext context) {
    final selected = _selected
        .map(ResourceCategoryData.byId)
        .whereType<ResourceCategory>()
        .toList(growable: false);
    if (selected.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 2),
      child: Semantics(
        container: true,
        label: 'Selected interests: ${selected.map((c) => c.name).join(', ')}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your selected interests',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in selected)
                  InputChip(
                    label: Text(category.name),
                    selected: true,
                    selectedColor: AppTheme.gold.withValues(alpha: 0.16),
                    checkmarkColor: AppTheme.gold,
                    onDeleted: () => _toggle(category.id),
                  ),
              ],
            ),
          ],
        ),
      ),
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

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final FocusNode focusNode;

  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.dividerColor(context), width: 0.5),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        keyboardType: TextInputType.text,
        textCapitalization: TextCapitalization.none,
        autocorrect: false,
        enableSuggestions: true,
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
