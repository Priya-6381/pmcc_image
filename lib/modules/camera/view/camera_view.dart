import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../controller/camera_screen_controller.dart';
import '../widgets/camera_message.dart';
import '../widgets/capture_button.dart';
import '../widgets/capture_result_panel.dart';

class CameraView extends GetView<CameraScreenController> {
  const CameraView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.cameraTitle)),
      body: Obx(() {
        final result = controller.result.value;
        if (result != null) {
          return CaptureResultPanel(
            result: result,
            onCancel: controller.onCancel,
            onDone: Get.back,
          );
        }
        return _buildCamera();
      }),
    );
  }

  Widget _buildCamera() {
    switch (controller.status.value) {
      case CameraStatus.initializing:
        return _buildLoading(AppStrings.preparingCamera);
      case CameraStatus.permissionDenied:
        return CameraMessage(
          message: controller.errorMessage.value,
          actionLabel: AppStrings.grantPermission,
          onAction: controller.startCamera,
        );
      case CameraStatus.permissionPermanentlyDenied:
        return CameraMessage(
          message: controller.errorMessage.value,
          actionLabel: AppStrings.openSettings,
          onAction: controller.openSettings,
        );
      case CameraStatus.failed:
        return CameraMessage(
          message: controller.errorMessage.value,
          actionLabel: AppStrings.retry,
          onAction: controller.startCamera,
        );
      case CameraStatus.ready:
        return _buildPreview();
    }
  }

  Widget _buildPreview() {
    final camera = controller.previewController!;
    final busyMessage = controller.busyMessage.value;

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AppColors.cameraBackground),
        Center(child: CameraPreview(camera)),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(
              bottom: AppSizes.captureButtonBottomMargin,
            ),
            child: CaptureButton(
              onPressed: busyMessage == null ? controller.capture : null,
            ),
          ),
        ),
        if (busyMessage != null) _buildBusyOverlay(busyMessage),
      ],
    );
  }

  Widget _buildBusyOverlay(String message) {
    return ColoredBox(
      color: AppColors.overlay,
      child: _buildLoading(message, color: AppColors.onPrimary),
    );
  }

  Widget _buildLoading(String message, {Color? color}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: color),
          const SizedBox(height: AppSizes.gapL),
          Text(message, style: TextStyle(color: color)),
        ],
      ),
    );
  }
}
