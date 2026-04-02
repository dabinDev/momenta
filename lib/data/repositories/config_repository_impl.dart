import '../../core/services/local_storage_service.dart';
import '../../core/services/secure_storage_service.dart';
import '../../domain/repositories/config_repository.dart';
import '../api/api_service.dart';
import '../models/app_config_model.dart';

class ConfigRepositoryImpl implements ConfigRepository {
  ConfigRepositoryImpl({
    required ApiService apiService,
    required LocalStorageService localStorageService,
    required SecureStorageService secureStorageService,
  })  : _apiService = apiService,
        _localStorageService = localStorageService,
        _secureStorageService = secureStorageService;

  final ApiService _apiService;
  final LocalStorageService _localStorageService;
  final SecureStorageService _secureStorageService;

  static const String _llmBaseUrlKey = 'llm_base_url';
  static const String _llmModelKey = 'llm_model';
  static const String _videoBaseUrlKey = 'video_base_url';
  static const String _videoModelKey = 'video_model';
  static const String _speechBaseUrlKey = 'speech_base_url';
  static const String _speechModelKey = 'speech_model';
  static const String _llmApiKeyKey = 'llm_api_key';
  static const String _videoApiKeyKey = 'video_api_key';
  static const String _speechApiKeyKey = 'speech_api_key';

  @override
  Future<AppConfigModel> loadLocalConfig() async {
    final AppConfigModel defaults = AppConfigModel.defaults();
    final String? llmApiKey = await _secureStorageService.read(_llmApiKeyKey);
    final String? videoApiKey =
        await _secureStorageService.read(_videoApiKeyKey);
    final String? speechApiKey =
        await _secureStorageService.read(_speechApiKeyKey);
    return defaults.copyWith(
      llmBaseUrl: _localStorageService.read<String>(_llmBaseUrlKey),
      llmModel: _localStorageService.read<String>(_llmModelKey),
      videoBaseUrl: _localStorageService.read<String>(_videoBaseUrlKey),
      videoModel: _localStorageService.read<String>(_videoModelKey),
      speechBaseUrl: _localStorageService.read<String>(_speechBaseUrlKey),
      speechModel: _localStorageService.read<String>(_speechModelKey),
      llmApiKey: llmApiKey,
      videoApiKey: videoApiKey,
      speechApiKey: speechApiKey,
    );
  }

  @override
  Future<AppConfigModel> fetchRemoteConfig() async {
    final Map<String, dynamic> json = await _apiService.getConfig();
    final AppConfigModel remote = AppConfigModel.fromJson(json);
    final AppConfigModel merged = remote.copyWith(
      llmApiKey: remote.llmApiKey.isEmpty
          ? await _secureStorageService.read(_llmApiKeyKey)
          : remote.llmApiKey,
      videoApiKey: remote.videoApiKey.isEmpty
          ? await _secureStorageService.read(_videoApiKeyKey)
          : remote.videoApiKey,
      speechApiKey: remote.speechApiKey.isEmpty
          ? await _secureStorageService.read(_speechApiKeyKey)
          : remote.speechApiKey,
    );
    await _persist(merged);
    return merged;
  }

  @override
  Future<AppConfigModel> saveConfig(AppConfigModel config) async {
    final Map<String, dynamic> json = await _apiService.saveConfig(config);
    final AppConfigModel remote = AppConfigModel.fromJson(json);
    final AppConfigModel merged = remote.copyWith(
      llmApiKey: config.llmApiKey,
      videoApiKey: config.videoApiKey,
      speechApiKey: config.speechApiKey,
    );
    await _persist(merged);
    return merged;
  }

  Future<void> _persist(AppConfigModel config) async {
    await _localStorageService.write(_llmBaseUrlKey, config.llmBaseUrl);
    await _localStorageService.write(_llmModelKey, config.llmModel);
    await _localStorageService.write(_videoBaseUrlKey, config.videoBaseUrl);
    await _localStorageService.write(_videoModelKey, config.videoModel);
    await _localStorageService.write(_speechBaseUrlKey, config.speechBaseUrl);
    await _localStorageService.write(_speechModelKey, config.speechModel);
    await _secureStorageService.write(_llmApiKeyKey, config.llmApiKey);
    await _secureStorageService.write(_videoApiKeyKey, config.videoApiKey);
    await _secureStorageService.write(_speechApiKeyKey, config.speechApiKey);
  }
}
