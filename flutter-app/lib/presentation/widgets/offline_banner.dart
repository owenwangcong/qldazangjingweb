import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    return Material(
      color: colors.muted,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Icon(Icons.cloud_off, size: 16, color: colors.mutedForeground),
            const SizedBox(width: 8),
            Expanded(
              child: TText(
                '当前离线 — 已缓存内容可正常阅读',
                style: TextStyle(fontSize: 13, color: colors.mutedForeground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
