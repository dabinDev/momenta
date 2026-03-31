import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/snackbar_helper.dart';
import 'auth_controller.dart';

class ChangePasswordController extends GetxController {
  ChangePasswordController() : _authController = Get.find<AuthController>();

  final AuthController _authController;

  final TextEditingController oldPasswordController = TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  final RxBool isSubmitting = false.obs;

  @override
  void onClose() {
    oldPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }

  Future<void> submit() async {
    final String oldPassword = oldPasswordController.text.trim();
    final String newPassword = newPasswordController.text.trim();
    final String confirmPassword = confirmPasswordController.text.trim();

    if (oldPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      SnackbarHelper.error('请把密码填写完整');
      return;
    }
    if (newPassword != confirmPassword) {
      SnackbarHelper.error('两次输入的新密码不一致');
      return;
    }

    isSubmitting.value = true;
    try {
      await _authController.changePassword(
        oldPassword: oldPassword,
        newPassword: newPassword,
      );
      oldPasswordController.clear();
      newPasswordController.clear();
      confirmPasswordController.clear();
      SnackbarHelper.success('密码修改成功');
      Get.back<void>();
    } catch (error) {
      SnackbarHelper.error(_readError(error, fallback: '密码修改失败'));
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
