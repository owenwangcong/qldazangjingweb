import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ink/ink.dart';
import '../../core/theme/app_theme.dart';
import '../providers/app_providers.dart';
import 'font_picker_sheet.dart';
import 't_text.dart';

/// 阅读设置（web Header 设置弹窗的移动端 BottomSheet 形态）：
/// 字号 / 行距 / 字距 / 段距 / 主题 / 繁简。P3.4 水墨化：墨色滑杆、
/// 笔触选中态、主题选纸样小卡。
void showReaderSettingsSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _ReaderSettingsSheet(),
  );
}

class _ReaderSettingsSheet extends ConsumerWidget {
  const _ReaderSettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final colors = context.colors;
    final ink = context.ink;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.62,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (context, scrollController) => SliderTheme(
        // 墨色滑杆：浓墨柄、重墨已选段、淡墨轨。
        data: SliderTheme.of(context).copyWith(
          activeTrackColor: ink.inkMedium,
          inactiveTrackColor: ink.inkLight.withValues(alpha: 0.35),
          thumbColor: ink.inkStrong,
          overlayColor: ink.inkMedium.withValues(alpha: 0.12),
          activeTickMarkColor: ink.inkLight,
          inactiveTickMarkColor: ink.inkLight.withValues(alpha: 0.4),
        ),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: colors.mutedForeground.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Center(
              child: TText(
                '阅读设置',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: colors.foreground,
                ),
              ),
            ),
            const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 6),
                child: BrushUnderline(width: 56, thickness: 2.2, seed: 23),
              ),
            ),
            // BottomSheet 顶部干笔分隔（P3.9）。
            const BrushDivider(height: 14, seed: 47),
            const SizedBox(height: 2),
            _SliderRow(
              label: '字号',
              value: settings.fontSize,
              min: 14,
              max: 40,
              divisions: 13,
              display: settings.fontSize.round().toString(),
              onChanged: controller.setFontSize,
            ),
            _SliderRow(
              label: '行距',
              value: settings.lineHeight,
              min: 1.0,
              max: 3.0,
              divisions: 8,
              display: settings.lineHeight.toStringAsFixed(2),
              onChanged: controller.setLineHeight,
            ),
            _SliderRow(
              label: '字距',
              value: settings.letterSpacingEm,
              min: -0.05,
              max: 0.15,
              divisions: 4,
              display: settings.letterSpacingEm.toStringAsFixed(2),
              onChanged: controller.setLetterSpacing,
            ),
            _SliderRow(
              label: '段距',
              value: settings.paragraphSpacing,
              min: 0,
              max: 40,
              divisions: 8,
              display: settings.paragraphSpacing.round().toString(),
              onChanged: controller.setParagraphSpacing,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TText('字体',
                    style: TextStyle(fontSize: 15, color: colors.foreground)),
                const Spacer(),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    foregroundColor: colors.foreground,
                  ),
                  onPressed: () => showFontPickerSheet(context),
                  icon: Text(
                    ref.watch(fontControllerProvider).selected.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontFamily:
                          ref.watch(fontControllerProvider).activeFamily,
                    ),
                  ),
                  label: Icon(Icons.chevron_right,
                      size: 18, color: colors.mutedForeground),
                ),
              ],
            ),
            Row(
              children: [
                TText('简繁转换',
                    style: TextStyle(fontSize: 15, color: colors.foreground)),
                const Spacer(),
                InkToggle(
                  options: const ['简体', '繁體'],
                  selectedIndex: settings.isSimplified ? 0 : 1,
                  onSelect: (_) => controller.toggleLanguage(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TText('主题',
                style: TextStyle(fontSize: 15, color: colors.foreground)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final theme in AppThemeId.values)
                  _ThemeSwatch(
                    theme: theme,
                    selected: settings.themeKey == theme.key,
                    onTap: () => controller.setTheme(theme.key),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.display,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        SizedBox(
          width: 44,
          child: TText(label,
              style: TextStyle(fontSize: 15, color: colors.foreground)),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            display,
            textAlign: TextAlign.end,
            style: TextStyle(fontSize: 13, color: colors.mutedForeground),
          ),
        ),
      ],
    );
  }
}

/// 主题选纸样（P3.4 简化版；P3.8 设置页升级为六幅小画卷缩略）：
/// 纸色小卡 + 墨点示意前景色，选中 = 朱砂印点。
class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  final AppThemeId theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = context.ink;
    final palette = buildAppTheme(theme).extension<AppColors>()!;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              children: [
                Container(
                  width: 64,
                  height: 30,
                  decoration: BoxDecoration(
                    color: palette.background,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: selected
                          ? ink.inkStrong.withValues(alpha: 0.7)
                          : ink.inkLight.withValues(alpha: 0.5),
                      width: selected ? 1.4 : 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '墨',
                    style: TextStyle(
                      fontSize: 13,
                      color: palette.foreground,
                      height: 1,
                    ),
                  ),
                ),
                if (selected)
                  Positioned(
                    right: 3,
                    top: 3,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: ink.sealRed,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            TText(
              theme.label,
              style: TextStyle(
                fontSize: 11,
                height: 1.1,
                color: selected ? ink.inkStrong : ink.inkMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
