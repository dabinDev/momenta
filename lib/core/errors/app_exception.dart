import 'package:dio/dio.dart';

class AppException implements Exception {
  const AppException(this.message);

  final String message;

  factory AppException.fromDioException(DioException exception) {
    final String path = exception.requestOptions.path;
    if (path.contains('/voice/transcribe')) {
      return AppException(_speechMessage(exception));
    }

    final String? serverMessage = _readServerMessage(exception.response?.data);
    if (serverMessage != null && serverMessage.isNotEmpty) {
      return AppException(serverMessage);
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

  static String resolveMessage(Object error, {required String fallback}) {
    if (error is AppException) {
      return error.message;
    }
    if (error is DioException) {
      final Object? innerError = error.error;
      if (innerError is AppException) {
        return innerError.message;
      }
      return AppException.fromDioException(error).message;
    }

    final String message = error.toString().trim();
    if (message.isEmpty || message.startsWith('{') || message.startsWith('[')) {
      return fallback;
    }
    return message;
  }

  static String _speechMessage(DioException exception) {
    switch (exception.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '语音识别超时，请缩短语音后重试';
      case DioExceptionType.connectionError:
        return '无法连接语音识别服务，请稍后重试';
      case DioExceptionType.cancel:
        return '已取消语音识别';
      case DioExceptionType.badCertificate:
        return '语音识别服务证书校验失败，请联系管理员';
      case DioExceptionType.badResponse:
        final int? statusCode = exception.response?.statusCode;
        final String? serverMessage = _readServerMessage(exception.response?.data);
        if (statusCode == 400 && serverMessage != null && serverMessage.isNotEmpty) {
          return serverMessage;
        }
        if (statusCode == 413) {
          return '语音消息过长，请控制在 60 秒内';
        }
        if (statusCode == 415) {
          return '语音格式暂不支持，请重新录制后重试';
        }
        if (statusCode == 503) {
          return '语音识别服务暂时不可用，请稍后重试';
        }
        return '语音识别暂时不可用，请稍后重试';
      case DioExceptionType.unknown:
        return '语音识别暂时不可用，请稍后重试';
    }
  }

  static String? _readServerMessage(dynamic data) {
    final String? raw = _extractMessage(data);
    if (raw == null) {
      return null;
    }

    final String message = raw.trim();
    if (message.isEmpty || message.startsWith('{') || message.startsWith('[')) {
      return null;
    }
    return message;
  }

  static String? _extractMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data['msg']?.toString() ??
          (data['error'] is Map ? data['error']['message']?.toString() : null) ??
          (data['error'] is Map ? data['error']['msg']?.toString() : null) ??
          (data['error'] is Map ? data['error']['detail']?.toString() : null) ??
          data['detail']?.toString() ??
          data['message']?.toString() ??
          data['error']?.toString();
    }
    if (data is Map) {
      return data['msg']?.toString() ??
          (data['error'] is Map ? data['error']['message']?.toString() : null) ??
          (data['error'] is Map ? data['error']['msg']?.toString() : null) ??
          (data['error'] is Map ? data['error']['detail']?.toString() : null) ??
          data['detail']?.toString() ??
          data['message']?.toString() ??
          data['error']?.toString();
    }
    return null;
  }

  @override
  String toString() => message;
}
