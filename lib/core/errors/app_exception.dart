import 'package:dio/dio.dart';

class AppException implements Exception {
  const AppException(this.message);

  final String message;

  factory AppException.fromDioException(DioException exception) {
    final dynamic data = exception.response?.data;
    if (data is Map<String, dynamic>) {
      final String? serverMessage = data['msg']?.toString() ??
          data['detail']?.toString() ??
          data['message']?.toString() ??
          data['error']?.toString();
      if (serverMessage != null && serverMessage.isNotEmpty) {
        return AppException(serverMessage);
      }
    }

    switch (exception.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const AppException('网络超时，请检查网络后重试');
      case DioExceptionType.badCertificate:
        return const AppException('证书校验失败，请联系管理员');
      case DioExceptionType.badResponse:
        return AppException('服务异常：${exception.response?.statusCode ?? '未知状态'}');
      case DioExceptionType.cancel:
        return const AppException('请求已取消');
      case DioExceptionType.connectionError:
        return const AppException('无法连接服务器，请确认服务端地址可访问');
      case DioExceptionType.unknown:
        return AppException(exception.message ?? '发生未知错误，请稍后再试');
    }
  }

  @override
  String toString() => message;
}
