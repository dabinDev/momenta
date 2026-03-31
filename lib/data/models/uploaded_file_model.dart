class UploadedFileModel {
  const UploadedFileModel({
    required this.path,
    this.url,
  });

  final String path;
  final String? url;

  factory UploadedFileModel.fromJson(Map<String, dynamic> json) {
    return UploadedFileModel(
      path: (json['path'] ?? json['url'] ?? '').toString(),
      url: json['url']?.toString(),
    );
  }
}
