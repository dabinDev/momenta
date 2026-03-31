import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'app/app_binding.dart';
import 'app/constants.dart';
import 'app/routes.dart';
import 'app/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  runApp(const SilverVideoAssistantApp());
}

class SilverVideoAssistantApp extends StatelessWidget {
  const SilverVideoAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: AppConstants.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialBinding: AppBinding(),
      initialRoute: AppRoutes.launch,
      getPages: AppPages.pages,
    );
  }
}
