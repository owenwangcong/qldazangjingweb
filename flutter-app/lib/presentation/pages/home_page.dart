import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ink/ink.dart';
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

/// 首页（P3.2 水墨化）：常用经典 = 册页题签，部类目录 = 笺纸卡。
/// 留白遵守设计八则 #1：水平边距 ≥16dp、区块垂直间距 ≥12dp。
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
            icon: const Icon(Icons.translate, semanticLabel: '字典'),
          ),
          IconButton(
            tooltip: '设置',
            iconSize: 24,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined, semanticLabel: '设置'),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // ---- 常用经典（册页题签） --------------------------------------
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
            // 区块间距：上接经典卡 bottom 12 → 合计 ≥12dp。
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
          // ---- 部类 Grid（笺纸卡） ----------------------------------------
          if (sections.isEmpty)
            // 空态：唯一一处淡莲花（设计八则 #6，每屏主意象 ≤1）。
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const LotusOutline(size: 140, opacity: 0.08),
                    const SizedBox(height: 12),
                    TText(
                      '暂无目录',
                      style: TextStyle(color: colors.mutedForeground),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              sliver: SliverLayoutBuilder(
                builder: (context, constraints) {
                  // Android 的 warm-up 帧会以 0×0 约束预布局一次，而
                  // MaxCrossAxisExtent 委托在 crossAxisExtent == 0 时直接断言，
                  // 导致 geometry 为 null、后续帧持续空指针。无效约束时短路。
                  if (constraints.crossAxisExtent <= 0) {
                    return const SliverToBoxAdapter(child: SizedBox.shrink());
                  }
                  return _buildSectionsGrid(context, sections);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionsGrid(
      BuildContext context, List<CatalogSection> sections) {
    final colors = context.colors;
    return SliverGrid(
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
          // 笺纸卡：吃墨边缘，种子随索引错开避免边缘纹路雷同；
          // 滚动网格内关阴影（§9 性能教训：模糊阴影逐帧重画）。
          return InkCard(
            seed: 7 + index,
            padding: EdgeInsets.zero,
            borderRadius: 10,
            shadow: false,
            onTap: () => context.push('/section/${section.sectionId}'),
            child: Center(
              child: TText(
                section.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.cardForeground,
                ),
              ),
            ),
          );
        },
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: InkCard(
        seed: 3,
        borderRadius: 12,
        padding: EdgeInsets.zero,
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
                      // 微交互档 180–240ms（§4.2）。
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      child: Icon(Icons.keyboard_arrow_down,
                          color: colors.mutedForeground),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              // 微交互档 180–240ms（§4.2）。
              duration: const Duration(milliseconds: 220),
              crossFadeState: visible
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              secondChild: const SizedBox(width: double.infinity),
              firstChild: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 分类页签：选中 = 重墨 + 笔触下划线（替换 Material chip）。
                  SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        for (final category in classics.keys)
                          _CategoryTab(
                            label: category,
                            selected: category == activeTab,
                            onTap: () => ref
                                .read(settingsProvider.notifier)
                                .setClassicsTab(category),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  // 册页题签：左缘墨线 + 浅笺底，仿书衣题签。
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (var i = 0; i < entries.length; i++)
                          _ClassicSlip(
                            title: entries[i].title,
                            seed: 41 + i,
                            onTap: () =>
                                context.push('/book/${entries[i].bookId}'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 分类页签：墨色文字，选中态加笔触下划线（形状差异，不只换色）。
class _CategoryTab extends StatelessWidget {
  const _CategoryTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = context.ink;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            TText(
              label,
              style: TextStyle(
                fontSize: 15,
                height: 1.2,
                color: selected ? ink.inkStrong : ink.inkMedium,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            SizedBox(
              height: 7,
              child: selected
                  ? Center(
                      child: BrushUnderline(
                        width: (label.length * 15.0).clamp(24.0, 72.0),
                        thickness: 2.2,
                        seed: 9,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// 册页题签（P3.2）：浅笺底色 + 吃墨边缘 + 左缘一道墨线（仿书衣题签），
/// 命中区 ≥48dp。
class _ClassicSlip extends StatelessWidget {
  const _ClassicSlip({
    required this.title,
    required this.seed,
    required this.onTap,
  });

  final String title;
  final int seed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = context.ink;
    final colors = context.colors;
    return InkCard(
      seed: seed,
      borderRadius: 6,
      shadow: false,
      color: colors.muted,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 3,
              height: 20,
              decoration: BoxDecoration(
                color: ink.inkMedium.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
            const SizedBox(width: 10),
            TText(
              title,
              style: TextStyle(fontSize: 15, color: colors.cardForeground),
            ),
          ],
        ),
      ),
    );
  }
}
