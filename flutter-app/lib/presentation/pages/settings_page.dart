import 'package:flutter/material.dart';
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
