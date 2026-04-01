import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../shared/widgets/app_backdrop.dart';
import 'auth_controller.dart';

class LaunchPage extends StatefulWidget {
  const LaunchPage({super.key});

  @override
  State<LaunchPage> createState() => _LaunchPageState();
}

class _LaunchPageState extends State<LaunchPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _redirect());
  }

  Future<void> _redirect() async {
    final AuthController authController = Get.find<AuthController>();
    await authController.bootstrap();
    if (!mounted) {
      return;
    }
    if (authController.isLoggedIn) {
      authController.refreshCurrentUser(silent: true);
      Get.offAllNamed(AppRoutes.home);
      return;
    }
    Get.offAllNamed(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackdrop(
        primaryTint: AppTheme.primary,
        secondaryTint: AppTheme.sky,
        tertiaryTint: AppTheme.jade,
        child: Center(
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.76),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 34,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text('正在进入', style: theme.textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(
                  '正在同步账户状态',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
