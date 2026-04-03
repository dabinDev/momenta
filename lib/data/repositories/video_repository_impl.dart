import 'dart:io';

import '../../domain/repositories/video_repository.dart';
import '../api/api_service.dart';
import '../models/ai_template_model.dart';
import '../models/create_workbench_model.dart';
import '../models/paginated_history_model.dart';
import '../models/video_task_model.dart';

class VideoRepositoryImpl implements VideoRepository {
  VideoRepositoryImpl({required ApiService apiService})
      : _apiService = apiService;

  final ApiService _apiService;

  @override
  Future<void> deleteHistory(String id) => _apiService.deleteHistory(id);

  @override
  Future<String> transcribeAudio(File audioFile) =>
      _apiService.speechToText(audioFile);

  @override
  Future<String> correctText(String text) => _apiService.correctText(text);

  @override
  Future<List<AiTemplateModel>> fetchPromptTemplates() =>
      _apiService.fetchPromptTemplates();

  @override
  Future<CreateWorkbenchModel> fetchCreateWorkbench() =>
      _apiService.fetchCreateWorkbench();

  @override
  Future<List<AiTemplateModel>> fetchVideoTemplates() =>
      _apiService.fetchVideoTemplates();

  @override
  Future<String> generatePrompt(String text, {String? promptTemplateKey}) =>
      _apiService.generatePrompt(
        text,
        promptTemplateKey: promptTemplateKey,
      );

  @override
  Future<VideoTaskModel> generateSimpleVideo({
    String? inputText,
    String? polishedText,
    required String prompt,
    required List<String> images,
    required int duration,
    String? promptTemplateKey,
    String? videoTemplateKey,
  }) {
    return _apiService.generateSimpleVideo(
      inputText: inputText,
      polishedText: polishedText,
      prompt: prompt,
      images: images,
      duration: duration,
      promptTemplateKey: promptTemplateKey,
      videoTemplateKey: videoTemplateKey,
    );
  }

  @override
  Future<VideoTaskModel> generateStarterVideo({
    String? inputText,
    String? prompt,
    required List<String> images,
    required int duration,
    required String referenceLink,
    String? promptTemplateKey,
    String? videoTemplateKey,
    String? supplementalText,
  }) {
    return _apiService.generateStarterVideo(
      inputText: inputText,
      prompt: prompt,
      images: images,
      duration: duration,
      referenceLink: referenceLink,
      promptTemplateKey: promptTemplateKey,
      videoTemplateKey: videoTemplateKey,
      supplementalText: supplementalText,
    );
  }

  @override
  Future<VideoTaskModel> generateCustomVideo({
    String? inputText,
    String? prompt,
    required List<String> images,
    required int duration,
    required String videoTemplateKey,
    String? promptTemplateKey,
    String? referenceLink,
    String? referenceVideoPath,
    String? supplementalText,
  }) {
    return _apiService.generateCustomVideo(
      inputText: inputText,
      prompt: prompt,
      images: images,
      duration: duration,
      videoTemplateKey: videoTemplateKey,
      promptTemplateKey: promptTemplateKey,
      referenceLink: referenceLink,
      referenceVideoPath: referenceVideoPath,
      supplementalText: supplementalText,
    );
  }

  @override
  Future<PaginatedHistoryModel> history({
    required int page,
    required int limit,
  }) {
    return _apiService.history(page: page, limit: limit);
  }

  @override
  Future<VideoTaskModel> videoStatus(String id) => _apiService.videoStatus(id);
}
