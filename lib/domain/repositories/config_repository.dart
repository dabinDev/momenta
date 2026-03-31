import '../../data/models/app_config_model.dart';

abstract class ConfigRepository {
  Future<AppConfigModel> loadLocalConfig();
  Future<AppConfigModel> fetchRemoteConfig();
  Future<AppConfigModel> saveConfig(AppConfigModel config);
}
