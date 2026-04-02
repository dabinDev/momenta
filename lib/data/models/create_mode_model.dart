class CreateModeModel {
  const CreateModeModel({
    required this.code,
    required this.label,
    required this.title,
    required this.subtitle,
    this.highlights = const <String>[],
    this.defaultPromptTemplateKey,
    this.defaultVideoTemplateKey,
    this.supportsVoiceInput = false,
    this.supportsTextCorrection = false,
    this.supportsPromptGeneration = false,
    this.requiresReferenceLink = false,
    this.requiresImages = false,
    this.supportsReferenceVideo = false,
  });

  final String code;
  final String label;
  final String title;
  final String subtitle;
  final List<String> highlights;
  final String? defaultPromptTemplateKey;
  final String? defaultVideoTemplateKey;
  final bool supportsVoiceInput;
  final bool supportsTextCorrection;
  final bool supportsPromptGeneration;
  final bool requiresReferenceLink;
  final bool requiresImages;
  final bool supportsReferenceVideo;

  factory CreateModeModel.fromJson(Map<String, dynamic> json) {
    return CreateModeModel(
      code: (json['code'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      highlights: _readStringList(json['highlights']),
      defaultPromptTemplateKey: json['default_prompt_template_key']?.toString(),
      defaultVideoTemplateKey: json['default_video_template_key']?.toString(),
      supportsVoiceInput: json['supports_voice_input'] == true ||
          json['supportsVoiceInput'] == true,
      supportsTextCorrection: json['supports_text_correction'] == true ||
          json['supportsTextCorrection'] == true,
      supportsPromptGeneration: json['supports_prompt_generation'] == true ||
          json['supportsPromptGeneration'] == true,
      requiresReferenceLink: json['requires_reference_link'] == true ||
          json['requiresReferenceLink'] == true,
      requiresImages:
          json['requires_images'] == true || json['requiresImages'] == true,
      supportsReferenceVideo: json['supports_reference_video'] == true ||
          json['supportsReferenceVideo'] == true,
    );
  }

  static List<String> _readStringList(dynamic value) {
    if (value is List) {
      return value
          .map((dynamic item) => item.toString().trim())
          .where((String item) => item.isNotEmpty)
          .toList();
    }
    return const <String>[];
  }
}
