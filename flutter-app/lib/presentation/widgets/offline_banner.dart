import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ink/ink.dart';
import '../../core/theme/app_theme.dart';
import '../providers/app_providers.dart';
import 't_text.dart';

/// Slim banner shown under the app bar while the device is offline.
/// Reading cached content keeps working; this only informs about网络功能.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(isOnlineProvider).value ?? true;
    if (online) return const SizedBox.shrink();
    final colors = context.colors;
    // 水墨化（P3.9）：浅墨衬底 + 底缘干笔一道；在 Column 流内不遮挡内容。
    // SafeArea：Shell 顶层（无 AppBar）时让出状态栏；在 Section 等页
    // （AppBar 已消费顶 inset）时自动为 0，不产生双重内边距。
    return Material(
      color: colors.muted,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
              child: Row(
                children: [
                  Icon(Icons.cloud_off,
                      size: 16, color: colors.mutedForeground),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TText(
                      '当前离线 — 已缓存内容可正常阅读',
                      style: TextStyle(
                          fontSize: 13, color: colors.mutedForeground),
                    ),
                  ),
                ],
              ),
            ),
            const BrushDivider(height: 6, seed: 55),
          ],
        ),
      ),
    );
  }
}
