import 'package:flutter/services.dart' show rootBundle;

import '../constants/app_constants.dart';

/// Pure-Dart simplified/traditional Chinese converter.
///
/// Replaces opencc-js from the web app. Dictionaries are extracted from the
/// same OpenCC data (STPhrases/STCharacters and TSPhrases/TSCharacters) into
/// TSV assets, and conversion uses greedy longest-prefix matching like OpenCC.
class ChineseConverter {
  ChineseConverter._(this._s2t, this._t2s, this._s2tMaxLen, this._t2sMaxLen);

  final Map<String, String> _s2t;
  final Map<String, String> _t2s;
  final int _s2tMaxLen;
  final int _t2sMaxLen;

  static Future<ChineseConverter> load() async {
    final s2t = _parseTsv(await rootBundle.loadString(AppConstants.assetS2t));
    final t2s = _parseTsv(await rootBundle.loadString(AppConstants.assetT2s));
    return ChineseConverter._(
      s2t.$1,
      t2s.$1,
      s2t.$2,
      t2s.$2,
    );
  }

  static (Map<String, String>, int) _parseTsv(String content) {
    final map = <String, String>{};
    var maxLen = 1;
    for (final line in content.split('\n')) {
      if (line.isEmpty) continue;
      final tab = line.indexOf('\t');
      if (tab <= 0) continue;
      final from = line.substring(0, tab);
      final to = line.substring(tab + 1).trimRight();
      map[from] = to;
      if (from.length > maxLen) maxLen = from.length;
    }
    return (map, maxLen);
  }

  String toTraditional(String text) => _convert(text, _s2t, _s2tMaxLen);

  String toSimplified(String text) => _convert(text, _t2s, _t2sMaxLen);

  /// Mirrors the web app's `convertText`: when displaying simplified the
  /// source text (already simplified) passes through a t→s normalization;
  /// when displaying traditional it converts s→t.
  String display(String text, {required bool simplified}) =>
      simplified ? text : toTraditional(text);

  /// Normalizes user input (possibly traditional) to simplified for search,
  /// matching the web client's OpenCC tw→cn step.
  String normalizeQuery(String text) => toSimplified(text);

  String _convert(String text, Map<String, String> dict, int maxLen) {
    if (text.isEmpty || dict.isEmpty) return text;
    final sb = StringBuffer();
    var i = 0;
    while (i < text.length) {
      String? replacement;
      var matchedLen = 0;
      final limit =
          maxLen < (text.length - i) ? maxLen : (text.length - i);
      for (var len = limit; len >= 1; len--) {
        final candidate = text.substring(i, i + len);
        final hit = dict[candidate];
        if (hit != null) {
          replacement = hit;
          matchedLen = len;
          break;
        }
      }
      if (replacement != null) {
        sb.write(replacement);
        i += matchedLen;
      } else {
        sb.write(text[i]);
        i++;
      }
    }
    return sb.toString();
  }
}
