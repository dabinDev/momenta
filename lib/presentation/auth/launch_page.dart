import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes.dart';
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
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[Color(0xFFF7F4EE), Color(0xFFFFFBF5)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(26),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.account_circle_outlined,
                  size: 42,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 18),
              Text('正在进入', style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
