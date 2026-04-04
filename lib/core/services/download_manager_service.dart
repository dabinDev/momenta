import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/api/api_service.dart';
import '../../data/models/download_task_record_model.dart';
import '../errors/app_exception.dart';
import '../utils/file_utils.dart';
import '../utils/snackbar_helper.dart';
import 'local_storage_service.dart';

class DownloadManagerService extends GetxService {
  DownloadManagerService({
    required LocalStorageService localStorageService,
    required ApiService apiService,
  })  : _localStorageService = localStorageService,
        _apiService = apiService {
    reload();
  }

  static const String _storageKeyPrefix = 'video_download_records_';
  static const String _authUsernameKey = 'auth_username';

  final LocalStorageService _localStorageService;
  final ApiService _apiService;
  final RxList<DownloadTaskRecordModel> items = <DownloadTaskRecordModel>[].obs;

  final Set<String> _activeTaskIds = <String>{};

  int get downloadingCount =>
      items.where((DownloadTaskRecordModel item) => item.isDownloading).length;

  int get completedCount =>
      items.where((DownloadTaskRecordModel item) => item.isCompleted).length;

  int get failedCount =>
      items.where((DownloadTaskRecordModel item) => item.isFailed).length;

  DownloadTaskRecordModel? latestForTask(String taskId) {
    return _findLatestByTaskId(taskId);
  }

  void reload() {
    final String? raw = _localStorageService.read<String>(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      items.assignAll(const <DownloadTaskRecordModel>[]);
      return;
    }

    try {
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      final List<DownloadTaskRecordModel> restored = decoded
          .whereType<Map<dynamic, dynamic>>()
          .map((Map<dynamic, dynamic> item) =>
              DownloadTaskRecordModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      final List<DownloadTaskRecordModel> reconciled =
          _reconcileMissingFiles(restored);
      _sortItems(reconciled);
      items.assignAll(reconciled);
      unawaited(_persist());
    } catch (_) {
      items.assignAll(const <DownloadTaskRecordModel>[]);
    }
  }

  Future<DownloadTaskRecordModel?> startTaskDownload({
    required String taskId,
    required String title,
  }) async {
    if (taskId.trim().isEmpty) {
      return null;
    }
    if (_activeTaskIds.contains(taskId)) {
      return _findLatestByTaskId(taskId);
    }

    final DateTime now = DateTime.now();
    final DownloadTaskRecordModel initial = DownloadTaskRecordModel(
      id: '${taskId}_${now.millisecondsSinceEpoch}',
      taskId: taskId,
      title: title,
      status: 'downloading',
      savePath: await _buildSavePath(taskId: taskId, title: title, time: now),
      progress: 0,
      createdAt: now,
      updatedAt: now,
    );

    _activeTaskIds.add(taskId);
    _upsert(initial, persist: true);
    unawaited(_performDownload(initial));
    return initial;
  }

  Future<DownloadTaskRecordModel?> retryDownload(
    DownloadTaskRecordModel record,
  ) async {
    if (_activeTaskIds.contains(record.taskId)) {
      return _findLatestByTaskId(record.taskId);
    }

    final DateTime now = DateTime.now();
    final DownloadTaskRecordModel retrying = record.copyWith(
      status: 'downloading',
      savePath: await _buildSavePath(
          taskId: record.taskId, title: record.title, time: now),
      progress: 0,
      updatedAt: now,
      clearErrorMessage: true,
      clearFileSize: true,
    );

    _activeTaskIds.add(record.taskId);
    _upsert(retrying, persist: true);
    unawaited(_performDownload(retrying));
    return retrying;
  }

  Future<void> removeRecord(
    DownloadTaskRecordModel record, {
    bool deleteFile = true,
  }) async {
    if (record.isDownloading) {
      throw const AppException('当前下载进行中，请稍后再试');
    }

    if (deleteFile && record.savePath.trim().isNotEmpty) {
      final File file = File(record.savePath);
      if (await file.exists()) {
        await file.delete();
      }
    }

    items.removeWhere((DownloadTaskRecordModel item) => item.id == record.id);
    await _persist();
  }

  Future<void> clearCompleted() async {
    final List<DownloadTaskRecordModel> completed = items
        .where((DownloadTaskRecordModel item) => item.isCompleted)
        .toList();
    for (final DownloadTaskRecordModel item in completed) {
      final File file = File(item.savePath);
      if (await file.exists()) {
        await file.delete();
      }
    }
    items.removeWhere((DownloadTaskRecordModel item) => item.isCompleted);
    await _persist();
  }

  DownloadTaskRecordModel? _findLatestByTaskId(String taskId) {
    for (final DownloadTaskRecordModel item in items) {
      if (item.taskId == taskId) {
        return item;
      }
    }
    return null;
  }

  Future<void> _performDownload(DownloadTaskRecordModel seed) async {
    DownloadTaskRecordModel current = seed;
    final File target = File(seed.savePath);
    double lastPersistedProgress = 0;

    try {
      await FileUtils.ensureParentDirectory(target);
      await _apiService.downloadTaskVideo(
        taskId: seed.taskId,
        savePath: seed.savePath,
        onReceiveProgress: (int received, int total) {
          final double progress = total <= 0 ? 0 : received / total;
          current = current.copyWith(
            progress: progress.clamp(0, 1).toDouble(),
            updatedAt: DateTime.now(),
          );
          _upsert(current, persist: false);
          if ((current.progress - lastPersistedProgress) >= 0.2) {
            lastPersistedProgress = current.progress;
            unawaited(_persist());
          }
        },
      );

      final int size = await target.length();
      current = current.copyWith(
        status: 'completed',
        progress: 1,
        fileSize: size,
        updatedAt: DateTime.now(),
        clearErrorMessage: true,
      );
      _upsert(current, persist: true);
      SnackbarHelper.success('视频已下载完成，可在下载管理中查看');
    } catch (error) {
      if (await target.exists()) {
        await target.delete();
      }
      current = current.copyWith(
        status: 'failed',
        progress: 0,
        updatedAt: DateTime.now(),
        errorMessage: AppException.resolveMessage(
          error,
          fallback: '下载失败，请稍后重试',
        ),
      );
      _upsert(current, persist: true);
      SnackbarHelper.error(current.errorMessage ?? '下载失败，请稍后重试');
    } finally {
      _activeTaskIds.remove(seed.taskId);
    }
  }

  Future<String> _buildSavePath({
    required String taskId,
    required String title,
    required DateTime time,
  }) async {
    final Directory root = await _resolveDownloadRoot();
    final String safeTitle = title
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final String fileName = '${safeTitle.isEmpty ? '拾光视频' : safeTitle}'
        '_${taskId}_${time.millisecondsSinceEpoch}.mp4';
    return p.join(root.path, fileName);
  }

  Future<Directory> _resolveDownloadRoot() async {
    if (Platform.isAndroid) {
      final Directory? external = await getExternalStorageDirectory();
      if (external != null) {
        final Directory dir = Directory(p.join(external.path, 'downloads'));
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return dir;
      }
    }

    try {
      final Directory? downloads = await getDownloadsDirectory();
      if (downloads != null) {
        final Directory dir = Directory(p.join(downloads.path, '拾光视频'));
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return dir;
      }
    } catch (_) {
      // Fall through to application documents directory.
    }

    final Directory documents = await getApplicationDocumentsDirectory();
    final Directory dir = Directory(p.join(documents.path, 'downloads'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  List<DownloadTaskRecordModel> _reconcileMissingFiles(
    List<DownloadTaskRecordModel> records,
  ) {
    return records.map((DownloadTaskRecordModel item) {
      if (item.isCompleted &&
          item.savePath.trim().isNotEmpty &&
          !File(item.savePath).existsSync()) {
        return item.copyWith(
          status: 'failed',
          progress: 0,
          updatedAt: DateTime.now(),
          errorMessage: '本地文件已不存在，请重新下载',
          clearFileSize: true,
        );
      }
      return item;
    }).toList();
  }

  void _upsert(
    DownloadTaskRecordModel record, {
    required bool persist,
  }) {
    final int index = items
        .indexWhere((DownloadTaskRecordModel item) => item.id == record.id);
    if (index >= 0) {
      items[index] = record;
    } else {
      items.insert(0, record);
    }
    _sortItems(items);
    if (persist) {
      unawaited(_persist());
    }
  }

  void _sortItems(List<DownloadTaskRecordModel> records) {
    records.sort(
      (DownloadTaskRecordModel left, DownloadTaskRecordModel right) =>
          right.updatedAt.compareTo(left.updatedAt),
    );
  }

  Future<void> _persist() {
    return _localStorageService.write(
      _storageKey,
      jsonEncode(
        items.map((DownloadTaskRecordModel item) => item.toJson()).toList(),
      ),
    );
  }

  String get _storageKey {
    final String username =
        (_localStorageService.read<String>(_authUsernameKey) ?? 'guest')
            .trim()
            .toLowerCase();
    final String safeUsername = username.isEmpty
        ? 'guest'
        : username.replaceAll(RegExp(r'[^a-z0-9_]+'), '_');
    return '$_storageKeyPrefix$safeUsername';
  }
}
