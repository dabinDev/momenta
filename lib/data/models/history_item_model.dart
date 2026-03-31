class HistoryItemModel {
  const HistoryItemModel({
    required this.id,
    required this.status,
    this.prompt,
    this.videoUrl,
    this.errorMessage,
    this.duration,
    this.createdAt,
  });

  final String id;
  final String status;
  final String? prompt;
  final String? videoUrl;
  final String? errorMessage;
  final int? duration;
  final DateTime? createdAt;

  bool get isProcessing => status == 'processing';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';

  String get displayTitle {
    final String value = prompt?.trim() ?? '';
    return value.isEmpty ? '未命名视频任务' : value;
  }

  HistoryItemModel copyWith({
    String? id,
    String? status,
    String? prompt,
    String? videoUrl,
    String? errorMessage,
    int? duration,
    DateTime? createdAt,
  }) {
    return HistoryItemModel(
      id: id ?? this.id,
      status: status ?? this.status,
      prompt: prompt ?? this.prompt,
      videoUrl: videoUrl ?? this.videoUrl,
      errorMessage: errorMessage ?? this.errorMessage,
      duration: duration ?? this.duration,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory HistoryItemModel.fromJson(Map<String, dynamic> json) {
    return HistoryItemModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      status: (json['status'] ?? 'processing').toString(),
      prompt: json['prompt']?.toString(),
      videoUrl: json['videoUrl']?.toString() ?? json['video_url']?.toString(),
      errorMessage:
          json['errorMessage']?.toString() ?? json['error']?.toString(),
      duration: int.tryParse((json['duration'] ?? '').toString()),
      createdAt: DateTime.tryParse(
          (json['createdAt'] ?? json['created_at'] ?? '').toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'status': status,
      'prompt': prompt,
      'videoUrl': videoUrl,
      'errorMessage': errorMessage,
      'duration': duration,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}
