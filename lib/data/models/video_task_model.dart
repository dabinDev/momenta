class VideoTaskModel {
  const VideoTaskModel({
    required this.id,
    required this.status,
    this.prompt,
    this.displayText,
    this.videoUrl,
    this.progress,
    this.errorMessage,
    this.duration,
    this.pointsCost = 0,
    this.pointsRefunded = false,
  });

  final String id;
  final String status;
  final String? prompt;
  final String? displayText;
  final String? videoUrl;
  final double? progress;
  final String? errorMessage;
  final int? duration;
  final int pointsCost;
  final bool pointsRefunded;

  bool get isProcessing => status == 'queued' || status == 'processing';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
  String? get pointsStatusLabel {
    if (pointsCost <= 0) {
      return null;
    }
    return pointsRefunded ? '已退回 $pointsCost 积分' : '已扣 $pointsCost 积分';
  }

  factory VideoTaskModel.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    return VideoTaskModel(
      id: (data['id'] ?? data['_id'] ?? data['taskId'] ?? '').toString(),
      status: (data['status'] ?? 'processing').toString(),
      prompt: data['prompt']?.toString(),
      displayText:
          data['displayText']?.toString() ?? data['display_text']?.toString(),
      videoUrl: data['videoUrl']?.toString() ?? data['video_url']?.toString(),
      progress: _asDouble(data['progress']),
      errorMessage:
          data['errorMessage']?.toString() ??
          data['error_message']?.toString() ??
          data['error']?.toString(),
      duration: _asInt(data['duration']),
      pointsCost: _asInt(data['pointsCost'] ?? data['points_cost']) ?? 0,
      pointsRefunded: data['pointsRefunded'] == true ||
          data['points_refunded'] == true,
    );
  }

  static double? _asDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    return double.tryParse(value.toString());
  }

  static int? _asInt(dynamic value) {
    if (value == null) {
      return null;
    }
    return int.tryParse(value.toString());
  }
}
