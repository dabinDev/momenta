import 'package:dio/dio.dart';

import '../../app/constants.dart';
import '../../core/errors/app_exception.dart';

class ApiClient {
  ApiClient() : dio = _buildDio(AppConstants.serverBaseUrl);

  final Dio dio;

  Dio createScopedClient(String baseUrl) => _buildDio(baseUrl);

  static Dio _buildDio(String baseUrl) {
    final Dio dio = Dio(_options(baseUrl));
    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException err, ErrorInterceptorHandler handler) {
          handler.next(err.copyWith(error: AppException.fromDioException(err)));
        },
      ),
    );
    return dio;
  }

  static BaseOptions _options(String baseUrl) {
    return BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
    );
  }
}
