import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/outbox_operation.dart';
import '../providers/app_providers.dart';
import '../widgets/t_text.dart';

final _cachedBooksProvider = StreamProvider<
    List<({String bookId, int sizeBytes, DateTime cachedAt})>>(
  (ref) => ref.watch(bookRepositoryProvider).watchCachedBooks(),
);

final _pendingOpsProvider = StreamProvider<List<OutboxOperation>>(
  (ref) => ref.watch(outboxProvider).watchAll().map(
        (ops) => ops
            .where((op) =>
                op.status == OutboxStatus.pending ||
                op.status == OutboxStatus.inFlight ||
                op.status == OutboxStatus.failed)
            .toList(),
      ),
);

final _titleLookupProvider =
    FutureProvider.family<String, String>((ref, bookId) async {
  final book = await ref.watch(catalogRepositoryProvider).getBook(bookId);
  return book?.title ?? bookId;
});

/// 离线缓存管理（web 占位 `/downloads` 在移动端成为真实核心能力）：
/// 已缓存经书列表（左滑删除）+ 下载队列状态。
class DownloadsPage extends ConsumerWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final cached = ref.watch(_cachedBooksProvider).value ?? const [];
    final pendingOps = ref.watch(_pendingOpsProvider).value ?? const [];
    final totalBytes =
        cached.fold<int>(0, (sum, item) => sum + item.sizeBytes);

    return Scaffold(
      appBar: AppBar(title: const TText('离线缓存')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Icon(Icons.storage_outlined,
                    size: 18, color: colors.mutedForeground),
                const SizedBox(width: 8),
                TText(
                  '已缓存 ${cached.length} 册 · ${_formatSize(totalBytes)}',
                  style:
                      TextStyle(fontSize: 14, color: colors.mutedForeground),
                ),
              ],
            ),
          ),
          if (pendingOps.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TText(
                '待同步队列（联网后自动下载）',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.mutedForeground,
                ),
              ),
            ),
            for (final op in pendingOps.take(20))
              ListTile(
                minTileHeight: 48,
                dense: true,
                leading: Icon(
                  op.status == OutboxStatus.failed
                      ? Icons.error_outline
                      : Icons.schedule,
                  size: 20,
                  color: op.status == OutboxStatus.failed
                      ? colors.destructive
                      : colors.mutedForeground,
                ),
                title: Text(
                  _describeOp(op),
                  style: TextStyle(fontSize: 14, color: colors.foreground),
                ),
                subtitle: op.lastError == null
                    ? null
                    : Text(
                        op.lastError!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, color: colors.mutedForeground),
                      ),
              ),
            const Divider(),
          ],
          if (cached.isEmpty)
            Padding(
              padding: const EdgeInsets.all(48),
              child: Center(
                child: TText(
                  '暂无离线缓存\n打开任意经书即自动缓存',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: colors.mutedForeground, height: 1.8),
                ),
              ),
            )
          else
            for (final item in cached)
              Slidable(
                key: ValueKey('cache-${item.bookId}'),
                endActionPane: ActionPane(
                  motion: const DrawerMotion(),
                  extentRatio: 0.25,
                  children: [
                    CustomSlidableAction(
                      onPressed: (_) => ref
                          .read(bookRepositoryProvider)
                          .deleteCache(item.bookId),
                      backgroundColor: colors.destructive,
                      foregroundColor: colors.destructiveForeground,
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.delete_outline),
                          SizedBox(height: 4),
                          TText('删除', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                child: Consumer(
                  builder: (context, ref, _) {
                    final title =
                        ref.watch(_titleLookupProvider(item.bookId)).value ??
                            item.bookId;
                    return ListTile(
                      minTileHeight: 56,
                      leading: Icon(Icons.menu_book_outlined,
                          color: colors.mutedForeground),
                      title: TText(title,
                          style: TextStyle(color: colors.foreground)),
                      subtitle: Text(
                        _formatSize(item.sizeBytes),
                        style: TextStyle(
                            fontSize: 12, color: colors.mutedForeground),
                      ),
                      onTap: () => context.push('/book/${item.bookId}'),
                    );
                  },
                ),
              ),
        ],
      ),
    );
  }

  String _describeOp(OutboxOperation op) {
    final status = switch (op.status) {
      OutboxStatus.pending => '等待中',
      OutboxStatus.inFlight => '下载中',
      OutboxStatus.failed => '失败（已重试 ${op.attempts} 次）',
      OutboxStatus.done => '完成',
    };
    final what = switch (op.type) {
      OutboxOpType.downloadBook => '下载经书 ${op.payloadJson}',
      OutboxOpType.downloadSection => '下载整部 ${op.payloadJson}',
    };
    return '$what · $status';
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}
