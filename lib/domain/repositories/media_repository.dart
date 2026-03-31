import 'dart:io';

import '../../data/models/uploaded_file_model.dart';

abstract class MediaRepository {
  Future<List<UploadedFileModel>> uploadImages(List<File> files);
  Future<String> speechToText(File audioFile);
}
