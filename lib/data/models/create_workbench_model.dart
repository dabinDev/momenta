import 'ai_template_model.dart';
import 'create_mode_model.dart';

class CreateWorkbenchModel {
  const CreateWorkbenchModel({
    this.defaultModeCode,
    this.durations = const <int>[],
    this.modes = const <CreateModeModel>[],
    this.promptTemplates = const <AiTemplateModel>[],
    this.videoTemplates = const <AiTemplateModel>[],
  });

  final String? defaultModeCode;
  final List<int> durations;
  final List<CreateModeModel> modes;
  final List<AiTemplateModel> promptTemplates;
  final List<AiTemplateModel> videoTemplates;

  factory CreateWorkbenchModel.fromJson(Map<String, dynamic> json) {
    return CreateWorkbenchModel(
      defaultModeCode: json['default_mode']?.toString(),
      durations: _readIntList(json['durations']),
      modes: _readModeList(json['modes']),
      promptTemplates: _readTemplateList(json['prompt_templates']),
      videoTemplates: _readTemplateList(json['video_templates']),
    );
  }

  static List<int> _readIntList(dynamic value) {
    if (value is List) {
      return value
          .map((dynamic item) => int.tryParse(item.toString()))
          .whereType<int>()
          .toList();
    }
    return const <int>[];
  }

  static List<CreateModeModel> _readModeList(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map(
            (Map item) => CreateModeModel.fromJson(
              item.map(
                (dynamic key, dynamic itemValue) =>
                    MapEntry<String, dynamic>(key.toString(), itemValue),
              ),
            ),
          )
          .toList();
    }
    return const <CreateModeModel>[];
  }

  static List<AiTemplateModel> _readTemplateList(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map(
            (Map item) => AiTemplateModel.fromJson(
              item.map(
                (dynamic key, dynamic itemValue) =>
                    MapEntry<String, dynamic>(key.toString(), itemValue),
              ),
            ),
          )
          .toList();
    }
    return const <AiTemplateModel>[];
  }
}
