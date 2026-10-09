import 'package:get/get.dart';

import '../../data/services/camera_service.dart';
import '../../data/services/image_processor_service.dart';
import '../../data/services/storage_service.dart';
import '../../modules/camera/controller/camera_screen_controller.dart';

class CameraBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(CameraService.new);
    Get.lazyPut(ImageProcessorService.new);
    Get.lazyPut(StorageService.new);
    Get.lazyPut(
      () => CameraScreenController(
        cameraService: Get.find(),
        imageProcessor: Get.find(),
        storageService: Get.find(),
      ),
    );
  }
}
