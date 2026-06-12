import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

import '../../core/ink/ink.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/catalog_models.dart';
import '../providers/app_providers.dart';
import 't_text.dart';

/// Reusable book row. Swipe left to favorite/unfavorite (mobile replacement
/// for the web's hover/heart button), tap to open the reader.
class BookListTile extends ConsumerWidget {
  const BookListTile({
    super.key,
    required this.book,
    this.showAuthor = true,
  });

  final CatalogBook book;
  final bool showAuthor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return Slidable(
      key: ValueKey(book.bookId),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.28,
        children: [
          CustomSlidableAction(
            onPressed: (_) => _toggleFavorite(context, ref),
            backgroundColor: colors.primary,
            foregroundColor: colors.primaryForeground,
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite_border),
                SizedBox(height: 4),
                TText('收藏', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
      // 笺纸卡行（P3.3）：吃墨边缘替代 Material Card 直线描边；
      // 长列表关阴影（§9：模糊阴影在 Impeller 下逐帧重画）。
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: InkCard(
          seed: 17 + book.bookId.hashCode % 23,
          borderRadius: 12,
          shadow: false,
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          onTap: () => context.push('/book/${book.bookId}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TText(
                book.title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: colors.cardForeground,
                ),
              ),
              if (showAuthor && book.author.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: TText(
                        book.author,
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.mutedForeground,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (book.volume.isNotEmpty)
                      TText(
                        book.volume,
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.mutedForeground,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleFavorite(BuildContext context, WidgetRef ref) async {
    final study = ref.read(studyRepositoryProvider);
    final already = await study.isFavorite(book.bookId);
    if (already) {
      await study.removeFavorite(book.bookId);
    } else {
      await study.addFavorite(book.bookId);
    }
    if (context.mounted) {
      final display = ref.read(displayTextProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(display(already ? '已从收藏中移除' : '已添加到收藏')),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }
}
