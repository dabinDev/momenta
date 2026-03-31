import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/snackbar_helper.dart';
import 'auth_controller.dart';

class ForgotPasswordController extends GetxController {
  ForgotPasswordController() : _authController = Get.find<AuthController>();

  final AuthController _authController;

  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  final RxBool isSubmitting = false.obs;

  @override
  void onClose() {
    usernameController.dispose();
    emailController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }

  Future<void> submit() async {
    final String username = usernameController.text.trim();
    final String email = emailController.text.trim();
    final String newPassword = newPasswordController.text.trim();
    final String confirmPassword = confirmPasswordController.text.trim();

    if (username.isEmpty ||
        email.isEmpty ||
        newPassword.isEmpty ||
        confirmPassword.isEmpty) {
      SnackbarHelper.error('请把信息填写完整');
      return;
    }
    if (newPassword != confirmPassword) {
      SnackbarHelper.error('两次输入的新密码不一致');
      return;
    }

    isSubmitting.value = true;
    try {
      await _authController.forgotPassword(
        username: username,
        email: email,
        newPassword: newPassword,
      );
      SnackbarHelper.success('密码已重置，请用新密码登录');
      Get.offAllNamed(AppRoutes.login);
    } catch (error) {
      SnackbarHelper.error(_readError(error, fallback: '密码重置失败'));
    } finally {
      isSubmitting.value = false;
    }
  }

  String _readError(Object error, {required String fallback}) {
    if (error is AppException) {
      return error.message;
    }
    return error.toString().isEmpty ? fallback : error.toString();
  }
}
