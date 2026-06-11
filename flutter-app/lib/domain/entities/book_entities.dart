/// Strongly-typed domain entities parsed from the canon's JSON payloads.
library;

class BookMeta {
  const BookMeta({
    required this.id,
    required this.bu,
    required this.title,
    required this.author,
    this.lastBuId,
    this.lastBuName,
    this.nextBuId,
    this.nextBuName,
  });

  final String id;
  final String bu;
  final String title;

  /// Source JSON spells this "Arthur".
  final String author;
  final String? lastBuId;
  final String? lastBuName;
  final String? nextBuId;
  final String? nextBuName;

  factory BookMeta.fromJson(Map<String, dynamic> json) {
    final last = json['last_bu'] as Map<String, dynamic>?;
    final next = json['next_bu'] as Map<String, dynamic>?;
    return BookMeta(
      id: json['id'] as String? ?? '',
      bu: json['Bu'] as String? ?? '',
      title: json['title'] as String? ?? '',
      author: json['Arthur'] as String? ?? '',
      lastBuId: last?['id'] as String?,
      lastBuName: last?['name'] as String?,
      nextBuId: next?['id'] as String?,
      nextBuName: next?['name'] as String?,
    );
  }
}

/// bt = 卷标题, bm = 品名, p = 正文段落组.
enum JuanBlockType { bt, bm, p }

class JuanBlock {
  const JuanBlock({
    required this.id,
    required this.type,
    required this.paragraphs,
  });

  final String id;
  final JuanBlockType type;
  final List<String> paragraphs;

  static JuanBlock? fromJson(Map<String, dynamic> json) {
    final type = switch (json['type'] as String?) {
      'bt' => JuanBlockType.bt,
      'bm' => JuanBlockType.bm,
      'p' => JuanBlockType.p,
      _ => null,
    };
    if (type == null) return null;
    final content = (json['content'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList();
    return JuanBlock(
      id: json['id'] as String? ?? '',
      type: type,
      paragraphs: content,
    );
  }
}

class BookData {
  const BookData({required this.meta, required this.blocks});

  final BookMeta meta;
  final List<JuanBlock> blocks;
}

class SearchHit {
  const SearchHit({
    required this.id,
    required this.title,
    required this.author,
    this.score,
    this.titleHighlight,
    this.authorHighlight,
    this.contentHighlights = const [],
  });

  final String id;
  final String title;
  final String author;
  final double? score;
  final String? titleHighlight;
  final String? authorHighlight;
  final List<String> contentHighlights;
}

class FullTextSearchPage {
  const FullTextSearchPage({required this.total, required this.hits});

  final int total;
  final List<SearchHit> hits;
}
