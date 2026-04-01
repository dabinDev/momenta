import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/snackbar_helper.dart';
import 'auth_controller.dart';

class LoginController extends GetxController {
  LoginController() : _authController = Get.find<AuthController>();

  final AuthController _authController;

  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final RxBool isSubmitting = false.obs;

  @override
  void onInit() {
    super.onInit();
    final String username = _authController.currentUser.value?.username ?? '';
    if (username.isNotEmpty) {
      usernameController.text = username;
    }
  }

  @override
  void onClose() {
    usernameController.dispose();
    passwordController.dispose();
    super.onClose();
  }

  Future<void> submit() async {
    final String username = usernameController.text.trim();
    final String password = passwordController.text.trim();
    if (username.isEmpty || password.isEmpty) {
      SnackbarHelper.error('请输入账号和密码');
      return;
    }

    isSubmitting.value = true;
    try {
      await _authController.login(username: username, password: password);
      Get.offAllNamed(AppRoutes.home);
    } catch (error) {
      SnackbarHelper.error(_readError(error, fallback: '登录失败'));
    } finally {
      isSubmitting.value = false;
    }
  }

  void openForgotPassword() {
    Get.toNamed(AppRoutes.forgotPassword);
  }

  String _readError(Object error, {required String fallback}) {
    return AppException.resolveMessage(error, fallback: fallback);
  }
}
