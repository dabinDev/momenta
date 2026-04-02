import 'dart:io';

import '../../data/models/uploaded_file_model.dart';

abstract class MediaRepository {
  Future<List<UploadedFileModel>> uploadImages(List<File> files);
  Future<UploadedFileModel> uploadReferenceVideo(File file);
  Future<String> speechToText(File audioFile);
}
