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
        return const AppException(
          '\u7f51\u7edc\u8d85\u65f6\uff0c\u8bf7\u68c0\u67e5\u7f51\u7edc\u540e\u91cd\u8bd5',
        );
      case DioExceptionType.badCertificate:
        return const AppException(
          '\u8bc1\u4e66\u6821\u9a8c\u5931\u8d25\uff0c\u8bf7\u8054\u7cfb\u7ba1\u7406\u5458',
        );
      case DioExceptionType.badResponse:
        return AppException(
          '\u670d\u52a1\u5f02\u5e38\uff1a${exception.response?.statusCode ?? '\u672a\u77e5\u72b6\u6001'}',
        );
      case DioExceptionType.cancel:
        return const AppException('\u8bf7\u6c42\u5df2\u53d6\u6d88');
      case DioExceptionType.connectionError:
        return const AppException(
          '\u65e0\u6cd5\u8fde\u63a5\u670d\u52a1\u5668\uff0c\u8bf7\u786e\u8ba4\u670d\u52a1\u7aef\u5730\u5740\u53ef\u8bbf\u95ee',
        );
      case DioExceptionType.unknown:
        return AppException(
          exception.message ??
              '\u53d1\u751f\u672a\u77e5\u9519\u8bef\uff0c\u8bf7\u7a0d\u540e\u518d\u8bd5',
        );
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
    return message.isEmpty ? fallback : message;
  }

  static String _speechMessage(DioException exception) {
    switch (exception.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '\u8bed\u97f3\u8bc6\u522b\u8d85\u65f6\uff0c\u8bf7\u7f29\u77ed\u8bed\u97f3\u540e\u91cd\u8bd5';
      case DioExceptionType.connectionError:
        return '\u65e0\u6cd5\u8fde\u63a5\u8bed\u97f3\u8bc6\u522b\u670d\u52a1\uff0c\u8bf7\u7a0d\u540e\u91cd\u8bd5';
      case DioExceptionType.cancel:
        return '\u5df2\u53d6\u6d88\u8bed\u97f3\u8bc6\u522b';
      case DioExceptionType.badCertificate:
        return '\u8bed\u97f3\u8bc6\u522b\u670d\u52a1\u8bc1\u4e66\u6821\u9a8c\u5931\u8d25\uff0c\u8bf7\u8054\u7cfb\u7ba1\u7406\u5458';
      case DioExceptionType.badResponse:
        final int? statusCode = exception.response?.statusCode;
        final String? serverMessage =
            _readServerMessage(exception.response?.data);
        if (statusCode == 400 &&
            serverMessage != null &&
            serverMessage.isNotEmpty) {
          return serverMessage;
        }
        if (statusCode == 413) {
          return '\u8bed\u97f3\u6d88\u606f\u8fc7\u957f\uff0c\u8bf7\u63a7\u5236\u5728 60 \u79d2\u5185';
        }
        if (statusCode == 415) {
          return '\u8bed\u97f3\u683c\u5f0f\u6682\u4e0d\u652f\u6301\uff0c\u8bf7\u91cd\u65b0\u5f55\u5236\u540e\u91cd\u8bd5';
        }
        if (statusCode == 503) {
          return '\u8bed\u97f3\u8bc6\u522b\u670d\u52a1\u6682\u65f6\u4e0d\u53ef\u7528\uff0c\u8bf7\u7a0d\u540e\u91cd\u8bd5';
        }
        return '\u8bed\u97f3\u8bc6\u522b\u6682\u65f6\u4e0d\u53ef\u7528\uff0c\u8bf7\u7a0d\u540e\u91cd\u8bd5';
      case DioExceptionType.unknown:
        return '\u8bed\u97f3\u8bc6\u522b\u6682\u65f6\u4e0d\u53ef\u7528\uff0c\u8bf7\u7a0d\u540e\u91cd\u8bd5';
    }
  }

  static String? _readServerMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data['msg']?.toString() ??
          data['detail']?.toString() ??
          data['message']?.toString() ??
          data['error']?.toString();
    }
    if (data is Map) {
      return data['msg']?.toString() ??
          data['detail']?.toString() ??
          data['message']?.toString() ??
          data['error']?.toString();
    }
    return null;
  }

  @override
  String toString() => message;
}
