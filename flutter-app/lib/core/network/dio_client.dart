import 'package:dio/dio.dart';

import '../constants/app_constants.dart';

/// Shared Dio instance pointing at the production origin.
Dio createDio() {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: AppConstants.networkTimeout,
      receiveTimeout: AppConstants.networkTimeout,
      headers: {'Accept': 'application/json'},
      responseType: ResponseType.json,
    ),
  );
  return dio;
}
