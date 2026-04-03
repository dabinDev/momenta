import 'dart:io';

import 'package:dio/dio.dart';

import '../../app/constants.dart';
import '../../core/errors/app_exception.dart';
import '../../core/services/secure_storage_service.dart';
import '../models/app_config_model.dart';
import '../models/app_update_info_model.dart';
import '../models/ai_template_model.dart';
import '../models/create_workbench_model.dart';
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
    final Options authOptions = await _authOptions();
    final FormData formData = FormData();
    for (final File file in files) {
      formData.files.add(
        MapEntry<String, MultipartFile>(
          'images',
          await MultipartFile.fromFile(
            file.path,
            filename: file.uri.pathSegments.last,
          ),
        ),
      );
    }
    final Response<dynamic> response = await _dio.post(
      '/api/upload-images',
      data: formData,
      options: authOptions.copyWith(
        contentType: Headers.multipartFormDataContentType,
      ),
    );
    final dynamic payload = _unwrapEnvelopeData(response.data);
    final List<dynamic> list = payload is Map<String, dynamic>
        ? (payload['images'] as List<dynamic>? ??
            payload['data'] as List<dynamic>? ??
            <dynamic>[])
        : (payload as List<dynamic>? ?? <dynamic>[]);
    return list
        .map((dynamic item) => UploadedFileModel.fromJson(_readMap(item)))
        .toList();
  }

  Future<UploadedFileModel> uploadReferenceVideo(File file) async {
    final Options authOptions = await _authOptions();
    final FormData formData = FormData.fromMap(<String, dynamic>{
      'video': await MultipartFile.fromFile(
        file.path,
        filename: file.uri.pathSegments.last,
      ),
    });
    final Response<dynamic> response = await _dio.post(
      '/api/upload-reference-video',
      data: formData,
      options: authOptions.copyWith(
        contentType: Headers.multipartFormDataContentType,
      ),
    );
    return UploadedFileModel.fromJson(_readEnvelopeMap(response.data));
  }

  Future<String> speechToText(File audioFile) async {
    final Options authOptions = await _authOptions();
    final FormData formData = FormData.fromMap(<String, dynamic>{
      'audio': await MultipartFile.fromFile(
        audioFile.path,
        filename: audioFile.uri.pathSegments.last,
      ),
    });
    try {
      final Response<dynamic> response = await _authDio.post(
        '/api/voice/transcribe',
        data: formData,
        options: authOptions.copyWith(
          contentType: Headers.multipartFormDataContentType,
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 90),
        ),
      );
      final Map<String, dynamic> map = _readEnvelopeMap(response.data);
      return (map['text'] ?? map['result'] ?? '').toString();
    } on DioException catch (error) {
      throw AppException.fromDioException(error);
    }
  }

  Future<String> correctText(String text) async {
    final Response<dynamic> response = await _dio.post(
      '/api/correct-text',
      data: <String, dynamic>{'text': text},
      options: await _authOptions(),
    );
    final Map<String, dynamic> map = _readEnvelopeMap(response.data);
    return (map['text'] ?? map['result'] ?? map['content'] ?? '').toString();
  }

  Future<List<AiTemplateModel>> fetchPromptTemplates() async {
    final Response<dynamic> response = await _dio.get(
      '/api/prompt-templates',
      options: await _authOptions(),
    );
    final Map<String, dynamic> map = _readEnvelopeMap(response.data);
    final List<dynamic> items = map['items'] as List<dynamic>? ?? <dynamic>[];
    return items
        .map((dynamic item) => AiTemplateModel.fromJson(_readMap(item)))
        .toList();
  }

  Future<List<AiTemplateModel>> fetchVideoTemplates() async {
    final Response<dynamic> response = await _dio.get(
      '/api/video-templates',
      options: await _authOptions(),
    );
    final Map<String, dynamic> map = _readEnvelopeMap(response.data);
    final List<dynamic> items = map['items'] as List<dynamic>? ?? <dynamic>[];
    return items
        .map((dynamic item) => AiTemplateModel.fromJson(_readMap(item)))
        .toList();
  }

  Future<CreateWorkbenchModel> fetchCreateWorkbench() async {
    final Response<dynamic> response = await _dio.get(
      '/api/create-workbench',
      options: await _authOptions(),
    );
    return CreateWorkbenchModel.fromJson(_readEnvelopeMap(response.data));
  }

  Future<String> generatePrompt(String text,
      {String? promptTemplateKey}) async {
    final Response<dynamic> response = await _dio.post(
      '/api/generate-prompt',
      data: <String, dynamic>{
        'text': text,
        if (promptTemplateKey != null) 'prompt_template_key': promptTemplateKey,
      },
      options: await _authOptions(),
    );
    final Map<String, dynamic> map = _readEnvelopeMap(response.data);
    return (map['prompt'] ?? map['text'] ?? map['result'] ?? '').toString();
  }

  Future<VideoTaskModel> generateSimpleVideo({
    String? inputText,
    String? polishedText,
    required String prompt,
    required List<String> images,
    required int duration,
    String? promptTemplateKey,
    String? videoTemplateKey,
  }) {
    return _postVideoTask(
      path: '/api/tasks',
      data: <String, dynamic>{
        if (inputText != null) 'input_text': inputText,
        if (polishedText != null) 'polished_text': polishedText,
        'prompt': prompt,
        'images': images,
        'duration': duration,
        if (promptTemplateKey != null) 'prompt_template_key': promptTemplateKey,
        if (videoTemplateKey != null) 'video_template_key': videoTemplateKey,
      },
    );
  }

  Future<VideoTaskModel> generateStarterVideo({
    String? inputText,
    String? prompt,
    required List<String> images,
    required int duration,
    required String referenceLink,
    String? promptTemplateKey,
    String? videoTemplateKey,
    String? supplementalText,
  }) {
    return _postVideoTask(
      path: '/api/starter-tasks',
      data: <String, dynamic>{
        if (inputText != null) 'input_text': inputText,
        if (prompt != null) 'prompt': prompt,
        'images': images,
        'duration': duration,
        'reference_link': referenceLink,
        if (promptTemplateKey != null) 'prompt_template_key': promptTemplateKey,
        if (videoTemplateKey != null) 'video_template_key': videoTemplateKey,
        if (supplementalText != null) 'supplemental_text': supplementalText,
      },
    );
  }

  Future<VideoTaskModel> generateCustomVideo({
    String? inputText,
    String? prompt,
    required List<String> images,
    required int duration,
    required String videoTemplateKey,
    String? promptTemplateKey,
    String? referenceLink,
    String? referenceVideoPath,
    String? supplementalText,
  }) {
    return _postVideoTask(
      path: '/api/custom-tasks',
      data: <String, dynamic>{
        if (inputText != null) 'input_text': inputText,
        if (prompt != null) 'prompt': prompt,
        'images': images,
        'duration': duration,
        'video_template_key': videoTemplateKey,
        if (promptTemplateKey != null) 'prompt_template_key': promptTemplateKey,
        if (referenceLink != null) 'reference_link': referenceLink,
        if (referenceVideoPath != null)
          'reference_video_path': referenceVideoPath,
        if (supplementalText != null) 'supplemental_text': supplementalText,
      },
    );
  }

  Future<VideoTaskModel> videoStatus(String id) async {
    final Response<dynamic> response = await _dio.get(
      '/api/tasks/$id',
      options: await _authOptions(),
    );
    return VideoTaskModel.fromJson(_readEnvelopeMap(response.data));
  }

  Future<PaginatedHistoryModel> history({
    required int page,
    required int limit,
    String filter = 'all',
  }) async {
    final Response<dynamic> response = await _dio.get(
      '/api/tasks',
      queryParameters: <String, dynamic>{
        'page': page,
        'limit': limit,
        'filter': filter,
      },
      options: await _authOptions(),
    );
    return PaginatedHistoryModel.fromJson(_readEnvelopeMap(response.data));
  }

  Future<Map<String, int>> historySummary() async {
    final Response<dynamic> response = await _dio.get(
      '/api/tasks/summary',
      options: await _authOptions(),
    );
    final Map<String, dynamic> data = _readEnvelopeMap(response.data);
    return <String, int>{
      'total': int.tryParse('${data['total'] ?? 0}') ?? 0,
      'completed': int.tryParse('${data['completed'] ?? 0}') ?? 0,
      'processing': int.tryParse('${data['processing'] ?? 0}') ?? 0,
      'failed': int.tryParse('${data['failed'] ?? 0}') ?? 0,
    };
  }

  Future<void> deleteHistory(String id) async {
    await _dio.delete(
      '/api/tasks/$id',
      options: await _authOptions(),
    );
  }

  Future<void> clearHistory() async {
    await _dio.delete(
      '/api/tasks',
      options: await _authOptions(),
    );
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

  Future<AppUpdateInfoModel> checkAppUpdate() async {
    final Response<dynamic> response = await _authDio.get(
      '/api/app/releases/latest',
      queryParameters: <String, dynamic>{
        'platform': AppConstants.releasePlatform,
        'channel': AppConstants.releaseChannelCode,
        'current_version': AppConstants.appVersion,
        'current_build_number': AppConstants.appBuildNumber,
      },
    );
    return AppUpdateInfoModel.fromJson(_readEnvelopeMap(response.data));
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

  static dynamic _unwrapEnvelopeData(dynamic data) {
    if (data is Map<String, dynamic> && data.containsKey('data')) {
      return data['data'];
    }
    if (data is Map && data.containsKey('data')) {
      return data['data'];
    }
    return data;
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

  Future<VideoTaskModel> _postVideoTask({
    required String path,
    required Map<String, dynamic> data,
  }) async {
    final Response<dynamic> response = await _dio.post(
      path,
      data: data,
      options: await _authOptions(),
    );
    return VideoTaskModel.fromJson(_readEnvelopeMap(response.data));
  }
}
