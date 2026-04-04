class DownloadTaskRecordModel {
  const DownloadTaskRecordModel({
    required this.id,
    required this.taskId,
    required this.title,
    required this.status,
    required this.savePath,
    required this.createdAt,
    required this.updatedAt,
    this.progress = 0,
    this.errorMessage,
    this.fileSize,
  });

  final String id;
  final String taskId;
  final String title;
  final String status;
  final String savePath;
  final double progress;
  final String? errorMessage;
  final int? fileSize;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isDownloading => status == 'downloading';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';

  String get displayTitle {
    final String value = title.trim();
    return value.isEmpty ? '未命名视频' : value;
  }

  DownloadTaskRecordModel copyWith({
    String? id,
    String? taskId,
    String? title,
    String? status,
    String? savePath,
    double? progress,
    String? errorMessage,
    int? fileSize,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearErrorMessage = false,
    bool clearFileSize = false,
  }) {
    return DownloadTaskRecordModel(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      title: title ?? this.title,
      status: status ?? this.status,
      savePath: savePath ?? this.savePath,
      progress: progress ?? this.progress,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      fileSize: clearFileSize ? null : (fileSize ?? this.fileSize),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory DownloadTaskRecordModel.fromJson(Map<String, dynamic> json) {
    return DownloadTaskRecordModel(
      id: (json['id'] ?? '').toString(),
      taskId: (json['taskId'] ?? json['task_id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      status: (json['status'] ?? 'failed').toString(),
      savePath: (json['savePath'] ?? json['save_path'] ?? '').toString(),
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      errorMessage:
          json['errorMessage']?.toString() ?? json['error_message']?.toString(),
      fileSize: (json['fileSize'] as num?)?.toInt() ??
          (json['file_size'] as num?)?.toInt(),
      createdAt: DateTime.tryParse(
            (json['createdAt'] ?? json['created_at'] ?? '').toString(),
          ) ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(
            (json['updatedAt'] ?? json['updated_at'] ?? '').toString(),
          ) ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'taskId': taskId,
      'title': title,
      'status': status,
      'savePath': savePath,
      'progress': progress,
      'errorMessage': errorMessage,
      'fileSize': fileSize,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
