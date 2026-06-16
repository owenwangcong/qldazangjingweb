import '../constants/app_constants.dart';

/// 段落文本预处理（滚动/翻页两种阅读模式共享，行为以滚动模式
/// `_BlockView._buildParagraph` 为准源——两边必须逐字节一致）。

/// 剥去弯引号（与 web 渲染器对齐）。在简繁转换**之前**调用。
String cleanParagraph(String raw) =>
    raw.replaceAll('“', '').replaceAll('”', '');

final _imgRegex = RegExp('<img[^>]*>');
final _srcRegex = RegExp('src=["\']([^"\']+)["\']');

/// 段落切分结果：text 与 imageUrl 二选一。
class ParagraphSegment {
  const ParagraphSegment.text(String this.text) : imageUrl = null;
  const ParagraphSegment.image(String this.imageUrl) : text = null;

  /// 原始（未简繁转换）文本段；调用方再做 display() 转换——
  /// 转换必须按段做，整段连 <img> 标签一起转换会改坏 URL。
  final String? text;
  final String? imageUrl;
}

/// 把（已剥引号的）段落按 <img> 标签切成文本段与图片段。
/// 无图片时返回单个文本段。空白文本段被丢弃（滚动模式渲染为 shrink）。
List<ParagraphSegment> splitParagraphSegments(String cleaned) {
  if (!cleaned.contains('<img')) {
    return [ParagraphSegment.text(cleaned)];
  }
  final segments = <ParagraphSegment>[];
  var cursor = 0;
  for (final match in _imgRegex.allMatches(cleaned)) {
    if (match.start > cursor) {
      segments.add(ParagraphSegment.text(cleaned.substring(cursor, match.start)));
    }
    final src = _srcRegex.firstMatch(match.group(0)!)?.group(1);
    if (src != null && src.isNotEmpty) {
      segments.add(ParagraphSegment.image(resolveImageUrl(src)));
    }
    cursor = match.end;
  }
  if (cursor < cleaned.length) {
    segments.add(ParagraphSegment.text(cleaned.substring(cursor)));
  }
  return segments;
}

/// 相对路径补全为绝对 URL（与 web 渲染器一致）。
String resolveImageUrl(String src) => src.startsWith('http')
    ? src
    : '${AppConstants.baseUrl}${src.startsWith('/') ? '' : '/'}$src';
