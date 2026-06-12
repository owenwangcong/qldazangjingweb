import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/fonts/font_service.dart';
import '../../core/ink/ink.dart';
import '../../core/theme/app_theme.dart';
import '../providers/app_providers.dart';
import 't_text.dart';

/// 字体选择（web Header 字体弹窗的移动端 BottomSheet 形态）。
/// 选项标签在该字体加载完成后即用其本身渲染（即时预览）；
/// 未加载的字体在选中时才读入内存（按需加载，~0.2-0.5s）。
void showFontPickerSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => const _FontPickerSheet(),
  );
}

class _FontPickerSheet extends ConsumerWidget {
  const _FontPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final fontState = ref.watch(fontControllerProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 24),
        children: [
          const Center(
            child: TText(
              '选择字体',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
          // BottomSheet 顶部干笔分隔（P3.9）。
          const BrushDivider(height: 14, seed: 45, indent: 12, endIndent: 12),
          const SizedBox(height: 2),
          for (final font in AppFont.values)
            ListTile(
              minTileHeight: 56,
              title: Text(
                font.label,
                style: TextStyle(
                  fontSize: 20,
                  color: colors.foreground,
                  // 已加载的字体用其本身渲染标签（与 web 选择器一致的预览体验）。
                  fontFamily:
                      fontState.isLoaded(font) ? font.familyName : null,
                ),
              ),
              trailing: fontState.loadingKey == font.key
                  ? const EnsoLoading(size: 22)
                  : fontState.selected == font
                      ? Icon(Icons.check, color: colors.primary)
                      : null,
              onTap: fontState.loadingKey != null
                  ? null
                  : () => _select(context, ref, font),
            ),
        ],
      ),
    );
  }

  Future<void> _select(
    BuildContext context,
    WidgetRef ref,
    AppFont font,
  ) async {
    final display = ref.read(displayTextProvider);
    try {
      await ref.read(fontControllerProvider.notifier).select(font);
      await ref.read(settingsProvider.notifier).setFontFamily(font.key);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(display('字体加载失败，请重试'))),
        );
      }
    }
  }
}
