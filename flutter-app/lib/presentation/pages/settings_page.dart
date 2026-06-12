import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show timeDilation;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ink/ink.dart';
import '../../core/theme/app_theme.dart';
import '../providers/app_providers.dart';
import '../widgets/font_picker_sheet.dart';
import '../widgets/reader_settings_sheet.dart';
import '../widgets/t_text.dart';

/// 设置页：主题 / 繁简 / 阅读偏好 / 离线缓存 / 关于。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const TText('设置')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SectionHeader('显示'),
          ListTile(
            minTileHeight: 56,
            leading: const Icon(Icons.palette_outlined),
            title: const TText('主题'),
            subtitle: TText(AppThemeId.fromKey(settings.themeKey).label),
            onTap: () => _showThemePicker(context, ref),
          ),
          ListTile(
            minTileHeight: 56,
            leading: const Icon(Icons.font_download_outlined),
            title: const TText('字体'),
            subtitle:
                Text(ref.watch(fontControllerProvider).selected.label),
            onTap: () => showFontPickerSheet(context),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.translate),
            title: const TText('繁體中文'),
            subtitle: const TText('开启后全站显示繁体'),
            value: !settings.isSimplified,
            onChanged: (_) => controller.toggleLanguage(),
          ),
          ListTile(
            minTileHeight: 56,
            leading: const Icon(Icons.text_fields),
            title: const TText('阅读设置'),
            subtitle: const TText('字号、行距、字距、段距'),
            onTap: () => showReaderSettingsSheet(context),
          ),
          const BrushDivider(height: 18, indent: 16, endIndent: 16, seed: 33),
          _SectionHeader('数据'),
          ListTile(
            minTileHeight: 56,
            leading: const Icon(Icons.download_done_outlined),
            title: const TText('离线缓存管理'),
            subtitle: const TText('查看与删除已下载的经书'),
            onTap: () => context.push('/downloads'),
          ),
          const BrushDivider(height: 18, indent: 16, endIndent: 16, seed: 35),
          _SectionHeader('其他'),
          ListTile(
            minTileHeight: 56,
            leading: const Icon(Icons.info_outline),
            title: const TText('关于乾隆大藏经'),
            onTap: () => context.push('/about'),
          ),
          // 开发者工具（仅 debug/profile）：动画慢放/加速，用于转场调试与
          // 慢动作取证（曾经要临时改代码重编译，见 §9 坑9）。
          if (!kReleaseMode) ...[
            const BrushDivider(
                height: 18, indent: 16, endIndent: 16, seed: 37),
            _SectionHeader('开发者'),
            const _DevDilationTile(),
          ],
        ],
      ),
    );
  }

  void _showThemePicker(BuildContext context, WidgetRef ref) {
    final settings = ref.read(settingsProvider);
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: TText(
                '选择主题',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
            const BrushUnderline(width: 56, thickness: 2.2, seed: 23),
            // 六幅小画卷缩略（P3.8）：预览色取各主题真实 token。
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  for (final theme in AppThemeId.values)
                    InkThemeThumb(
                      theme: theme,
                      selected: settings.themeKey == theme.key,
                      onTap: () {
                        ref
                            .read(settingsProvider.notifier)
                            .setTheme(theme.key);
                        Navigator.pop(sheetContext);
                      },
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

/// 动画时间膨胀滑杆（开发者工具）：直接驱动 Flutter 全局 [timeDilation]，
/// 0.1×（10 倍加速）～ 10×（10 倍慢放），1× 居中。转场由墨晕/相机/墨缘环
/// 多个动画协同，必须整体缩放观感才真实——相机定时器已随 timeDilation
/// 同步（app_router）。对数刻度：两端十倍、中点正好 1×。
/// 不持久化（重启复位）；深链巡检通道 `?dilation=<v>` 可脚本化设置。
class _DevDilationTile extends StatefulWidget {
  const _DevDilationTile();

  @override
  State<_DevDilationTile> createState() => _DevDilationTileState();
}

class _DevDilationTileState extends State<_DevDilationTile> {
  static double _toLog(double v) => math.log(v) / math.ln10; // [-1, 1]
  static double _fromLog(double l) => math.pow(10, l).toDouble();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ink = context.ink;
    final dilation = timeDilation.clamp(0.1, 10.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Icon(Icons.slow_motion_video,
                  size: 22, color: colors.mutedForeground),
              const SizedBox(width: 12),
              Expanded(
                child: TText(
                  '动画慢放',
                  style: TextStyle(fontSize: 15, color: colors.foreground),
                ),
              ),
              Text(
                '${dilation.toStringAsFixed(dilation < 1 ? 2 : 1)}×',
                style: TextStyle(fontSize: 13, color: colors.mutedForeground),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: ink.inkMedium,
              inactiveTrackColor: ink.inkLight.withValues(alpha: 0.35),
              thumbColor: ink.inkStrong,
              overlayColor: ink.inkMedium.withValues(alpha: 0.12),
            ),
            child: Slider(
              value: _toLog(dilation),
              min: -1,
              max: 1,
              divisions: 40,
              label: '${dilation.toStringAsFixed(dilation < 1 ? 2 : 1)}×',
              onChanged: (l) =>
                  setState(() => timeDilation = _fromLog(l).clamp(0.1, 10.0)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TText(
            '>1 慢放、<1 加速，作用于全部动画；重启复位。仅 debug/profile 可见',
            style: TextStyle(fontSize: 12, color: colors.mutedForeground),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TText(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: context.colors.mutedForeground,
        ),
      ),
    );
  }
}
