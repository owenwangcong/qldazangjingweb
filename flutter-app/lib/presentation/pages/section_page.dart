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
/// 全部经文已内置 App，点开即读，无需任何下载操作。
class SectionPage extends ConsumerWidget {
  const SectionPage({super.key, required this.sectionId});

  final String sectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(_sectionBooksProvider(sectionId)).value ?? const [];
    final name = ref.watch(_sectionNameProvider(sectionId)).value ?? '';

    return Scaffold(
      appBar: AppBar(title: TText(name.isEmpty ? '部类' : name)),
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
}
