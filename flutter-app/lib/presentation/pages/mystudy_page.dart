import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

import '../../core/ink/ink.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/user_data.dart';
import '../providers/app_providers.dart';
import '../widgets/t_text.dart';

final _favoritesProvider = StreamProvider<List<FavoriteBook>>(
  (ref) => ref.watch(studyRepositoryProvider).watchFavorites(),
);
final _historyProvider = StreamProvider<List<HistoryItem>>(
  (ref) => ref.watch(studyRepositoryProvider).watchHistory(),
);
final _bookmarksProvider = StreamProvider<List<Bookmark>>(
  (ref) => ref.watch(studyRepositoryProvider).watchBookmarks(),
);
final _notesProvider = StreamProvider<List<Note>>(
  (ref) => ref.watch(studyRepositoryProvider).watchNotes(),
);

/// Book titles resolved from the local catalog (offline).
/// Family key is a comma-joined string — a List key would never compare equal
/// across rebuilds and would recreate the provider on every frame.
final _titlesProvider = FutureProvider.family<Map<String, String>, String>(
  (ref, joinedIds) async {
    final ids = joinedIds.isEmpty ? const <String>[] : joinedIds.split(',');
    final books = await ref.watch(catalogRepositoryProvider).getBooks(ids);
    return {for (final b in books) b.bookId: b.title};
  },
);

/// 我的（web `/mystudy` 的移动端形态）：收藏/历史/书签/笔记 + 离线缓存入口。
/// 列表项左滑删除（flutter_slidable）取代 web 的 hover 删除按钮。
class MyStudyPage extends ConsumerWidget {
  const MyStudyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const TText('我的研习'),
          actions: [
            IconButton(
              tooltip: '离线缓存',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: () => context.push('/downloads'),
              icon: const Icon(Icons.download_done_outlined),
            ),
            IconButton(
              tooltip: '设置',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: () => context.push('/settings'),
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
          bottom: TabBar(
            labelColor: colors.foreground,
            unselectedLabelColor: colors.mutedForeground,
            // 笔触指示器（P3.6）：替代 Material 直线 indicator。
            indicator: BrushTabIndicator(color: context.ink.inkStrong),
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(child: TText('收藏')),
              Tab(child: TText('历史')),
              Tab(child: TText('书签')),
              Tab(child: TText('笔记')),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _FavoritesTab(),
            _HistoryTab(),
            _BookmarksTab(),
            _NotesTab(),
          ],
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TText(
        message,
        style: TextStyle(color: context.colors.mutedForeground),
      ),
    );
  }
}

Widget _deletableTile({
  required BuildContext context,
  required Key key,
  required Widget child,
  required VoidCallback onDelete,
}) {
  final colors = context.colors;
  return Slidable(
    key: key,
    endActionPane: ActionPane(
      motion: const DrawerMotion(),
      extentRatio: 0.25,
      children: [
        CustomSlidableAction(
          onPressed: (_) => onDelete(),
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
    child: child,
  );
}

class _FavoritesTab extends ConsumerWidget {
  const _FavoritesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final favorites = ref.watch(_favoritesProvider).value ?? const [];
    if (favorites.isEmpty) return const _EmptyHint('暂无收藏');
    final titles = ref
            .watch(_titlesProvider(favorites.map((f) => f.bookId).join(',')))
            .value ??
        const {};
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: favorites.length,
      itemBuilder: (context, index) {
        final fav = favorites[index];
        return _deletableTile(
          context: context,
          key: ValueKey('fav-${fav.bookId}'),
          onDelete: () =>
              ref.read(studyRepositoryProvider).removeFavorite(fav.bookId),
          child: ListTile(
            minTileHeight: 56,
            title: TText(
              titles[fav.bookId] ?? fav.bookId,
              style: TextStyle(color: colors.foreground),
            ),
            trailing: Icon(Icons.chevron_right, color: colors.mutedForeground),
            onTap: () => context.push('/book/${fav.bookId}'),
          ),
        );
      },
    );
  }
}

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final history = ref.watch(_historyProvider).value ?? const [];
    if (history.isEmpty) return const _EmptyHint('暂无历史');
    final titles = ref
            .watch(_titlesProvider(history.map((h) => h.bookId).join(',')))
            .value ??
        const {};
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: history.length,
      itemBuilder: (context, index) {
        final item = history[index];
        return ListTile(
          minTileHeight: 56,
          title: TText(
            titles[item.bookId] ?? item.bookId,
            style: TextStyle(color: colors.foreground),
          ),
          subtitle: Text(
            _formatTime(item.visitedAt),
            style: TextStyle(fontSize: 12, color: colors.mutedForeground),
          ),
          trailing: Icon(Icons.chevron_right, color: colors.mutedForeground),
          onTap: () => context.push('/book/${item.bookId}'),
        );
      },
    );
  }
}

class _BookmarksTab extends ConsumerWidget {
  const _BookmarksTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final bookmarks = ref.watch(_bookmarksProvider).value ?? const [];
    if (bookmarks.isEmpty) return const _EmptyHint('暂无书签');
    final titles = ref
            .watch(_titlesProvider(bookmarks.map((b) => b.bookId).join(',')))
            .value ??
        const {};
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: bookmarks.length,
      itemBuilder: (context, index) {
        final bookmark = bookmarks[index];
        // 书签笺纸卡（P3.6）：InkCard 吃墨边缘，长列表关阴影。
        return _deletableTile(
          context: context,
          key: ValueKey('bm-${bookmark.compositeKey}'),
          onDelete: () => ref
              .read(studyRepositoryProvider)
              .removeBookmark(bookmark.compositeKey),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: InkCard(
              seed: 61 + index,
              borderRadius: 12,
              shadow: false,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              onTap: () => context.push(
                '/book/${bookmark.bookId}?index=${bookmark.blockIndex}',
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TText(
                    titles[bookmark.bookId] ?? bookmark.bookId,
                    style: TextStyle(color: colors.foreground),
                  ),
                  const SizedBox(height: 4),
                  TText(
                    '${bookmark.content}…',
                    style: TextStyle(
                        fontSize: 13, color: colors.mutedForeground),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NotesTab extends ConsumerWidget {
  const _NotesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final notes = ref.watch(_notesProvider).value ?? const [];
    if (notes.isEmpty) return const _EmptyHint('暂无笔记');
    final titles = ref
            .watch(_titlesProvider(notes.map((n) => n.bookId).join(',')))
            .value ??
        const {};
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        // 笔记笺纸卡（P3.6）：引文衬左缘墨线，注语为主体。
        return _deletableTile(
          context: context,
          key: ValueKey('note-${note.id}'),
          onDelete: () =>
              ref.read(studyRepositoryProvider).removeNote(note.id),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: InkCard(
              seed: 67 + index,
              borderRadius: 12,
              shadow: false,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              onTap: () => context.push('/book/${note.bookId}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TText(
                    titles[note.bookId] ?? note.bookId,
                    style: TextStyle(
                        fontSize: 14, color: colors.mutedForeground),
                  ),
                  const SizedBox(height: 4),
                  TText(
                    '「${note.quote}」',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13, color: colors.mutedForeground),
                  ),
                  const SizedBox(height: 2),
                  TText(
                    note.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontSize: 15, color: colors.foreground),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

String _formatTime(DateTime time) {
  final now = DateTime.now();
  final diff = now.difference(time);
  if (diff.inMinutes < 1) return '刚刚';
  if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
  if (diff.inDays < 1) return '${diff.inHours} 小时前';
  if (diff.inDays < 30) return '${diff.inDays} 天前';
  return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';
}
