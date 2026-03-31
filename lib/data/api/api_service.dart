import 'dart:io';

import 'package:dio/dio.dart';

import '../../app/constants.dart';
import '../../core/services/secure_storage_service.dart';
import '../models/app_config_model.dart';
import '../models/paginated_history_model.dart';
import '../models/uploaded_file_model.dart';
import '../models/video_task_model.dart';
import 'api_client.dart';

class ApiService {
  ApiService(this._apiClient, this._secureStorageService)
      : _authDio =
            _apiClient.createScopedClient(AppConstants.authServerBaseUrl);

  final ApiClient _apiClient;
  final SecureStorageService _secureStorageService;
  final Dio _authDio;

  Dio get _dio => _apiClient.dio;

  Future<Map<String, dynamic>> getConfig() async {
    final Response<dynamic> response = await _authDio.get(
      '/api/config',
      options: await _authOptions(),
    );
    return _readEnvelopeMap(response.data);
  }

  Future<Map<String, dynamic>> saveConfig(AppConfigModel config) async {
    final Response<dynamic> response = await _authDio.post(
      '/api/config',
      data: config.toJson(includeKeys: true),
      options: await _authOptions(),
    );
    return _readEnvelopeMap(response.data);
  }

  Future<List<UploadedFileModel>> uploadImages(List<File> files) async {
    final FormData formData = FormData();
    for (final File file in files) {
      formData.files.add(
        MapEntry<String, MultipartFile>(
          'images',
          await MultipartFile.fromFile(file.path,
              filename: file.uri.pathSegments.last),
        ),
      );
    }
    final Response<dynamic> response = await _dio.post(
      '/api/upload-images',
      data: formData,
      options: Options(contentType: Headers.multipartFormDataContentType),
    );
    final dynamic payload = response.data;
    final List<dynamic> list = payload is Map<String, dynamic>
        ? (payload['images'] as List<dynamic>? ??
            payload['data'] as List<dynamic>? ??
            <dynamic>[])
        : (payload as List<dynamic>? ?? <dynamic>[]);
    return list
        .map((dynamic item) => UploadedFileModel.fromJson(_readMap(item)))
        .toList();
  }

  Future<String> speechToText(File audioFile) async {
    final FormData formData = FormData.fromMap(<String, dynamic>{
      'audio': await MultipartFile.fromFile(audioFile.path,
          filename: audioFile.uri.pathSegments.last),
    });
    final Response<dynamic> response = await _dio.post(
      '/api/speech-to-text',
      data: formData,
      options: Options(contentType: Headers.multipartFormDataContentType),
    );
    final Map<String, dynamic> map = _readMap(response.data);
    return (map['text'] ?? map['result'] ?? map['data'] ?? '').toString();
  }

  Future<String> polishText(String text) async {
    final Response<dynamic> response = await _dio.post(
      '/api/polish-text',
      data: <String, dynamic>{'text': text},
    );
    final Map<String, dynamic> map = _readMap(response.data);
    return (map['text'] ?? map['result'] ?? map['content'] ?? '').toString();
  }

  Future<String> generatePrompt(String text) async {
    final Response<dynamic> response = await _dio.post(
      '/api/generate-prompt',
      data: <String, dynamic>{'text': text},
    );
    final Map<String, dynamic> map = _readMap(response.data);
    return (map['prompt'] ?? map['text'] ?? map['result'] ?? '').toString();
  }

  Future<VideoTaskModel> generateVideo({
    required String prompt,
    required List<String> images,
    required int duration,
  }) async {
    final Response<dynamic> response = await _dio.post(
      '/api/generate-video',
      data: <String, dynamic>{
        'prompt': prompt,
        'images': images,
        'duration': duration,
      },
    );
    return VideoTaskModel.fromJson(_readMap(response.data));
  }

  Future<VideoTaskModel> videoStatus(String id) async {
    final Response<dynamic> response = await _dio.get('/api/video-status/$id');
    return VideoTaskModel.fromJson(_readMap(response.data));
  }

  Future<PaginatedHistoryModel> history({
    required int page,
    required int limit,
  }) async {
    final Response<dynamic> response = await _dio.get(
      '/api/history',
      queryParameters: <String, dynamic>{
        'page': page,
        'limit': limit,
      },
    );
    return PaginatedHistoryModel.fromJson(_readMap(response.data));
  }

  Future<void> deleteHistory(String id) async {
    await _dio.delete('/api/history/$id');
  }

  Future<File> downloadVideo({
    required String url,
    required String savePath,
    ProgressCallback? onReceiveProgress,
  }) async {
    await _dio.download(
      url,
      savePath,
      onReceiveProgress: onReceiveProgress,
      options: Options(responseType: ResponseType.bytes),
    );
    return File(savePath);
  }

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final Response<dynamic> response = await _authDio.post(
      '/api/v1/base/access_token',
      data: <String, dynamic>{
        'username': username,
        'password': password,
      },
    );
    return _readEnvelopeMap(response.data);
  }

  Future<Map<String, dynamic>> currentUserInfo({String? token}) async {
    final Response<dynamic> response = await _authDio.get(
      '/api/v1/base/userinfo',
      options: await _authOptions(token: token),
    );
    return _readEnvelopeMap(response.data);
  }

  Future<void> forgotPassword({
    required String username,
    required String email,
    required String newPassword,
  }) async {
    await _authDio.post(
      '/api/v1/base/forgot_password',
      data: <String, dynamic>{
        'username': username,
        'email': email,
        'new_password': newPassword,
      },
    );
  }

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await _authDio.post(
      '/api/v1/base/change_password',
      data: <String, dynamic>{
        'old_password': oldPassword,
        'new_password': newPassword,
      },
      options: await _authOptions(),
    );
  }

  Future<Map<String, dynamic>> updateCurrentProfile({
    required String email,
    required String alias,
    required String phone,
  }) async {
    final Response<dynamic> response = await _authDio.post(
      '/api/v1/base/update_profile',
      data: <String, dynamic>{
        'email': email,
        'alias': alias,
        'phone': phone,
      },
      options: await _authOptions(),
    );
    return _readEnvelopeMap(response.data);
  }

  Future<Options> _authOptions({String? token}) async {
    final String? storedToken =
        token ?? await _secureStorageService.read('auth_access_token');
    final String? normalizedToken =
        storedToken?.trim().isEmpty == true ? null : storedToken?.trim();
    return Options(
      headers: <String, dynamic>{
        if (normalizedToken != null) 'Authorization': 'Bearer $normalizedToken',
        if (normalizedToken != null) 'token': normalizedToken,
      },
    );
  }

  static Map<String, dynamic> _readEnvelopeMap(dynamic data) {
    final Map<String, dynamic> map = _readMap(data);
    return _readMap(map['data']);
  }

  static Map<String, dynamic> _readMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return data
          .map((dynamic key, dynamic value) => MapEntry(key.toString(), value));
    }
    return <String, dynamic>{'data': data};
  }
}
