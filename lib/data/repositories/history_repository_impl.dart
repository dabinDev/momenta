import 'dart:convert';

import '../../core/services/local_storage_service.dart';
import '../../domain/repositories/history_repository.dart';
import '../models/history_item_model.dart';
import '../models/paginated_history_model.dart';

class HistoryRepositoryImpl implements HistoryRepository {
  HistoryRepositoryImpl({
    required LocalStorageService localStorageService,
  }) : _localStorageService = localStorageService;

  final LocalStorageService _localStorageService;

  static const String _historyPrefix = 'history_records_';
  static const String _authUsernameKey = 'auth_username';

  @override
  Future<List<HistoryItemModel>> allItems() async {
    final String? raw = _localStorageService.read<String>(_storageKey);
    if (raw == null || raw.isEmpty) {
      return <HistoryItemModel>[];
    }

    final dynamic decoded = jsonDecode(raw);
    if (decoded is! List) {
      return <HistoryItemModel>[];
    }

    final List<HistoryItemModel> items = decoded
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (Map<dynamic, dynamic> item) => HistoryItemModel.fromJson(
            item.map((dynamic key, dynamic value) =>
                MapEntry(key.toString(), value)),
          ),
        )
        .toList();
    items.sort(_compareByCreatedAtDesc);
    return items;
  }

  @override
  Future<PaginatedHistoryModel> list({
    required int page,
    required int limit,
    String filter = 'all',
  }) async {
    final List<HistoryItemModel> all = await allItems();
    final List<HistoryItemModel> filtered = filter == 'all'
        ? all
        : all.where((HistoryItemModel item) => item.status == filter).toList();

    final int start = ((page - 1) * limit).clamp(0, filtered.length);
    final int end = (start + limit).clamp(0, filtered.length);
    final List<HistoryItemModel> pageItems = filtered.sublist(start, end);

    return PaginatedHistoryModel(
      items: pageItems,
      page: page,
      limit: limit,
      total: filtered.length,
    );
  }

  @override
  Future<void> upsert(HistoryItemModel item) async {
    final List<HistoryItemModel> items = await allItems();
    final int index =
        items.indexWhere((HistoryItemModel element) => element.id == item.id);
    if (index >= 0) {
      final HistoryItemModel existing = items[index];
      items[index] = HistoryItemModel(
        id: item.id,
        status: item.status,
        prompt: _firstNonEmpty(item.prompt, existing.prompt),
        videoUrl: _firstNonEmpty(item.videoUrl, existing.videoUrl),
        errorMessage: _firstNonEmpty(item.errorMessage, existing.errorMessage),
        duration: item.duration ?? existing.duration,
        createdAt: existing.createdAt ?? item.createdAt ?? DateTime.now(),
      );
    } else {
      items.add(
        item.copyWith(
          createdAt: item.createdAt ?? DateTime.now(),
        ),
      );
    }
    items.sort(_compareByCreatedAtDesc);
    await _persist(items);
  }

  @override
  Future<void> remove(String id) async {
    final List<HistoryItemModel> items = await allItems();
    items.removeWhere((HistoryItemModel item) => item.id == id);
    await _persist(items);
  }

  @override
  Future<void> clear() async {
    await _localStorageService.remove(_storageKey);
  }

  String get _storageKey {
    final String username =
        (_localStorageService.read<String>(_authUsernameKey) ?? 'guest').trim();
    return '$_historyPrefix${username.isEmpty ? 'guest' : username}';
  }

  Future<void> _persist(List<HistoryItemModel> items) {
    return _localStorageService.write(
      _storageKey,
      jsonEncode(items.map((HistoryItemModel item) => item.toJson()).toList()),
    );
  }

  static int _compareByCreatedAtDesc(HistoryItemModel a, HistoryItemModel b) {
    final DateTime aTime =
        a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final DateTime bTime =
        b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return bTime.compareTo(aTime);
  }

  static String? _firstNonEmpty(String? current, String? fallback) {
    final String? trimmed = current?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
    return fallback;
  }
}
