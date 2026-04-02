import 'dart:io';

import '../../data/models/ai_template_model.dart';
import '../../data/models/create_workbench_model.dart';
import '../../data/models/paginated_history_model.dart';
import '../../data/models/video_task_model.dart';

abstract class VideoRepository {
  Future<String> transcribeAudio(File audioFile);
  Future<String> correctText(String text);
  Future<String> polishText(String text);
  Future<CreateWorkbenchModel> fetchCreateWorkbench();
  Future<List<AiTemplateModel>> fetchPromptTemplates();
  Future<List<AiTemplateModel>> fetchVideoTemplates();
  Future<String> generatePrompt(String text, {String? promptTemplateKey});
  Future<VideoTaskModel> generateSimpleVideo({
    String? inputText,
    String? polishedText,
    required String prompt,
    required List<String> images,
    required int duration,
    String? promptTemplateKey,
    String? videoTemplateKey,
  });
  Future<VideoTaskModel> generateStarterVideo({
    String? inputText,
    String? prompt,
    required List<String> images,
    required int duration,
    required String referenceLink,
    String? promptTemplateKey,
    String? videoTemplateKey,
    String? supplementalText,
  });
  Future<VideoTaskModel> generateCustomVideo({
    String? inputText,
    String? prompt,
    required List<String> images,
    required int duration,
    required String videoTemplateKey,
    String? promptTemplateKey,
    String? referenceVideoPath,
    String? supplementalText,
  });
  Future<VideoTaskModel> videoStatus(String id);
  Future<PaginatedHistoryModel> history({
    required int page,
    required int limit,
  });
  Future<void> deleteHistory(String id);
}
