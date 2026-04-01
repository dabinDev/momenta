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
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              Color(0xFFF5EFE6),
              Color(0xFFF9F6EF),
              Color(0xFFEAF1EC),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool wideLayout = constraints.maxWidth >= 860;

              final Widget hero = _LoginHero(wideLayout: wideLayout);
              final Widget form = _LoginForm(controller: controller);

              return SingleChildScrollView(
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
                                const SizedBox(width: 20),
                                SizedBox(width: 410, child: form),
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
      padding: const EdgeInsets.fromLTRB(26, 26, 26, 26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFFFFFAF4),
            Color(0xFFF2F6F1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                colors: <Color>[
                  Color(0xFFF6E9D1),
                  Color(0xFFE8F3EE),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: theme.colorScheme.primary,
              size: 30,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            AppConstants.appTitle,
            style: theme.textTheme.headlineLarge?.copyWith(
              fontSize: wideLayout ? 38 : 32,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '为长辈准备的简洁视频创作流程。',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '登录后即可进入创作、历史记录和个人中心。',
            style: theme.textTheme.bodyMedium,
          ),
          if (wideLayout) const Spacer(),
          if (!wideLayout) const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const <Widget>[
              _HeroTag(icon: Icons.verified_user_outlined, label: '账号登录'),
              _HeroTag(icon: Icons.history_rounded, label: '历史记录'),
              _HeroTag(icon: Icons.person_outline_rounded, label: '个人中心'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroTag extends StatelessWidget {
  const _HeroTag({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginForm extends GetView<LoginController> {
  const _LoginForm({required this.controller});

  @override
  final LoginController controller;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '账号登录',
      subtitle: '输入用户名和密码后继续。',
      icon: Icons.person_outline_rounded,
      accentColor: Theme.of(context).colorScheme.primary,
      child: AutofillGroup(
        child: Column(
          children: <Widget>[
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
