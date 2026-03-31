import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SnackbarHelper {
  SnackbarHelper._();

  static void success(String message, {String title = '操作成功'}) {
    _show(title: title, message: message);
  }

  static void error(String message, {String title = '操作失败'}) {
    _show(title: title, message: message);
  }

  static void info(String message, {String title = '提示'}) {
    _show(title: title, message: message);
  }

  static void _show({required String title, required String message}) {
    final ThemeData theme = Get.theme;

    Get.closeAllSnackbars();
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      backgroundColor: theme.colorScheme.surface,
      borderRadius: 22,
      borderColor: theme.colorScheme.outlineVariant,
      borderWidth: 1,
      boxShadows: <BoxShadow>[
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ],
      titleText: Text(
        title,
        style: theme.textTheme.titleMedium,
      ),
      messageText: Text(
        message,
        style: theme.textTheme.bodyLarge,
      ),
    );
  }
}
