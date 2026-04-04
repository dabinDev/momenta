import 'package:get/get.dart';

import '../../app/routes.dart';
import '../../core/services/download_manager_service.dart';
import '../../data/models/user_profile_model.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthController extends GetxController {
  AuthController({required AuthRepository repository})
      : _repository = repository;

  final AuthRepository _repository;
  final Rxn<UserProfileModel> currentUser = Rxn<UserProfileModel>();

  bool _bootstrapped = false;

  bool get isLoggedIn => currentUser.value != null;

  Future<void> bootstrap() async {
    if (_bootstrapped) {
      return;
    }
    currentUser.value = await _repository.restoreLocalUser();
    if (Get.isRegistered<DownloadManagerService>()) {
      Get.find<DownloadManagerService>().reload();
    }
    _bootstrapped = true;
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    currentUser.value = await _repository.login(
      username: username,
      password: password,
    );
    if (Get.isRegistered<DownloadManagerService>()) {
      Get.find<DownloadManagerService>().reload();
    }
  }

  Future<void> register({
    required String username,
    required String email,
    required String password,
    required String inviteCode,
    String? alias,
    String? phone,
  }) {
    return _repository.register(
      username: username,
      email: email,
      password: password,
      inviteCode: inviteCode,
      alias: alias,
      phone: phone,
    );
  }

  Future<void> refreshCurrentUser({bool silent = false}) async {
    try {
      currentUser.value = await _repository.refreshCurrentUser();
    } catch (_) {
      if (!silent) {
        rethrow;
      }
    }
  }

  Future<void> forgotPassword({
    required String username,
    required String email,
    required String newPassword,
  }) {
    return _repository.forgotPassword(
      username: username,
      email: email,
      newPassword: newPassword,
    );
  }

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) {
    return _repository.changePassword(
      oldPassword: oldPassword,
      newPassword: newPassword,
    );
  }

  Future<UserProfileModel> updateCurrentProfile({
    required String email,
    required String alias,
    required String phone,
  }) async {
    final UserProfileModel user = await _repository.updateCurrentProfile(
      email: email,
      alias: alias,
      phone: phone,
    );
    currentUser.value = user;
    return user;
  }

  Future<void> logout() async {
    await _repository.logout();
    currentUser.value = null;
    if (Get.isRegistered<DownloadManagerService>()) {
      Get.find<DownloadManagerService>().reload();
    }
    Get.offAllNamed(AppRoutes.login);
  }
}
