import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/constants.dart';
import '../../shared/widgets/large_text_field.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/section_card.dart';
import 'login_controller.dart';

class LoginPage extends GetView<LoginController> {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[Color(0xFFF7F4EE), Color(0xFFFFFBF5)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: <Color>[Color(0xFF2E7080), Color(0xFFE18C49)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.lock_open_rounded,
                            color: Colors.white, size: 30),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '账号登录',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        AppConstants.authServerBaseUrl,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SectionCard(
                  title: '登录',
                  subtitle: '',
                  icon: Icons.person_outline_rounded,
                  accentColor: const Color(0xFF537AB7),
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
                        controller: controller.passwordController,
                        label: '密码',
                        hintText: '请输入密码',
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => controller.submit(),
                      ),
                      const SizedBox(height: 16),
                      Obx(
                        () => PrimaryButton(
                          label:
                              controller.isSubmitting.value ? '登录中...' : '登录',
                          icon: Icons.login_rounded,
                          onPressed: controller.isSubmitting.value
                              ? null
                              : controller.submit,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: controller.openForgotPassword,
                          child: const Text('忘记密码'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
