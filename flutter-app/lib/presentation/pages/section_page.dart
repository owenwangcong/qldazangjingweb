import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/catalog_models.dart';
import '../providers/app_providers.dart';
import '../widgets/book_list_tile.dart';
import '../widgets/offline_banner.dart';
import '../widgets/t_text.dart';

final _sectionBooksProvider =
    StreamProvider.family<List<CatalogBook>, String>(
  (ref, sectionId) =>
      ref.watch(catalogRepositoryProvider).watchBooksOfSection(sectionId),
);

final _sectionNameProvider = StreamProvider.family<String, String>(
  (ref, sectionId) =>
      ref.watch(catalogRepositoryProvider).watchSections().map(
            (sections) => sections
                .firstWhere(
                  (s) => s.sectionId == sectionId,
                  orElse: () => CatalogSection()
                    ..sectionId = sectionId
                    ..name = ''
                    ..order = 0,
                )
                .name,
          ),
);

/// 部类册列表（web `/juans/[id]` 的移动端形态）。
class SectionPage extends ConsumerWidget {
  const SectionPage({super.key, required this.sectionId});

  final String sectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(_sectionBooksProvider(sectionId)).value ?? const [];
    final name = ref.watch(_sectionNameProvider(sectionId)).value ?? '';

    return Scaffold(
      appBar: AppBar(
        title: TText(name.isEmpty ? '部类' : name),
        actions: [
          IconButton(
            tooltip: '下载整部离线',
            iconSize: 24,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(Icons.download_for_offline_outlined),
            onPressed: () => _confirmSectionDownload(context, ref, name),
          ),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: books.length,
              itemBuilder: (context, index) =>
                  BookListTile(book: books[index]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSectionDownload(
    BuildContext context,
    WidgetRef ref,
    String name,
  ) async {
    final display = ref.read(displayTextProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(display('下载整部离线')),
        content: Text(display('将「$name」全部册数加入离线下载队列？\n离线时会在网络恢复后自动下载。')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(display('取消')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(display('加入队列')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(bookRepositoryProvider).queueSectionDownload(sectionId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(display('已加入下载队列，可在「我的-离线缓存」查看进度'))),
      );
    }
  }
}
