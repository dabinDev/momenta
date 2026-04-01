import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme.dart';
import '../../shared/widgets/app_page_scaffold.dart';
import '../../shared/widgets/large_text_field.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/section_card.dart';
import 'change_password_controller.dart';

class ChangePasswordPage extends GetView<ChangePasswordController> {
  const ChangePasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: '修改密码',
      subtitle: '输入旧密码并设置新密码',
      accentColor: AppTheme.coral,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: <Widget>[
          SectionCard(
            title: '密码设置',
            subtitle: '建议使用更容易记住但足够安全的新密码',
            icon: Icons.key_outlined,
            accentColor: AppTheme.coral,
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
                    onPressed:
                        controller.isSubmitting.value ? null : controller.submit,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
