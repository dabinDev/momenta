import 'history_item_model.dart';

class PaginatedHistoryModel {
  const PaginatedHistoryModel({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
  });

  final List<HistoryItemModel> items;
  final int page;
  final int limit;
  final int total;

  factory PaginatedHistoryModel.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    final List<dynamic> list = data['items'] as List<dynamic>? ??
        data['list'] as List<dynamic>? ??
        data['records'] as List<dynamic>? ??
        <dynamic>[];
    return PaginatedHistoryModel(
      items: list
          .map((dynamic item) => HistoryItemModel.fromJson(
                item is Map<String, dynamic>
                    ? item
                    : (item as Map).map((dynamic key, dynamic value) =>
                        MapEntry(key.toString(), value)),
              ))
          .toList(),
      page: int.tryParse((data['page'] ?? 1).toString()) ?? 1,
      limit: int.tryParse((data['limit'] ?? 10).toString()) ?? 10,
      total: int.tryParse((data['total'] ?? list.length).toString()) ??
          list.length,
    );
  }
}
