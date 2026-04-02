class AppConstants {
  AppConstants._();

  static const String appTitle = '拾光视频';
  static const String appVersion = '1.0.0';
  static const String appBuildNumber = '1';
  static const String releasePlatform = 'android';
  static const String releaseChannelCode = 'lan';
  static const String updateChannel = '局域网安装包';
  static const String updateHint = '如有新版本，重新安装新的 APK 即可覆盖更新。';
  static const String authServerBaseUrl = 'http://192.168.101.21:9999';
  static const String serverBaseUrl = authServerBaseUrl;
  static const String legacyServerBaseUrl = 'http://1.15.227.223:3000';
  static const String defaultLlmBaseUrl = 'https://api.99hub.top';
  static const String defaultLlmModel = 'gpt-5.4-mini';
  static const String defaultLlmApiKeyPlaceholder =
      'sk-xxxxxxxxxxxxxxxxxxxxxxxx';
  static const String defaultVideoBaseUrl = 'https://api.99hub.top';
  static const String defaultVideoModel = 'veo_3_1-fast-components-4K';
  static const String defaultSpeechBaseUrl = 'https://api.99hub.top';
  static const String defaultSpeechModel = 'gpt-4o-mini-audio-preview';
  static const int maxImages = 3;
  static const int pollingIntervalSeconds = 2;
  static const int maxPollingTimes = 60;
  static const List<int> durations = <int>[5, 10, 20];
  static const int historyPageSize = 10;
  static const int maxSpeechSeconds = 60;
  static const int speechSampleRate = 16000;
}
