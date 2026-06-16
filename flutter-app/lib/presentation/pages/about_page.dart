import 'package:flutter/material.dart';

import '../../core/ink/ink.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/t_text.dart';

/// 关于页（web `/intro` 的移动端重写——内容针对 App 的交互方式）。
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bodyStyle = TextStyle(
      fontSize: 15,
      height: 1.8,
      color: colors.foreground,
    );
    final headerStyle = TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w700,
      color: colors.foreground,
    );

    return Scaffold(
      appBar: AppBar(title: const TText('关于乾隆大藏经')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          TText(
            '《乾隆大藏经》，又称《清藏》《龙藏》，是清代官刻的汉文大藏经，收录经、律、论等典籍一千六百余部。'
            '本应用致力于提供便捷、现代化的大藏经阅读体验，支持完全离线阅读。',
            style: bodyStyle,
          ),
          const SizedBox(height: 24),
          TText('离线优先', style: headerStyle),
          const SizedBox(height: 8),
          TText(
            '• 全部目录内置于应用中，无需网络即可浏览\n'
            '• 任意经书打开一次后即永久缓存，可离线阅读\n'
            '• 可在部类页一键下载整部经书；离线时操作会进入队列，联网后自动完成\n'
            '• 收藏、书签、笔记、阅读进度全部保存在本机',
            style: bodyStyle,
          ),
          const SizedBox(height: 24),
          TText('阅读功能', style: headerStyle),
          const SizedBox(height: 8),
          TText(
            '• 长按选中经文，可进行 复制/字典/今译/释义/笔记 操作\n'
            '• 字典查询佛学辞典；今译与释义由 AI 生成（需联网）\n'
            '• 支持简繁切换、六款配色主题、字号行距等阅读偏好\n'
            '• 自动记忆每本经书的阅读位置',
            style: bodyStyle,
          ),
          const SizedBox(height: 24),
          TText('数据来源', style: headerStyle),
          const SizedBox(height: 8),
          TText(
            '经文数据来自 qldazangjing.com（乾隆大藏经网站）。'
            '若发现经文错漏，欢迎通过网站反馈。',
            style: bodyStyle,
          ),
          // 卷尾留白收笔：淡祥云（每屏唯一意象）+ 落款印。
          const SizedBox(height: 40),
          const Center(child: CloudPattern(width: 110, opacity: 0.07)),
          const SizedBox(height: 16),
          const Center(child: SealStamp(text: '藏', size: 30)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
