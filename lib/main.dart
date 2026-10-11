import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app_config.dart';
import 'model/deal_model.dart';
import 'repository/deal_repo.dart';
import 'repository/order_repo.dart';
import 'repository/store_repo.dart';
import 'routes/routes.dart';
import 'service/analytics_service.dart';
import 'service/cart_service.dart';
import 'service/clock_service.dart';
import 'service/fake_api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDependencies();
  runApp(const RescuApp());
}

Future<void> initDependencies() async {
  await Get.putAsync(() => FakeApiService().init(), permanent: true);
  Get.put(AnalyticsService(), permanent: true);
  // Registered before CartService: the cart needs the clock to refuse flash
  // deals whose sale is over, and to remove them from the bag when it ends.
  Get.put(ClockService(), permanent: true);
  Get.put(
    CartService(
      clock: Get.find(),
      onFlashSaleExpired: showFlashSaleExpiredNotice,
    ),
    permanent: true,
  );
  Get.lazyPut(() => DealRepo(api: Get.find()), fenix: true);
  Get.lazyPut(() => StoreRepo(api: Get.find()), fenix: true);
  Get.lazyPut(() => OrderRepo(api: Get.find()), fenix: true);
}

/// Tells the user that [deal] was taken out of their bag because its flash
/// sale ended. A snackbar shows on top of whichever screen is open.
void showFlashSaleExpiredNotice(DealModel deal) {
  Get.snackbar(
    'Flash sale ended',
    '${deal.name} was removed from your bag',
    snackPosition: SnackPosition.BOTTOM,
    duration: const Duration(seconds: 4),
  );
}

class RescuApp extends StatelessWidget {
  const RescuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppConfig.theme,
      initialRoute: Routes.home,
      getPages: Routes.pages,
    );
  }
}
