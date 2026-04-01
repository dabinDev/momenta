import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme.dart';
import '../../shared/widgets/app_page_scaffold.dart';
import '../../shared/widgets/large_text_field.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/section_card.dart';
import 'forgot_password_controller.dart';

class ForgotPasswordPage extends GetView<ForgotPasswordController> {
  const ForgotPasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: '忘记密码',
      subtitle: '通过用户名和邮箱重新设置密码',
      accentColor: AppTheme.amber,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: <Widget>[
          SectionCard(
            title: '找回密码',
            subtitle: '信息填写正确后会直接重置当前账号密码',
            icon: Icons.lock_reset_outlined,
            accentColor: AppTheme.amber,
            child: Column(
              children: <Widget>[
                LargeTextField(
                  controller: controller.usernameController,
                  label: '账号',
                  hintText: '请输入用户名',
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                LargeTextField(
                  controller: controller.emailController,
                  label: '邮箱',
                  hintText: '请输入注册邮箱',
                  keyboardType: TextInputType.emailAddress,
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
                    label: controller.isSubmitting.value ? '提交中...' : '重设密码',
                    icon: Icons.check_circle_outline_rounded,
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
