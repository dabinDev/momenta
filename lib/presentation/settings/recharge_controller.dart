import 'package:get/get.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../data/api/api_service.dart';
import '../../data/models/recharge_order_model.dart';
import '../../data/models/recharge_product_model.dart';
import '../auth/auth_controller.dart';

class RechargeController extends GetxController {
  RechargeController()
      : _apiService = Get.find<ApiService>(),
        authController = Get.find<AuthController>();

  final ApiService _apiService;
  final AuthController authController;

  final RxBool isLoading = false.obs;
  final RxString creatingPackageCode = ''.obs;
  final RxString selectedPayMethod = 'wechat'.obs;
  final RxList<RechargeProductModel> products = <RechargeProductModel>[].obs;
  final RxList<RechargeOrderModel> orders = <RechargeOrderModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    refreshAll();
  }

  bool isCreating(String packageCode) =>
      creatingPackageCode.value == packageCode;

  bool methodEnabled(String method) {
    final user = authController.currentUser.value;
    if (user == null || !user.rechargeEnabled) {
      return false;
    }
    switch (method) {
      case 'wechat':
        return user.wechatPayEnabled;
      case 'alipay':
        return user.alipayPayEnabled;
      default:
        return false;
    }
  }

  Future<void> refreshAll() async {
    isLoading.value = true;
    try {
      if (authController.isLoggedIn) {
        await authController.refreshCurrentUser(silent: true);
      }
      final user = authController.currentUser.value;
      if (user == null || !user.pointsEnabled || !user.rechargeEnabled) {
        products.clear();
        orders.clear();
        return;
      }
      final List<String> enabledMethods = <String>[
        if (user.wechatPayEnabled) 'wechat',
        if (user.alipayPayEnabled) 'alipay',
      ];
      if (!enabledMethods.contains(selectedPayMethod.value)) {
        selectedPayMethod.value =
            enabledMethods.isEmpty ? '' : enabledMethods.first;
      }
      final List<dynamic> result = await Future.wait<dynamic>(<Future<dynamic>>[
        _apiService.fetchRechargeProducts(),
        _apiService.fetchRechargeOrders(page: 1, pageSize: 20),
      ]);
      products.assignAll(result[0] as List<RechargeProductModel>);
      orders.assignAll(result[1] as List<RechargeOrderModel>);
    } catch (error) {
      SnackbarHelper.error(
        AppException.resolveMessage(error, fallback: '加载充值信息失败'),
      );
    } finally {
      isLoading.value = false;
    }
  }

  void selectPayMethod(String method) {
    if (!methodEnabled(method)) {
      SnackbarHelper.info('当前未开启该支付方式');
      return;
    }
    selectedPayMethod.value = method;
  }

  Future<void> createOrder(RechargeProductModel product) async {
    if (!product.available) {
      SnackbarHelper.info(product.disabledReason.isNotEmpty
          ? product.disabledReason
          : '当前套餐暂不可购买');
      return;
    }
    if (selectedPayMethod.value.trim().isEmpty ||
        !methodEnabled(selectedPayMethod.value)) {
      SnackbarHelper.info('请先选择可用的支付方式');
      return;
    }

    creatingPackageCode.value = product.code;
    try {
      final RechargeOrderModel order = await _apiService.createRechargeOrder(
        packageCode: product.code,
        payMethod: selectedPayMethod.value,
      );
      orders.removeWhere(
          (RechargeOrderModel item) => item.orderNo == order.orderNo);
      orders.insert(0, order);
      SnackbarHelper.success(
        order.paymentHint.trim().isNotEmpty
            ? order.paymentHint
            : '充值订单已创建，请等待管理员确认到账',
      );
      await refreshAll();
    } catch (error) {
      SnackbarHelper.error(
        AppException.resolveMessage(error, fallback: '创建充值订单失败'),
      );
    } finally {
      creatingPackageCode.value = '';
    }
  }
}
