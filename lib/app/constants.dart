class AppConstants {
  AppConstants._();

  static const String appTitle = '银龄视频助手';
  static const String appVersion = '1.0.0';
  static const String appBuildNumber = '1';
  static const String updateChannel = '局域网安装包';
  static const String updateHint = '如有新版本，重新安装新的 APK 即可覆盖更新。';
  static const String serverBaseUrl = 'http://1.15.227.223:3000';
  static const String authServerBaseUrl = 'http://192.168.12.197:9999';
  static const String defaultLlmBaseUrl = 'https://api.moonshot.cn/v1';
  static const String defaultLlmModel = 'moonshot-v1-8k';
  static const String defaultLlmApiKeyPlaceholder = 'sk-xxxxxxxxxxxxxxxxxxxxxxxx';
  static const String defaultVideoBaseUrl = 'https://api.openai.com/v1';
  static const String defaultVideoModel = 'video-generation';
  static const int maxImages = 3;
  static const int pollingIntervalSeconds = 2;
  static const int maxPollingTimes = 60;
  static const List<int> durations = <int>[5, 10, 20];
  static const int historyPageSize = 10;
}
