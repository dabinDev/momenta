import '../../app/constants.dart';

class AppConfigModel {
  const AppConfigModel({
    required this.llmBaseUrl,
    required this.llmApiKey,
    required this.llmModel,
    required this.videoBaseUrl,
    required this.videoApiKey,
    required this.videoModel,
  });

  final String llmBaseUrl;
  final String llmApiKey;
  final String llmModel;
  final String videoBaseUrl;
  final String videoApiKey;
  final String videoModel;

  factory AppConfigModel.defaults() {
    return const AppConfigModel(
      llmBaseUrl: AppConstants.defaultLlmBaseUrl,
      llmApiKey: '',
      llmModel: AppConstants.defaultLlmModel,
      videoBaseUrl: AppConstants.defaultVideoBaseUrl,
      videoApiKey: '',
      videoModel: AppConstants.defaultVideoModel,
    );
  }

  factory AppConfigModel.fromJson(Map<String, dynamic> json) {
    return AppConfigModel(
      llmBaseUrl: (json['llmBaseUrl'] ??
              json['llm_base_url'] ??
              AppConstants.defaultLlmBaseUrl)
          .toString(),
      llmApiKey: (json['llmApiKey'] ?? json['llm_api_key'] ?? '').toString(),
      llmModel: (json['llmModel'] ??
              json['llm_model'] ??
              AppConstants.defaultLlmModel)
          .toString(),
      videoBaseUrl: (json['videoBaseUrl'] ??
              json['video_base_url'] ??
              AppConstants.defaultVideoBaseUrl)
          .toString(),
      videoApiKey:
          (json['videoApiKey'] ?? json['video_api_key'] ?? '').toString(),
      videoModel: (json['videoModel'] ??
              json['video_model'] ??
              AppConstants.defaultVideoModel)
          .toString(),
    );
  }

  Map<String, dynamic> toJson({bool includeKeys = false}) {
    return <String, dynamic>{
      'llmBaseUrl': llmBaseUrl,
      'llmModel': llmModel,
      'videoBaseUrl': videoBaseUrl,
      'videoModel': videoModel,
      if (includeKeys) 'llmApiKey': llmApiKey,
      if (includeKeys) 'videoApiKey': videoApiKey,
    };
  }

  AppConfigModel copyWith({
    String? llmBaseUrl,
    String? llmApiKey,
    String? llmModel,
    String? videoBaseUrl,
    String? videoApiKey,
    String? videoModel,
  }) {
    return AppConfigModel(
      llmBaseUrl: llmBaseUrl ?? this.llmBaseUrl,
      llmApiKey: llmApiKey ?? this.llmApiKey,
      llmModel: llmModel ?? this.llmModel,
      videoBaseUrl: videoBaseUrl ?? this.videoBaseUrl,
      videoApiKey: videoApiKey ?? this.videoApiKey,
      videoModel: videoModel ?? this.videoModel,
    );
  }
}
