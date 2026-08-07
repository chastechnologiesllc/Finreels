import 'package:flutter/material.dart';

import '../data/resource_category_data.dart';
import '../models/resource_category.dart';
import '../services/user_profile_service.dart';
import '../theme/app_theme.dart';
import '../utils/category_search.dart';
import 'category_detail_screen.dart';

/// Search + browse across all 60 categories. This is the "access
/// everything" surface: nothing here is fetched until a specific category
/// is tapped (see CategoryDetailScreen) — browsing the list itself is
/// pure local data, instant, and free.
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor(context),
      appBar: AppBar(
        backgroundColor: AppTheme.bgColor(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: AppTheme.textColor(context), size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Discover',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: _SearchField(
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          Expanded(child: _buildList(context)),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    // Same Profession -> Skill -> Business order as onboarding (see
    // CategorySearch.sectionOrder) so the two pickers never disagree on
    // ordering. Discover browses the full 60 always — no reduced default
    // list and no "Others" here, since this screen exists specifically to
    // see everything, not to make a quick onboarding decision.
    final children = <Widget>[];
    for (final section in CategorySearch.sectionOrder) {
      final all = ResourceCategoryData.bySection(section);
      final items = _query.isEmpty ? all : CategorySearch.search(all, _query);
      if (items.isEmpty) continue;
      children.add(_SectionLabel(section.pluralLabel));
      for (final c in items) {
        children.add(_DiscoverTile(category: c));
      }
    }
    if (children.isEmpty) {
      return Center(
        child: Text('No match for "$_query"', style: TextStyle(color: AppTheme.textMuted(context))),
      );
    }
    return ListView(padding: const EdgeInsets.only(bottom: 16), children: children);
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
        autofocus: true,
        onChanged: onChanged,
        style: TextStyle(color: AppTheme.textColor(context)),
        decoration: InputDecoration(
          hintText: 'Search skills, businesses, professions…',
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
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppTheme.gold, letterSpacing: 1.4, fontWeight: FontWeight.w800, fontSize: 11),
      ),
    );
  }
}

class _DiscoverTile extends StatelessWidget {
  final ResourceCategory category;
  const _DiscoverTile({required this.category});

  @override
  Widget build(BuildContext context) {
    final isSelected = UserProfileService.instance.isSelected(category.id);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => CategoryDetailScreen(category: category)),
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.dividerColor(context), width: 0.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(category.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(category.shortDescription,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppTheme.textSecondary(context))),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (isSelected)
                const Icon(Icons.check_circle_rounded, color: AppTheme.gold, size: 20)
              else
                Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted(context)),
            ],
          ),
        ),
      ),
    );
  }
}
