import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/snackbar_helper.dart';
import 'auth_controller.dart';

class RegisterController extends GetxController {
  RegisterController() : _authController = Get.find<AuthController>();

  final AuthController _authController;

  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController aliasController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController inviteCodeController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  final RxBool isSubmitting = false.obs;

  @override
  void onClose() {
    usernameController.dispose();
    emailController.dispose();
    aliasController.dispose();
    phoneController.dispose();
    inviteCodeController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }

  Future<void> submit() async {
    final String username = usernameController.text.trim();
    final String email = emailController.text.trim();
    final String alias = aliasController.text.trim();
    final String phone = phoneController.text.trim();
    final String inviteCode = inviteCodeController.text.trim();
    final String password = passwordController.text.trim();
    final String confirmPassword = confirmPasswordController.text.trim();

    if (username.isEmpty ||
        email.isEmpty ||
        inviteCode.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      SnackbarHelper.error('请把注册信息填写完整');
      return;
    }
    if (password != confirmPassword) {
      SnackbarHelper.error('两次输入的密码不一致');
      return;
    }

    isSubmitting.value = true;
    try {
      await _authController.register(
        username: username,
        email: email,
        password: password,
        inviteCode: inviteCode,
        alias: alias.isEmpty ? null : alias,
        phone: phone.isEmpty ? null : phone,
      );
      SnackbarHelper.success('注册成功，请使用新账号登录');
      Get.offNamed(
        AppRoutes.login,
        arguments: <String, String>{'username': username},
      );
    } catch (error) {
      SnackbarHelper.error(_readError(error, fallback: '注册失败'));
    } finally {
      isSubmitting.value = false;
    }
  }

  String _readError(Object error, {required String fallback}) {
    return AppException.resolveMessage(error, fallback: fallback);
  }
}
