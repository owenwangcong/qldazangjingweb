import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/catalog_models.dart';
import '../providers/app_providers.dart';
import '../widgets/t_text.dart';

final _sectionsProvider = StreamProvider<List<CatalogSection>>(
  (ref) => ref.watch(catalogRepositoryProvider).watchSections(),
);

final _classicsProvider = StreamProvider<Map<String, List<ClassicEntry>>>(
  (ref) => ref.watch(catalogRepositoryProvider).watchClassics(),
);

/// 首页：常用经典 + 部类目录（web `/` 的移动端形态）。
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final sections = ref.watch(_sectionsProvider).value ?? const [];
    final classics = ref.watch(_classicsProvider).value ?? const {};
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const TText('乾隆大藏经'),
        actions: [
          IconButton(
            tooltip: '字典',
            iconSize: 24,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: () => context.push('/dict'),
            icon: const Icon(Icons.translate),
          ),
          IconButton(
            tooltip: '设置',
            iconSize: 24,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // ---- 常用经典 --------------------------------------------------
          if (classics.isNotEmpty)
            SliverToBoxAdapter(
              child: _ClassicsCard(
                classics: classics,
                activeTab: classics.containsKey(settings.classicsActiveTab)
                    ? settings.classicsActiveTab
                    : classics.keys.first,
                visible: settings.classicsVisible,
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            sliver: SliverToBoxAdapter(
              child: TText(
                '部类目录',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colors.foreground,
                ),
              ),
            ),
          ),
          // ---- 部类 Grid --------------------------------------------------
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                mainAxisExtent: 64,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              delegate: SliverChildBuilderDelegate(
                childCount: sections.length,
                (context, index) {
                  final section = sections[index];
                  return Material(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () =>
                          context.push('/section/${section.sectionId}'),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: colors.border.withValues(alpha: 0.6),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: TText(
                          section.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colors.cardForeground,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassicsCard extends ConsumerWidget {
  const _ClassicsCard({
    required this.classics,
    required this.activeTab,
    required this.visible,
  });

  final Map<String, List<ClassicEntry>> classics;
  final String activeTab;
  final bool visible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final entries = classics[activeTab] ?? const [];

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      color: colors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.border.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: title + collapse toggle (48dp target).
          InkWell(
            onTap: () => ref
                .read(settingsProvider.notifier)
                .setClassicsVisible(!visible),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                children: [
                  TText(
                    '常用经典',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: colors.cardForeground,
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: visible ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(Icons.keyboard_arrow_down,
                        color: colors.mutedForeground),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: visible
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            secondChild: const SizedBox(width: double.infinity),
            firstChild: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Category chips (horizontal scroll, mobile pattern).
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      for (final category in classics.keys)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: TText(category),
                            selected: category == activeTab,
                            selectedColor:
                                colors.primary.withValues(alpha: 0.3),
                            onSelected: (_) => ref
                                .read(settingsProvider.notifier)
                                .setClassicsTab(category),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                // Entries of the active category.
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in entries)
                        ActionChip(
                          label: TText(entry.title),
                          backgroundColor: colors.muted,
                          side: BorderSide(
                            color: colors.border.withValues(alpha: 0.5),
                          ),
                          onPressed: () =>
                              context.push('/book/${entry.bookId}'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
