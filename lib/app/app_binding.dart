import 'package:get/get.dart';

import '../core/services/local_storage_service.dart';
import '../core/services/secure_storage_service.dart';
import '../data/api/api_client.dart';
import '../data/api/api_service.dart';
import '../data/repositories/auth_repository_impl.dart';
import '../data/repositories/config_repository_impl.dart';
import '../data/repositories/history_repository_impl.dart';
import '../data/repositories/media_repository_impl.dart';
import '../data/repositories/video_repository_impl.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/config_repository.dart';
import '../domain/repositories/history_repository.dart';
import '../domain/repositories/media_repository.dart';
import '../domain/repositories/video_repository.dart';
import '../presentation/auth/auth_controller.dart';

class AppBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(LocalStorageService(), permanent: true);
    Get.put(SecureStorageService(), permanent: true);
    Get.put(ApiClient(), permanent: true);
    Get.put(ApiService(Get.find<ApiClient>(), Get.find<SecureStorageService>()),
        permanent: true);

    Get.put<AuthRepository>(
      AuthRepositoryImpl(
        apiService: Get.find<ApiService>(),
        localStorageService: Get.find<LocalStorageService>(),
        secureStorageService: Get.find<SecureStorageService>(),
      ),
      permanent: true,
    );
    Get.put(AuthController(repository: Get.find<AuthRepository>()),
        permanent: true);

    Get.put<ConfigRepository>(
      ConfigRepositoryImpl(
        apiService: Get.find<ApiService>(),
        localStorageService: Get.find<LocalStorageService>(),
        secureStorageService: Get.find<SecureStorageService>(),
      ),
      permanent: true,
    );
    Get.put<HistoryRepository>(
      HistoryRepositoryImpl(
        localStorageService: Get.find<LocalStorageService>(),
        apiService: Get.find<ApiService>(),
      ),
      permanent: true,
    );
    Get.put<MediaRepository>(
      MediaRepositoryImpl(apiService: Get.find<ApiService>()),
      permanent: true,
    );
    Get.put<VideoRepository>(
      VideoRepositoryImpl(apiService: Get.find<ApiService>()),
      permanent: true,
    );
  }
}
