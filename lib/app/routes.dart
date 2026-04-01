import 'package:get/get.dart';

import '../presentation/auth/change_password_binding.dart';
import '../presentation/auth/change_password_page.dart';
import '../presentation/auth/forgot_password_binding.dart';
import '../presentation/auth/forgot_password_page.dart';
import '../presentation/auth/launch_page.dart';
import '../presentation/auth/login_binding.dart';
import '../presentation/auth/login_page.dart';
import '../presentation/create/create_binding.dart';
import '../presentation/create/create_page.dart';
import '../presentation/history/history_binding.dart';
import '../presentation/history/history_page.dart';
import '../presentation/settings/app_settings_binding.dart';
import '../presentation/settings/app_settings_page.dart';
import '../presentation/settings/edit_profile_binding.dart';
import '../presentation/settings/edit_profile_page.dart';
import '../presentation/settings/profile_detail_page.dart';
import '../presentation/settings/settings_binding.dart';
import '../presentation/settings/settings_page.dart';
import '../presentation/shell/main_shell_binding.dart';
import '../presentation/shell/main_shell_page.dart';
import '../presentation/video_player/video_player_binding.dart';
import '../presentation/video_player/video_player_page.dart';

class AppRoutes {
  AppRoutes._();

  static const String launch = '/';
  static const String login = '/login';
  static const String forgotPassword = '/forgot-password';
  static const String changePassword = '/change-password';
  static const String home = '/home';
  static const String create = '/create';
  static const String history = '/history';
  static const String settings = '/settings';
  static const String profileDetail = '/profile-detail';
  static const String appSettings = '/app-settings';
  static const String editProfile = '/edit-profile';
  static const String videoPlayer = '/video-player';
}

class AppPages {
  AppPages._();

  static final List<GetPage<dynamic>> pages = <GetPage<dynamic>>[
    GetPage<dynamic>(
      name: AppRoutes.launch,
      page: LaunchPage.new,
    ),
    GetPage<dynamic>(
      name: AppRoutes.login,
      page: LoginPage.new,
      binding: LoginBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.forgotPassword,
      page: ForgotPasswordPage.new,
      binding: ForgotPasswordBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.changePassword,
      page: ChangePasswordPage.new,
      binding: ChangePasswordBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.home,
      page: MainShellPage.new,
      binding: MainShellBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.create,
      page: CreatePage.new,
      binding: CreateBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.history,
      page: HistoryPage.new,
      binding: HistoryBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.settings,
      page: SettingsPage.new,
      binding: SettingsBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.profileDetail,
      page: ProfileDetailPage.new,
      binding: SettingsBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.appSettings,
      page: AppSettingsPage.new,
      binding: AppSettingsBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.editProfile,
      page: EditProfilePage.new,
      binding: EditProfileBinding(),
    ),
    GetPage<dynamic>(
      name: AppRoutes.videoPlayer,
      page: VideoPlayerPage.new,
      binding: VideoPlayerBinding(),
    ),
  ];
}
