import 'dart:convert';

import '../../core/services/local_storage_service.dart';
import '../../core/services/secure_storage_service.dart';
import '../../domain/repositories/auth_repository.dart';
import '../api/api_service.dart';
import '../models/auth_session_model.dart';
import '../models/user_profile_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required ApiService apiService,
    required LocalStorageService localStorageService,
    required SecureStorageService secureStorageService,
  })  : _apiService = apiService,
        _localStorageService = localStorageService,
        _secureStorageService = secureStorageService;

  final ApiService _apiService;
  final LocalStorageService _localStorageService;
  final SecureStorageService _secureStorageService;

  static const String _accessTokenKey = 'auth_access_token';
  static const String _usernameKey = 'auth_username';
  static const String _profileKey = 'auth_user_profile';

  @override
  Future<UserProfileModel?> restoreLocalUser() async {
    final String? token = await _secureStorageService.read(_accessTokenKey);
    if (token == null || token.trim().isEmpty) {
      return null;
    }

    final String? rawProfile = _localStorageService.read<String>(_profileKey);
    if (rawProfile != null && rawProfile.isNotEmpty) {
      return UserProfileModel.fromJson(
        jsonDecode(rawProfile) as Map<String, dynamic>,
      );
    }

    final String username =
        _localStorageService.read<String>(_usernameKey) ?? '';
    return UserProfileModel.placeholder(username);
  }

  @override
  Future<UserProfileModel> login({
    required String username,
    required String password,
  }) async {
    final AuthSessionModel session = AuthSessionModel.fromJson(
      await _apiService.login(username: username, password: password),
    );
    await _secureStorageService.write(_accessTokenKey, session.accessToken);
    await _localStorageService.write(_usernameKey, session.username);

    try {
      return await refreshCurrentUser();
    } catch (_) {
      final UserProfileModel fallback =
          UserProfileModel.placeholder(session.username);
      await _persistProfile(fallback);
      return fallback;
    }
  }

  @override
  Future<UserProfileModel> refreshCurrentUser() async {
    final UserProfileModel user =
        UserProfileModel.fromJson(await _apiService.currentUserInfo());
    await _persistProfile(user);
    return user;
  }

  @override
  Future<void> forgotPassword({
    required String username,
    required String email,
    required String newPassword,
  }) {
    return _apiService.forgotPassword(
      username: username,
      email: email,
      newPassword: newPassword,
    );
  }

  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) {
    return _apiService.changePassword(
      oldPassword: oldPassword,
      newPassword: newPassword,
    );
  }

  @override
  Future<UserProfileModel> updateCurrentProfile({
    required String email,
    required String alias,
    required String phone,
  }) async {
    final UserProfileModel user = UserProfileModel.fromJson(
      await _apiService.updateCurrentProfile(
        email: email,
        alias: alias,
        phone: phone,
      ),
    );
    await _persistProfile(user);
    return user;
  }

  @override
  Future<void> logout() async {
    await _secureStorageService.delete(_accessTokenKey);
    await _localStorageService.remove(_usernameKey);
    await _localStorageService.remove(_profileKey);
  }

  Future<void> _persistProfile(UserProfileModel user) async {
    await _localStorageService.write(_usernameKey, user.username);
    await _localStorageService.write(_profileKey, jsonEncode(user.toJson()));
  }
}
