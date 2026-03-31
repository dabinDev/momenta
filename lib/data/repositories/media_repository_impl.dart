import 'dart:io';

import '../../domain/repositories/media_repository.dart';
import '../api/api_service.dart';
import '../models/uploaded_file_model.dart';

class MediaRepositoryImpl implements MediaRepository {
  MediaRepositoryImpl({required ApiService apiService})
      : _apiService = apiService;

  final ApiService _apiService;

  @override
  Future<String> speechToText(File audioFile) =>
      _apiService.speechToText(audioFile);

  @override
  Future<List<UploadedFileModel>> uploadImages(List<File> files) =>
      _apiService.uploadImages(files);
}
