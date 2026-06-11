import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../providers/app_providers.dart';
import 't_text.dart';

/// 阅读设置（web Header 设置弹窗的移动端 BottomSheet 形态）：
/// 字号 / 行距 / 字距 / 段距 / 主题 / 繁简。
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

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.62,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (context, scrollController) => ListView(
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
          const SizedBox(height: 8),
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
              TText('简繁转换',
                  style: TextStyle(fontSize: 15, color: colors.foreground)),
              const Spacer(),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('简体')),
                  ButtonSegment(value: false, label: Text('繁體')),
                ],
                selected: {settings.isSimplified},
                onSelectionChanged: (_) => controller.toggleLanguage(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TText('主题',
              style: TextStyle(fontSize: 15, color: colors.foreground)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final theme in AppThemeId.values)
                ChoiceChip(
                  label: TText(theme.label),
                  selected: settings.themeKey == theme.key,
                  onSelected: (_) => controller.setTheme(theme.key),
                ),
            ],
          ),
        ],
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
