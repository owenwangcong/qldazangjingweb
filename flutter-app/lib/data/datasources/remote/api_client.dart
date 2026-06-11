import 'package:dio/dio.dart';

import '../../../core/constants/app_constants.dart';

/// Strongly-typed gateway to qldazangjing.com.
/// Only the local database talks to this — never the UI directly.
class ApiClient {
  ApiClient(this._dio);

  final Dio _dio;

  /// GET /data/books/{id}.json — one volume's full text.
  Future<Map<String, dynamic>> fetchBook(String bookId) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '${AppConstants.bookDataPath}/$bookId.json',
    );
    final data = res.data;
    if (data == null) {
      throw DioException(
        requestOptions: res.requestOptions,
        message: 'Empty book payload for $bookId',
      );
    }
    return data;
  }

  /// POST /api/elasticsearch/search — full-text search (online only).
  Future<Map<String, dynamic>> searchFullText({
    required String query,
    required String originalQuery,
    required bool phraseMatch,
    required int from,
    required int size,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      AppConstants.searchApiPath,
      data: {
        'query': query,
        'originalQuery': originalQuery,
        'mode': phraseMatch ? 'phrase' : 'smart',
        'fields': ['title', 'author', 'content'],
        'from': from,
        'size': size,
        'highlight': true,
      },
    );
    return res.data ?? const {};
  }

  /// POST /api/todict — dictionary lookup (online only).
  Future<List<DictEntry>> lookupDictionary(String key) async {
    final res = await _dio.post<Map<String, dynamic>>(
      AppConstants.dictApiPath,
      data: {'key': key},
    );
    final results = res.data?['results'] as List<dynamic>? ?? const [];
    return results
        .whereType<Map<String, dynamic>>()
        .map(DictEntry.fromJson)
        .toList();
  }

  /// POST /api/tochatgpt — AI 今译/释义 (online only).
  /// [action] is `tomodernchinese` or `explain`, mirroring the web client.
  Future<String> askAi({required String text, required String action}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      AppConstants.chatGptApiPath,
      data: {'text': text, 'action': action},
    );
    final openai = res.data?['openai_response'] as Map<String, dynamic>?;
    final errorMessage =
        (openai?['error'] as Map<String, dynamic>?)?['message'];
    if (errorMessage != null) {
      throw Exception('大语言模型接口出现了一个问题。请稍后再试');
    }
    final choices = openai?['choices'] as List<dynamic>?;
    final content = ((choices?.firstOrNull as Map<String, dynamic>?)?['message']
        as Map<String, dynamic>?)?['content'] as String?;
    if (content == null || content.isEmpty) {
      throw Exception('AI 未返回内容');
    }
    var result = '**以下内容由AI生成, 仅供参考**\n\n$content';
    final usage = openai?['usage'] as Map<String, dynamic>?;
    if ((usage?['completion_tokens'] as num? ?? 0) >= 1024) {
      result += '\n\n\n\n**注意：由于查询内容较长，部分信息可能未显示。请适当减少查询字数。**';
    }
    return result;
  }
}

class DictEntry {
  const DictEntry({required this.dict, required this.value});

  final String dict;
  final String value;

  static DictEntry fromJson(Map<String, dynamic> json) => DictEntry(
        dict: json['dict'] as String? ?? '',
        value: json['value'] as String? ?? '',
      );
}
