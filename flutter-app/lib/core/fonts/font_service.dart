import 'dart:async';

import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 内置阅读字体目录。key 与显示名和 Web 版 Header 的字体选择器 1:1 对齐
/// （web: --font-{key}）；TTF 为全量字体，按需加载。
enum AppFont {
  system('', '系统默认', null),
  aakai('aakai', 'Aa楷体', 'assets/fonts/aaKaiTi.ttf'),
  aakaiSong('aakaiSong', 'Aa楷宋', 'assets/fonts/aaKaiSong.ttf'),
  hyfs('hyfs', '汉仪仿宋', 'assets/fonts/hyFangSong.ttf'),
  lxgw('lxgw', '落霞孤鹜', 'assets/fonts/lxgw.ttf'),
  qnlb('qnlb', '青鸟隶变', 'assets/fonts/qnBianLi.ttf'),
  rzykt('rzykt', '锐字云楷体', 'assets/fonts/rzyKaiTi.ttf'),
  twzk('twzk', '台湾正楷体', 'assets/fonts/twZhengKai.ttf'),
  wqwh('wqwh', '文泉微黑', 'assets/fonts/wqwMiHei.ttf');

  const AppFont(this.key, this.label, this.assetPath);

  /// Settings value; '' = system font (no loading at all).
  final String key;
  final String label;
  final String? assetPath;

  /// Family name registered with the engine (the key itself).
  String? get familyName => this == AppFont.system ? null : key;

  static AppFont fromKey(String? key) => AppFont.values.firstWhere(
        (f) => f.key == key,
        orElse: () => AppFont.system,
      );
}

/// Loads bundled fonts on demand via [FontLoader] — only the font the user
/// actually selects is ever read and parsed, the other TTFs just sit in the
/// APK. Idempotent and concurrency-safe.
class FontService {
  final Set<String> _loaded = {};
  final Map<String, Future<void>> _inFlight = {};

  bool isLoaded(AppFont font) =>
      font == AppFont.system || _loaded.contains(font.key);

  Future<void> ensure(AppFont font) {
    if (isLoaded(font)) return Future.value();
    return _inFlight.putIfAbsent(font.key, () async {
      try {
        final data = await rootBundle.load(font.assetPath!);
        final loader = FontLoader(font.familyName!)
          ..addFont(Future.value(data));
        await loader.load();
        _loaded.add(font.key);
      } finally {
        _inFlight.remove(font.key);
      }
    });
  }
}

class FontState {
  const FontState({
    required this.selected,
    required this.loadedKeys,
    this.loadingKey,
  });

  final AppFont selected;
  final Set<String> loadedKeys;
  final String? loadingKey;

  /// Family to actually render with — null (system) until the selected font
  /// finished loading, so first frames never block on font IO.
  String? get activeFamily =>
      selected != AppFont.system && loadedKeys.contains(selected.key)
          ? selected.familyName
          : null;

  bool isLoaded(AppFont font) =>
      font == AppFont.system || loadedKeys.contains(font.key);

  FontState copyWith({
    AppFont? selected,
    Set<String>? loadedKeys,
    String? Function()? loadingKey,
  }) =>
      FontState(
        selected: selected ?? this.selected,
        loadedKeys: loadedKeys ?? this.loadedKeys,
        loadingKey: loadingKey != null ? loadingKey() : this.loadingKey,
      );
}

class FontController extends StateNotifier<FontState> {
  FontController(this._service, AppFont initial)
      : super(FontState(selected: initial, loadedKeys: const {})) {
    // Fire-and-forget warm-up of the persisted choice: UI renders with the
    // system font immediately and swaps once the font is registered.
    if (initial != AppFont.system) {
      _load(initial).then((_) {
        if (mounted) {
          state = state.copyWith(
            loadedKeys: {...state.loadedKeys, initial.key},
          );
        }
      }).catchError((_) {});
    }
  }

  final FontService _service;

  Future<void> _load(AppFont font) => _service.ensure(font);

  /// Loads (if needed) and selects [font]. Returns when the font is active.
  Future<void> select(AppFont font) async {
    if (font == AppFont.system) {
      state = state.copyWith(selected: font, loadingKey: () => null);
      return;
    }
    state = state.copyWith(loadingKey: () => font.key);
    try {
      await _load(font);
      state = FontState(
        selected: font,
        loadedKeys: {...state.loadedKeys, font.key},
      );
    } catch (_) {
      state = state.copyWith(loadingKey: () => null);
      rethrow;
    }
  }
}
