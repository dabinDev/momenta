import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme.dart';
import '../../shared/widgets/app_page_scaffold.dart';
import '../../shared/widgets/large_text_field.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/section_card.dart';
import 'register_controller.dart';

class RegisterPage extends GetView<RegisterController> {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: '注册账号',
      subtitle: '注册需要邀请码，成功后返回登录页',
      accentColor: AppTheme.sky,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: <Widget>[
          SectionCard(
            title: '创建新账号',
            subtitle: '请填写基本信息与邀请码，由后端统一校验',
            icon: Icons.person_add_alt_1_rounded,
            accentColor: AppTheme.sky,
            child: Column(
              children: <Widget>[
                LargeTextField(
                  controller: controller.usernameController,
                  label: '用户名',
                  hintText: '请输入用户名',
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                LargeTextField(
                  controller: controller.emailController,
                  label: '邮箱',
                  hintText: '请输入邮箱',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                LargeTextField(
                  controller: controller.aliasController,
                  label: '昵称（可选）',
                  hintText: '请输入昵称',
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                LargeTextField(
                  controller: controller.phoneController,
                  label: '手机号（可选）',
                  hintText: '请输入手机号',
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                LargeTextField(
                  controller: controller.inviteCodeController,
                  label: '邀请码',
                  hintText: '请输入邀请码',
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                LargeTextField(
                  controller: controller.passwordController,
                  label: '密码',
                  hintText: '请输入密码',
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                LargeTextField(
                  controller: controller.confirmPasswordController,
                  label: '确认密码',
                  hintText: '请再次输入密码',
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => controller.submit(),
                ),
                const SizedBox(height: 16),
                Obx(
                  () => PrimaryButton(
                    label: controller.isSubmitting.value ? '注册中...' : '确认注册',
                    icon: Icons.app_registration_rounded,
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
