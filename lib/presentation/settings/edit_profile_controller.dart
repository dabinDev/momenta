import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/snackbar_helper.dart';
import '../auth/auth_controller.dart';

class EditProfileController extends GetxController {
  EditProfileController() : _authController = Get.find<AuthController>();

  final AuthController _authController;

  final TextEditingController aliasController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  final RxBool isSubmitting = false.obs;

  @override
  void onInit() {
    super.onInit();
    final user = _authController.currentUser.value;
    aliasController.text = user?.alias ?? '';
    emailController.text = user?.email ?? '';
    phoneController.text = user?.phone ?? '';
  }

  @override
  void onClose() {
    aliasController.dispose();
    emailController.dispose();
    phoneController.dispose();
    super.onClose();
  }

  Future<void> submit() async {
    final String email = emailController.text.trim();
    final String alias = aliasController.text.trim();
    final String phone = phoneController.text.trim();

    if (email.isEmpty) {
      SnackbarHelper.error('请先填写邮箱');
      return;
    }

    isSubmitting.value = true;
    try {
      await _authController.updateCurrentProfile(
        email: email,
        alias: alias,
        phone: phone,
      );
      SnackbarHelper.success('个人资料已更新');
      Get.back<void>();
    } catch (error) {
      SnackbarHelper.error(_readError(error, fallback: '更新个人资料失败'));
    } finally {
      isSubmitting.value = false;
    }
  }

  String _readError(Object error, {required String fallback}) {
    if (error is AppException) {
      return error.message;
    }
    final String message = error.toString().trim();
    return message.isEmpty ? fallback : message;
  }
}
