import '../../data/models/history_item_model.dart';
import '../../data/models/paginated_history_model.dart';

abstract class HistoryRepository {
  Future<List<HistoryItemModel>> allItems();
  Future<PaginatedHistoryModel> list({
    required int page,
    required int limit,
    String filter = 'all',
  });
  Future<void> upsert(HistoryItemModel item);
  Future<void> remove(String id);
  Future<void> clear();
}
