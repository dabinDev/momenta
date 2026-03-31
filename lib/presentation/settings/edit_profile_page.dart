import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../shared/widgets/large_text_field.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/section_card.dart';
import 'edit_profile_controller.dart';

class EditProfilePage extends GetView<EditProfileController> {
  const EditProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('编辑资料')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: <Widget>[
            SectionCard(
              title: '个人资料',
              subtitle: '修改昵称、邮箱、手机号',
              icon: Icons.person_outline_rounded,
              accentColor: const Color(0xFF4E7BB4),
              child: Column(
                children: <Widget>[
                  LargeTextField(
                    controller: controller.aliasController,
                    label: '昵称',
                    hintText: '请输入昵称',
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
                    controller: controller.phoneController,
                    label: '手机号',
                    hintText: '请输入手机号',
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => controller.submit(),
                  ),
                  const SizedBox(height: 16),
                  Obx(
                    () => PrimaryButton(
                      label: controller.isSubmitting.value ? '保存中...' : '保存资料',
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
