class AiTemplateModel {
  const AiTemplateModel({
    required this.key,
    required this.name,
    required this.description,
    this.preview,
    this.isDefault = false,
    this.defaultDuration,
    this.size,
    this.previewVideoUrl,
    this.tags = const <String>[],
    this.popularity,
    this.supportsReferenceLink = false,
    this.supportsReferenceVideo = false,
    this.supportsReferenceImage = true,
  });

  final String key;
  final String name;
  final String description;
  final String? preview;
  final bool isDefault;
  final int? defaultDuration;
  final String? size;
  final String? previewVideoUrl;
  final List<String> tags;
  final int? popularity;
  final bool supportsReferenceLink;
  final bool supportsReferenceVideo;
  final bool supportsReferenceImage;

  factory AiTemplateModel.fromJson(Map<String, dynamic> json) {
    return AiTemplateModel(
      key: (json['key'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      preview: json['preview']?.toString(),
      isDefault: json['is_default'] == true || json['isDefault'] == true,
      defaultDuration: _asInt(json['default_duration'] ?? json['defaultDuration']),
      size: json['size']?.toString(),
      previewVideoUrl:
          json['preview_video_url']?.toString() ?? json['previewVideoUrl']?.toString(),
      tags: _readStringList(json['tags']),
      popularity: _asInt(json['popularity']),
      supportsReferenceLink: json['supports_reference_link'] == true ||
          json['supportsReferenceLink'] == true,
      supportsReferenceVideo: json['supports_reference_video'] == true ||
          json['supportsReferenceVideo'] == true,
      supportsReferenceImage: json['supports_reference_image'] != false &&
          json['supportsReferenceImage'] != false,
    );
  }

  static int? _asInt(dynamic value) {
    if (value == null) {
      return null;
    }
    return int.tryParse(value.toString());
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
