import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
          const Divider(),
          _SectionHeader('数据'),
          ListTile(
            minTileHeight: 56,
            leading: const Icon(Icons.download_done_outlined),
            title: const TText('离线缓存管理'),
            subtitle: const TText('查看与删除已下载的经书'),
            onTap: () => context.push('/downloads'),
          ),
          const Divider(),
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
              padding: EdgeInsets.all(16),
              child: TText(
                '选择主题',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
            for (final theme in AppThemeId.values)
              RadioListTile<String>(
                value: theme.key,
                groupValue: settings.themeKey,
                title: TText(theme.label),
                secondary: CircleAvatar(
                  radius: 12,
                  backgroundColor:
                      buildAppTheme(theme).colorScheme.primary,
                ),
                onChanged: (key) {
                  if (key != null) {
                    ref.read(settingsProvider.notifier).setTheme(key);
                  }
                  Navigator.pop(sheetContext);
                },
              ),
            const SizedBox(height: 8),
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
