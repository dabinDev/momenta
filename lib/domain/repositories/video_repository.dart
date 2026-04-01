import 'dart:io';

import '../../data/models/paginated_history_model.dart';
import '../../data/models/video_task_model.dart';

abstract class VideoRepository {
  Future<String> transcribeAudio(File audioFile);
  Future<String> polishText(String text);
  Future<String> generatePrompt(String text);
  Future<VideoTaskModel> generateVideo({
    String? inputText,
    String? polishedText,
    required String prompt,
    required List<String> images,
    required int duration,
  });
  Future<VideoTaskModel> videoStatus(String id);
  Future<PaginatedHistoryModel> history({
    required int page,
    required int limit,
  });
  Future<void> deleteHistory(String id);
}
