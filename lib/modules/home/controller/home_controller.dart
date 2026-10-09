import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';

class HomeController extends GetxController {
  void openCamera() => Get.toNamed(AppRoutes.camera);
}
