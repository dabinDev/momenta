import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/constants.dart';
import '../../app/theme.dart';
import '../../shared/widgets/app_backdrop.dart';
import '../../shared/widgets/app_brand_mark.dart';
import '../../shared/widgets/large_text_field.dart';
import '../../shared/widgets/primary_button.dart';
import 'register_controller.dart';

class RegisterPage extends GetView<RegisterController> {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackdrop(
        primaryTint: AppTheme.sky,
        secondaryTint: AppTheme.primary,
        tertiaryTint: AppTheme.jade,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool wideLayout = constraints.maxWidth >= 860;
              final Widget hero = _RegisterHero(wideLayout: wideLayout);
              final Widget form = _RegisterForm(controller: controller);

              return ScrollConfiguration(
                behavior:
                    ScrollConfiguration.of(context).copyWith(scrollbars: false),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1020),
                      child: wideLayout
                          ? IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  Expanded(child: hero),
                                  const SizedBox(width: 26),
                                  SizedBox(width: 430, child: form),
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
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RegisterHero extends StatelessWidget {
  const _RegisterHero({required this.wideLayout});

  final bool wideLayout;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(4, wideLayout ? 18 : 4, 4, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            wideLayout ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: <Widget>[
          const AppBrandMark(size: 82, radius: 24),
          const SizedBox(height: 24),
          Text(
            AppConstants.appTitle,
            style: theme.textTheme.headlineLarge?.copyWith(
              fontSize: wideLayout ? 40 : 33,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '受邀注册后即可进入同一套创作、历史和设置能力，账号校验、邀请码消耗与用户资料都由后端统一维护。',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppTheme.muted,
            ),
          ),
          const SizedBox(height: 18),
          const Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _HeroPill(label: '邀请码校验', tint: AppTheme.sky),
              _HeroPill(label: '统一账号体系', tint: AppTheme.coral),
              _HeroPill(label: '注册后直接登录', tint: AppTheme.jade),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  Colors.white.withValues(alpha: 0.9),
                  AppTheme.surfaceSky.withValues(alpha: 0.86),
                  AppTheme.surfaceSoft.withValues(alpha: 0.82),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _HeroNote(
                  title: '注册要求',
                  body: '必须填写后台生成的邀请码；没有邀请码、邀请码失效或已停用时无法注册。',
                ),
                SizedBox(height: 12),
                _HeroNote(
                  title: '账号资料',
                  body: '用户名、邮箱、密码为必填；昵称和手机号可选，后续可在设置页继续维护。',
                ),
                SizedBox(height: 12),
                _HeroNote(
                  title: '后续流转',
                  body: '注册成功后回到登录页，使用新账号进入 App，与 H5 和后台保持同一套用户数据。',
                ),
              ],
            ),
          ),
          if (wideLayout) const Spacer(),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({
    required this.label,
    required this.tint,
  });

  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.text,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _HeroNote extends StatelessWidget {
  const _HeroNote({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          body,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppTheme.muted,
            height: 1.55,
          ),
        ),
      ],
    );
  }
}

class _RegisterForm extends GetView<RegisterController> {
  const _RegisterForm({required this.controller});

  @override
  final RegisterController controller;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(26),
      ),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '注册账号',
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              '保持和登录页一致的轻量层次，邀请码作为必要条件单独强调。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.muted,
              ),
            ),
            const SizedBox(height: 18),
            LargeTextField(
              controller: controller.usernameController,
              label: '用户名',
              hintText: '请输入用户名',
              prefixIcon: Icons.person_outline_rounded,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.username],
            ),
            const SizedBox(height: 12),
            LargeTextField(
              controller: controller.emailController,
              label: '邮箱',
              hintText: '请输入邮箱',
              prefixIcon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.email],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    AppTheme.surfaceSky.withValues(alpha: 0.92),
                    Colors.white.withValues(alpha: 0.94),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.sky.withValues(alpha: 0.18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    '邀请码',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '后台生成的邀请码是注册必填项，注册成功后会自动记录到管理端用户档案。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.muted,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  LargeTextField(
                    controller: controller.inviteCodeController,
                    label: '受邀口令',
                    hintText: '请输入邀请码',
                    prefixIcon: Icons.confirmation_number_outlined,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: controller.openInviteScanner,
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      label: const Text('扫一扫带入邀请码'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            LargeTextField(
              controller: controller.passwordController,
              label: '密码',
              hintText: '请输入密码',
              prefixIcon: Icons.lock_outline_rounded,
              obscureText: true,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.newPassword],
            ),
            const SizedBox(height: 12),
            LargeTextField(
              controller: controller.confirmPasswordController,
              label: '确认密码',
              hintText: '请再次输入密码',
              prefixIcon: Icons.verified_user_outlined,
              obscureText: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => controller.submit(),
            ),
            const SizedBox(height: 18),
            Obx(
              () => PrimaryButton(
                label: controller.isSubmitting.value ? '注册中...' : '确认注册',
                icon: Icons.app_registration_rounded,
                onPressed:
                    controller.isSubmitting.value ? null : controller.submit,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: Get.back,
                child: const Text('返回登录'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
