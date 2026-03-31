import '../../data/models/user_profile_model.dart';

abstract class AuthRepository {
  Future<UserProfileModel?> restoreLocalUser();
  Future<UserProfileModel> login({
    required String username,
    required String password,
  });
  Future<UserProfileModel> refreshCurrentUser();
  Future<void> forgotPassword({
    required String username,
    required String email,
    required String newPassword,
  });
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  });
  Future<UserProfileModel> updateCurrentProfile({
    required String email,
    required String alias,
    required String phone,
  });
  Future<void> logout();
}
