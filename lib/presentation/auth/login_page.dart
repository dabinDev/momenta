import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/constants.dart';
import '../../app/theme.dart';
import '../../shared/widgets/app_backdrop.dart';
import '../../shared/widgets/large_text_field.dart';
import '../../shared/widgets/primary_button.dart';
import 'login_controller.dart';

class LoginPage extends GetView<LoginController> {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackdrop(
        primaryTint: AppTheme.primary,
        secondaryTint: AppTheme.sky,
        tertiaryTint: AppTheme.jade,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool wideLayout = constraints.maxWidth >= 860;

              final Widget hero = _LoginHero(wideLayout: wideLayout);
              final Widget form = _LoginForm(controller: controller);

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 980),
                    child: wideLayout
                        ? IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                Expanded(child: hero),
                                const SizedBox(width: 22),
                                SizedBox(width: 400, child: form),
                              ],
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              hero,
                              const SizedBox(height: 18),
                              form,
                            ],
                          ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LoginHero extends StatelessWidget {
  const _LoginHero({required this.wideLayout});

  final bool wideLayout;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 58,
            height: 6,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[
                  AppTheme.primary,
                  AppTheme.amber,
                  AppTheme.jade,
                ],
              ),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(24),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: AppTheme.primary,
              size: 34,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            AppConstants.appTitle,
            style: theme.textTheme.headlineLarge?.copyWith(
              fontSize: wideLayout ? 38 : 32,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '专为长辈准备的简洁视频创作流程。',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 22),
          const _HeroLine(
            icon: Icons.favorite_border_rounded,
            label: '一句话就能生成温暖视频',
            tint: AppTheme.coral,
          ),
          const SizedBox(height: 12),
          const _HeroLine(
            icon: Icons.graphic_eq_rounded,
            label: '支持语音输入和文案润色',
            tint: AppTheme.sky,
          ),
          const SizedBox(height: 12),
          const _HeroLine(
            icon: Icons.history_rounded,
            label: '历史记录与个人中心一目了然',
            tint: AppTheme.jade,
          ),
          if (wideLayout) const Spacer(),
        ],
      ),
    );
  }
}

class _HeroLine extends StatelessWidget {
  const _HeroLine({
    required this.icon,
    required this.label,
    required this.tint,
  });

  final IconData icon;
  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 20, color: tint),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ],
    );
  }
}

class _LoginForm extends GetView<LoginController> {
  const _LoginForm({required this.controller});

  @override
  final LoginController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(30),
      ),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '账号登录',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '输入用户名和密码后继续。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            LargeTextField(
              controller: controller.usernameController,
              label: '用户名',
              hintText: '请输入用户名',
              prefixIcon: Icons.person_outline_rounded,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.username],
            ),
            const SizedBox(height: 14),
            LargeTextField(
              controller: controller.passwordController,
              label: '密码',
              hintText: '请输入密码',
              prefixIcon: Icons.lock_outline_rounded,
              obscureText: true,
              textInputAction: TextInputAction.done,
              autofillHints: const <String>[AutofillHints.password],
              onSubmitted: (_) => controller.submit(),
            ),
            const SizedBox(height: 18),
            Obx(
              () => PrimaryButton(
                label: controller.isSubmitting.value ? '登录中...' : '登录',
                icon: Icons.login_rounded,
                onPressed:
                    controller.isSubmitting.value ? null : controller.submit,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '仅限已授权账号使用',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                TextButton(
                  onPressed: controller.openForgotPassword,
                  child: const Text('忘记密码'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
