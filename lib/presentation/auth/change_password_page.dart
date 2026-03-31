import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../shared/widgets/large_text_field.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/section_card.dart';
import 'change_password_controller.dart';

class ChangePasswordPage extends GetView<ChangePasswordController> {
  const ChangePasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('修改密码')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: <Widget>[
            SectionCard(
              title: '修改密码',
              subtitle: '',
              icon: Icons.key_outlined,
              accentColor: const Color(0xFF5A816A),
              child: Column(
                children: <Widget>[
                  LargeTextField(
                    controller: controller.oldPasswordController,
                    label: '旧密码',
                    hintText: '请输入当前密码',
                    obscureText: true,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  LargeTextField(
                    controller: controller.newPasswordController,
                    label: '新密码',
                    hintText: '请输入新密码',
                    obscureText: true,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  LargeTextField(
                    controller: controller.confirmPasswordController,
                    label: '确认新密码',
                    hintText: '请再次输入新密码',
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => controller.submit(),
                  ),
                  const SizedBox(height: 16),
                  Obx(
                    () => PrimaryButton(
                      label: controller.isSubmitting.value ? '保存中...' : '确认修改',
                      icon: Icons.save_outlined,
                      onPressed: controller.isSubmitting.value
                          ? null
                          : controller.submit,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
