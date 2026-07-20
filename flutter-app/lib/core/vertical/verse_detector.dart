import 'punctuation.dart';
import 'vertical_models.dart';

/// 偈颂检测（实施方案 §7，验收 C3）。
///
/// 在**带标点**的 token 序列上按句读边界切句（白文剥标点后无从切句，
/// 故检测发生在剥除之前——见 token_stream.buildTokenStream 的流程）。
/// 句长以**占格 token 数**计——悬浮引号不占格不计数，独立占格的
/// 间隔号等则计入，与分页器的列格算术完全同源。
///
/// 判定从严（漏检无害化：漏检 = 按散文连排，网格仍对齐）：
/// - 全部句子等长，句长 n ∈ [4, 7]（四/五/六/七言）；
/// - 句数 ≥ 4；
/// - 段尾必须以句读收束（有游离残句 = 非偈颂）。
int? detectVerseClauseLen(List<GridToken> tokens) {
  if (tokens.isEmpty) return null;
  final lengths = <int>[];
  var current = 0;
  for (final t in tokens) {
    current++;
    if (_endsClause(t.trailingPunct)) {
      lengths.add(current);
      current = 0;
    }
  }
  if (current != 0) return null;
  if (lengths.length < 4) return null;
  final n = lengths.first;
  if (n < 4 || n > 7) return null;
  if (lengths.any((l) => l != n)) return null;
  return n;
}

/// 悬浮堆中含任一句读边界符即视为句子收束
/// （如「乐。」——句号后跟后引号，仍是句尾）。
bool _endsClause(String trailingPunct) => trailingPunct.runes
    .any((r) => clauseBoundaryPunctuation.contains(String.fromCharCode(r)));
