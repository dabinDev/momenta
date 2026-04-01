class AppReleaseModel {
  const AppReleaseModel({
    required this.id,
    required this.platform,
    required this.channel,
    required this.versionName,
    required this.buildNumber,
    required this.title,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.forceUpdate,
    required this.isActive,
    required this.publishedAt,
  });

  final int id;
  final String platform;
  final String channel;
  final String versionName;
  final int buildNumber;
  final String title;
  final String releaseNotes;
  final String downloadUrl;
  final bool forceUpdate;
  final bool isActive;
  final DateTime? publishedAt;

  String get versionLabel => 'V$versionName ($buildNumber)';

  factory AppReleaseModel.fromJson(Map<String, dynamic> json) {
    return AppReleaseModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      platform: (json['platform'] ?? '').toString(),
      channel: (json['channel'] ?? '').toString(),
      versionName: (json['version_name'] ?? '').toString(),
      buildNumber: (json['build_number'] as num?)?.toInt() ??
          int.tryParse('${json['build_number'] ?? 0}') ??
          0,
      title: (json['title'] ?? '').toString(),
      releaseNotes: (json['release_notes'] ?? '').toString(),
      downloadUrl: (json['download_url'] ?? '').toString(),
      forceUpdate: json['force_update'] == true,
      isActive: json['is_active'] == true,
      publishedAt: DateTime.tryParse((json['published_at'] ?? '').toString()),
    );
  }
}

class AppUpdateInfoModel {
  const AppUpdateInfoModel({
    required this.platform,
    required this.channel,
    required this.currentVersion,
    required this.currentBuildNumber,
    required this.hasUpdate,
    required this.isForceUpdate,
    required this.message,
    required this.latest,
  });

  final String platform;
  final String channel;
  final String currentVersion;
  final int currentBuildNumber;
  final bool hasUpdate;
  final bool isForceUpdate;
  final String message;
  final AppReleaseModel? latest;

  bool get hasLatestRelease => latest != null && latest!.versionName.isNotEmpty;

  factory AppUpdateInfoModel.fromJson(Map<String, dynamic> json) {
    final dynamic latestJson = json['latest'];
    return AppUpdateInfoModel(
      platform: (json['platform'] ?? '').toString(),
      channel: (json['channel'] ?? '').toString(),
      currentVersion: (json['current_version'] ?? '').toString(),
      currentBuildNumber: (json['current_build_number'] as num?)?.toInt() ??
          int.tryParse('${json['current_build_number'] ?? 0}') ??
          0,
      hasUpdate: json['has_update'] == true,
      isForceUpdate: json['is_force_update'] == true,
      message: (json['message'] ?? '').toString(),
      latest: latestJson is Map<String, dynamic>
          ? AppReleaseModel.fromJson(latestJson)
          : latestJson is Map
              ? AppReleaseModel.fromJson(
                  latestJson.map(
                    (dynamic key, dynamic value) =>
                        MapEntry(key.toString(), value),
                  ),
                )
              : null,
    );
  }
}
