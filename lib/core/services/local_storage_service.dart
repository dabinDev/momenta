import 'package:get_storage/get_storage.dart';

class LocalStorageService {
  LocalStorageService() : _box = GetStorage();

  final GetStorage _box;

  T? read<T>(String key) => _box.read<T>(key);

  Future<void> write(String key, dynamic value) async {
    await _box.write(key, value);
  }

  Future<void> remove(String key) async {
    await _box.remove(key);
  }
}
