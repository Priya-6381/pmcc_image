import 'dart:io';

import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/constants/app_strings.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/date_time_util.dart';

class CameraService {
  CameraController? _controller;

  CameraController? get controller => _controller;

  Future<CameraController> initialize() async {
    await dispose();

    final List<CameraDescription> cameras;
    try {
      cameras = await availableCameras();
    } on CameraException {
      throw const AppException(AppStrings.cameraUnavailable);
    }
    if (cameras.isEmpty) throw const AppException(AppStrings.cameraUnavailable);

    final camera = cameras.firstWhere(
      (item) => item.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await controller.initialize();
    } on CameraException {
      await controller.dispose();
      throw const AppException(AppStrings.cameraInitFailed);
    }

    _controller = controller;
    return controller;
  }

  Future<File> captureToTemp(DateTime capturedAt) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      throw const AppException(AppStrings.cameraUnavailable);
    }

    try {
      final shot = await controller.takePicture();
      final tempDir = await getTemporaryDirectory();
      final rawPath = '${tempDir.path}/${AppStrings.rawFilePrefix}'
          '${DateTimeUtil.fileStamp(capturedAt)}${AppStrings.fileExtension}';
      await shot.saveTo(rawPath);
      await File(shot.path).delete();
      return File(rawPath);
    } on CameraException {
      throw const AppException(AppStrings.captureFailed);
    } on FileSystemException {
      throw const AppException(AppStrings.captureFailed);
    }
  }

  Future<void> dispose() async {
    final controller = _controller;
    _controller = null;
    await controller?.dispose();
  }
}
