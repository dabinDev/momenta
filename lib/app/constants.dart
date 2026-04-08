class AppConstants {
  AppConstants._();

  static const String appTitle = '拾光视频';
  static const String appVersion = '1.3.2';
  static const String appBuildNumber = '6';
  static const String releasePlatform = 'android';
  static const String releaseChannelCode = 'lan';
  static const String updateChannel = '局域网安装包';
  static const String updateHint = '如有新版本，重新安装新的 APK 即可覆盖更新。';
  static const String authServerBaseUrl = String.fromEnvironment(
    'AUTH_SERVER_BASE_URL',
    defaultValue: 'https://api.cylonai.cn',
  );
  static const String serverBaseUrl = authServerBaseUrl;
  static const String legacyServerBaseUrl = '';
  static const int maxImages = 3;
  static const int pollingIntervalSeconds = 3;
  static const int maxPollingTimes = 180;
  static const List<int> durations = <int>[5, 10, 20];
  static const int historyPageSize = 10;
  static const int maxSpeechSeconds = 60;
  static const int speechSampleRate = 16000;
}
