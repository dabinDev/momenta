import 'dart:io';

import 'package:path/path.dart' as p;

class FileUtils {
  FileUtils._();

  static String fileNameFromPath(String filePath) => p.basename(filePath);

  static String resolveUrl(String baseUrl, String? rawPath) {
    if (rawPath == null || rawPath.isEmpty) {
      return '';
    }
    if (rawPath.startsWith('http://') || rawPath.startsWith('https://')) {
      return rawPath;
    }
    return '${baseUrl.replaceFirst(RegExp(r'/$'), '')}/${rawPath.replaceFirst(RegExp(r'^/'), '')}';
  }

  static Future<void> ensureParentDirectory(File file) async {
    final Directory dir = file.parent;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }
}
