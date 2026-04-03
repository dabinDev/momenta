import 'dart:io';

import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/api/api_service.dart';
import '../errors/app_exception.dart';
import 'file_utils.dart';

class VideoSaveHelper {
  VideoSaveHelper._();

  static const String albumName = '拾光视频';

  static Future<void> saveRemoteVideoToGallery({
    required ApiService apiService,
    required String videoUrl,
    String fileNamePrefix = albumName,
  }) async {
    final Directory tempDir = await getTemporaryDirectory();
    final String fileName =
        '${_sanitizeFileName(fileNamePrefix)}_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final File tempFile = File(p.join(tempDir.path, fileName));

    try {
      final bool hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) {
        final bool granted = await Gal.requestAccess(toAlbum: true);
        if (!granted) {
          throw const AppException('未获得相册权限，请在系统设置中允许后重试');
        }
      }

      await FileUtils.ensureParentDirectory(tempFile);
      await apiService.downloadVideo(
        url: videoUrl,
        savePath: tempFile.path,
      );
      await Gal.putVideo(tempFile.path, album: albumName);
    } on DioException catch (error) {
      throw AppException.fromDioException(error);
    } on GalException catch (error) {
      throw AppException(_readGalError(error));
    } finally {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  static Future<void> saveTaskVideoToGallery({
    required ApiService apiService,
    required String taskId,
    String fileNamePrefix = albumName,
  }) async {
    final Directory tempDir = await getTemporaryDirectory();
    final String fileName =
        '${_sanitizeFileName(fileNamePrefix)}_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final File tempFile = File(p.join(tempDir.path, fileName));

    try {
      final bool hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) {
        final bool granted = await Gal.requestAccess(toAlbum: true);
        if (!granted) {
          throw const AppException('鏈幏寰楃浉鍐屾潈闄愶紝璇峰湪绯荤粺璁剧疆涓厑璁稿悗閲嶈瘯');
        }
      }

      await FileUtils.ensureParentDirectory(tempFile);
      await apiService.downloadTaskVideo(
        taskId: taskId,
        savePath: tempFile.path,
      );
      await Gal.putVideo(tempFile.path, album: albumName);
    } on DioException catch (error) {
      throw AppException.fromDioException(error);
    } on GalException catch (error) {
      throw AppException(_readGalError(error));
    } finally {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  static String _sanitizeFileName(String input) {
    final String normalized = input
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    return normalized.isEmpty ? 'video' : normalized;
  }

  static String _readGalError(GalException error) {
    switch (error.type) {
      case GalExceptionType.accessDenied:
        return '未获得相册权限，请在系统设置中允许后重试';
      case GalExceptionType.notEnoughSpace:
        return '本地存储空间不足，无法保存视频';
      case GalExceptionType.notSupportedFormat:
        return '当前视频格式暂不支持保存到相册';
      case GalExceptionType.unexpected:
        return '保存视频时发生异常，请稍后重试';
    }
  }
}
