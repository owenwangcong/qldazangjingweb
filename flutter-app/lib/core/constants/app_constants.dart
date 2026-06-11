/// Global constants for the 乾隆大藏经 app.
abstract class AppConstants {
  /// Production origin that serves both the static canon data and the
  /// online-only APIs (search / dictionary / AI).
  // TODO: AI_ASSUMPTION 生产数据源从 Web 项目 sitemap 推断为 qldazangjing.com
  static const String baseUrl = 'https://qldazangjing.com';

  static const String bookDataPath = '/data/books'; // GET {base}{path}/{id}.json
  static const String searchApiPath = '/api/elasticsearch/search';
  static const String dictApiPath = '/api/todict';
  static const String chatGptApiPath = '/api/tochatgpt';

  // Bundled seed assets (copied from the web app's /public/data).
  static const String assetMls = 'assets/data/mls.json';
  static const String assetClassics = 'assets/data/classics.json';
  static const String assetBookMeta = 'assets/data/bookMetaData.json';
  static const String assetS2t = 'assets/opencc/s2t.tsv';
  static const String assetT2s = 'assets/opencc/t2s.tsv';

  /// Same cap as the web app's browser history.
  static const int historyLimit = 50;

  /// Search page size (mirrors the web client).
  static const int searchPageSize = 10;

  static const Duration networkTimeout = Duration(seconds: 20);
}
