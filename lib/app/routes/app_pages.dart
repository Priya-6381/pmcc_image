import 'package:get/get.dart';

import '../../modules/camera/view/camera_view.dart';
import '../../modules/home/view/home_view.dart';
import '../bindings/camera_binding.dart';
import '../bindings/home_binding.dart';
import 'app_routes.dart';

class AppPages {
  AppPages._();

  static final pages = <GetPage<dynamic>>[
    GetPage(
      name: AppRoutes.home,
      page: () => const HomeView(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: AppRoutes.camera,
      page: () => const CameraView(),
      binding: CameraBinding(),
    ),
  ];
}
