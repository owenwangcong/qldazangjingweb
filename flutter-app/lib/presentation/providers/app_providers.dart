import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

import '../../core/fonts/font_service.dart';
import '../../core/network/connectivity_service.dart';
import '../../core/network/dio_client.dart';
import '../../core/utils/chinese_converter.dart';
import '../../data/datasources/local/isar_service.dart';
import '../../data/datasources/remote/api_client.dart';
import '../../data/models/app_settings.dart';
import '../../data/repositories/book_repository_impl.dart';
import '../../data/repositories/catalog_repository_impl.dart';
import '../../data/repositories/search_repository_impl.dart';
import '../../data/repositories/study_repository_impl.dart';
import '../../data/sync/outbox.dart';
import '../../data/sync/sync_manager.dart';
import '../../domain/repositories/repositories.dart';

/// Overridden in main() with the eagerly-initialized instances.
final isarServiceProvider =
    Provider<IsarService>((ref) => throw UnimplementedError());
final chineseConverterProvider =
    Provider<ChineseConverter>((ref) => throw UnimplementedError());
final connectivityServiceProvider =
    Provider<ConnectivityService>((ref) => throw UnimplementedError());

final isarProvider = Provider<Isar>((ref) => ref.watch(isarServiceProvider).isar);

final isOnlineProvider = StreamProvider<bool>(
  (ref) => ref.watch(connectivityServiceProvider).onStatusChange,
);

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(createDio()));

final outboxProvider =
    Provider<Outbox>((ref) => Outbox(ref.watch(isarProvider)));

final syncManagerProvider = Provider<SyncManager>((ref) {
  final manager = SyncManager(
    isar: ref.watch(isarProvider),
    outbox: ref.watch(outboxProvider),
    api: ref.watch(apiClientProvider),
    connectivity: ref.watch(connectivityServiceProvider),
  );
  ref.onDispose(manager.stop);
  return manager;
});

// ---- Repositories ----------------------------------------------------------

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => CatalogRepositoryImpl(ref.watch(isarProvider)),
);

final bookRepositoryProvider = Provider<BookRepository>(
  (ref) => BookRepositoryImpl(
    isar: ref.watch(isarProvider),
    api: ref.watch(apiClientProvider),
    outbox: ref.watch(outboxProvider),
    syncManager: ref.watch(syncManagerProvider),
    connectivity: ref.watch(connectivityServiceProvider),
  ),
);

final studyRepositoryProvider = Provider<StudyRepository>(
  (ref) => StudyRepositoryImpl(ref.watch(isarProvider)),
);

final searchRepositoryProvider = Provider<SearchRepository>(
  (ref) => SearchRepositoryImpl(ref.watch(apiClientProvider)),
);

final lexiconRepositoryProvider = Provider<LexiconRepository>(
  (ref) => LexiconRepositoryImpl(ref.watch(apiClientProvider)),
);

// ---- Settings (theme / language / reading prefs) ---------------------------

class SettingsController extends StateNotifier<AppSettings> {
  SettingsController(this._isar, AppSettings initial) : super(initial);

  final Isar _isar;

  Future<void> _persist(AppSettings next) async {
    state = next;
    await _isar.writeTxn(() => _isar.appSettings.put(next));
  }

  AppSettings _copy() => AppSettings()
    ..themeKey = state.themeKey
    ..isSimplified = state.isSimplified
    ..fontSize = state.fontSize
    ..lineHeight = state.lineHeight
    ..letterSpacingEm = state.letterSpacingEm
    ..paragraphSpacing = state.paragraphSpacing
    ..fontFamily = state.fontFamily
    ..readingMode = state.readingMode
    ..hasSeenReaderTips = state.hasSeenReaderTips
    ..classicsActiveTab = state.classicsActiveTab
    ..classicsVisible = state.classicsVisible;

  Future<void> setTheme(String key) => _persist(_copy()..themeKey = key);
  Future<void> setFontFamily(String key) =>
      _persist(_copy()..fontFamily = key);
  Future<void> toggleLanguage() =>
      _persist(_copy()..isSimplified = !state.isSimplified);
  Future<void> setFontSize(double v) => _persist(_copy()..fontSize = v);
  Future<void> setLineHeight(double v) => _persist(_copy()..lineHeight = v);
  Future<void> setLetterSpacing(double v) =>
      _persist(_copy()..letterSpacingEm = v);
  Future<void> setParagraphSpacing(double v) =>
      _persist(_copy()..paragraphSpacing = v);
  Future<void> setReadingMode(String v) =>
      _persist(_copy()..readingMode = v);
  Future<void> markReaderTipsSeen() =>
      _persist(_copy()..hasSeenReaderTips = true);
  Future<void> setClassicsTab(String tab) =>
      _persist(_copy()..classicsActiveTab = tab);
  Future<void> setClassicsVisible(bool visible) =>
      _persist(_copy()..classicsVisible = visible);
}

final settingsProvider =
    StateNotifierProvider<SettingsController, AppSettings>((ref) {
  final isar = ref.watch(isarProvider);
  final initial = isar.appSettings.getSync(0) ?? AppSettings();
  return SettingsController(isar, initial);
});

// ---- Fonts (on-demand FontLoader, only the chosen font is ever loaded) -----

final fontServiceProvider = Provider<FontService>((ref) => FontService());

final fontControllerProvider =
    StateNotifierProvider<FontController, FontState>((ref) {
  final initial = AppFont.fromKey(ref.read(settingsProvider).fontFamily);
  return FontController(ref.watch(fontServiceProvider), initial);
});

/// Converts text for display according to the current 简/繁 setting.
final displayTextProvider = Provider<String Function(String)>((ref) {
  final simplified =
      ref.watch(settingsProvider.select((s) => s.isSimplified));
  final converter = ref.watch(chineseConverterProvider);
  return (text) => converter.display(text, simplified: simplified);
});
