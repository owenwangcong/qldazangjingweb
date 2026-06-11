import '../../core/constants/app_constants.dart';
import '../../domain/entities/book_entities.dart';
import '../../domain/repositories/repositories.dart';
import '../datasources/remote/api_client.dart';

class SearchRepositoryImpl implements SearchRepository {
  SearchRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<FullTextSearchPage> searchFullText({
    required String query,
    required bool phraseMatch,
    required int page,
  }) async {
    final data = await _api.searchFullText(
      query: query,
      originalQuery: query,
      phraseMatch: phraseMatch,
      from: (page - 1) * AppConstants.searchPageSize,
      size: AppConstants.searchPageSize,
    );
    if (data['error'] != null) {
      throw Exception(data['error'].toString());
    }
    final hits = (data['hits'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((hit) {
      final highlights = hit['highlights'] as Map<String, dynamic>?;
      List<String> hl(String field) =>
          (highlights?[field] as List<dynamic>? ?? const [])
              .whereType<String>()
              .toList();
      return SearchHit(
        id: hit['id'] as String? ?? '',
        title: hit['title'] as String? ?? '',
        author: hit['author'] as String? ?? '',
        score: (hit['score'] as num?)?.toDouble(),
        titleHighlight: hl('title').firstOrNull,
        authorHighlight: hl('author').firstOrNull,
        contentHighlights: hl('content'),
      );
    }).toList();
    return FullTextSearchPage(
      total: (data['total'] as num?)?.toInt() ?? hits.length,
      hits: hits,
    );
  }
}

class LexiconRepositoryImpl implements LexiconRepository {
  LexiconRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<List<({String dict, String value})>> lookup(String key) async {
    final entries = await _api.lookupDictionary(key);
    return entries.map((e) => (dict: e.dict, value: e.value)).toList();
  }

  @override
  Future<String> toModernChinese(String text) =>
      _api.askAi(text: text, action: 'tomodernchinese');

  @override
  Future<String> explain(String text) =>
      _api.askAi(text: text, action: 'explain');
}
