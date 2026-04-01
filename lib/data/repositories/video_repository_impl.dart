import 'dart:io';

import '../../domain/repositories/video_repository.dart';
import '../api/api_service.dart';
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
  Future<String> generatePrompt(String text) =>
      _apiService.generatePrompt(text);

  @override
  Future<VideoTaskModel> generateVideo({
    String? inputText,
    String? polishedText,
    required String prompt,
    required List<String> images,
    required int duration,
  }) {
    return _apiService.generateVideo(
      inputText: inputText,
      polishedText: polishedText,
      prompt: prompt,
      images: images,
      duration: duration,
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
  Future<String> polishText(String text) => _apiService.polishText(text);

  @override
  Future<VideoTaskModel> videoStatus(String id) => _apiService.videoStatus(id);
}
