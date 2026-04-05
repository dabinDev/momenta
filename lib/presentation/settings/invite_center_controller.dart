import 'package:get/get.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../data/api/api_service.dart';
import '../../data/models/invite_overview_model.dart';

class InviteCenterController extends GetxController {
  InviteCenterController() : _apiService = Get.find<ApiService>();

  final ApiService _apiService;

  final RxBool isLoading = false.obs;
  final Rxn<InviteOverviewModel> overview = Rxn<InviteOverviewModel>();

  @override
  void onInit() {
    super.onInit();
    refreshOverview();
  }

  Future<void> refreshOverview() async {
    isLoading.value = true;
    try {
      overview.value = await _apiService.fetchInviteOverview();
    } catch (error) {
      SnackbarHelper.error(
        AppException.resolveMessage(error, fallback: '加载邀请信息失败'),
      );
    } finally {
      isLoading.value = false;
    }
  }
}
