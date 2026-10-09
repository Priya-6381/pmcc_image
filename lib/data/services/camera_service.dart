import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/date_time_util.dart';
import 'orientation_service.dart';

class RawPhoto {
  final File file;
  final DeviceOrientation orientation;

  const RawPhoto({required this.file, required this.orientation});
}

class CameraService {
  static const _presets = [ResolutionPreset.veryHigh, ResolutionPreset.high];

  final _orientationService = OrientationService();
  CameraController? _controller;
  DateTime _readyAt = DateTime.now();

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

    final controller = await _open(_mainCamera(cameras));
    _controller = controller;
    _orientationService.start();
    _readyAt = DateTime.now().add(
      const Duration(milliseconds: AppConstants.focusWarmupMs),
    );
    return controller;
  }

  /// The main back camera: the first back lens that reports itself as a
  /// standard wide lens, else the first back lens, else any camera.
  CameraDescription _mainCamera(List<CameraDescription> cameras) {
    final back = cameras
        .where((item) => item.lensDirection == CameraLensDirection.back)
        .toList();
    if (back.isEmpty) return cameras.first;
    return back.firstWhere(
      (item) => item.lensType == CameraLensType.wide,
      orElse: () => back.first,
    );
  }

  Future<CameraController> _open(CameraDescription camera) async {
    for (final preset in _presets) {
      final controller = CameraController(
        camera,
        preset,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      try {
        await controller.initialize();
        await _useAutoModes(controller);
        return controller;
      } on CameraException {
        await controller.dispose();
      }
    }
    throw const AppException(AppStrings.cameraInitFailed);
  }

  Future<void> _useAutoModes(CameraController controller) async {
    await _ignoreUnsupported(() => controller.setFocusMode(FocusMode.auto));
    await _ignoreUnsupported(
      () => controller.setExposureMode(ExposureMode.auto),
    );
    await _ignoreUnsupported(() => controller.setFlashMode(FlashMode.auto));
  }

  /// Focuses and meters on [point], given as 0 to 1 fractions of the preview.
  Future<void> focusAt(Offset point) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (controller.value.focusPointSupported) {
      await _ignoreUnsupported(() => controller.setFocusPoint(point));
    }
    if (controller.value.exposurePointSupported) {
      await _ignoreUnsupported(() => controller.setExposurePoint(point));
    }
  }

  /// Continuous autofocus needs a moment after the camera opens, and the phone
  /// a moment to stop shaking after the tap. Shooting before that gives a
  /// blurry raw photo that no processing can fix.
  Future<void> _waitUntilSteady() async {
    final warmup = _readyAt.difference(DateTime.now());
    const settle = Duration(milliseconds: AppConstants.focusSettleMs);
    await Future<void>.delayed(warmup > settle ? warmup : settle);
  }

  Future<void> _ignoreUnsupported(Future<void> Function() action) async {
    try {
      await action();
    } on CameraException {
      return;
    }
  }

  Future<RawPhoto> captureToTemp(DateTime capturedAt) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      throw const AppException(AppStrings.cameraUnavailable);
    }

    try {
      await _waitUntilSteady();
      final orientation = _orientationService.current;
      final shot = await controller.takePicture();
      final tempDir = await getTemporaryDirectory();
      final rawPath =
          '${tempDir.path}/${AppStrings.rawFilePrefix}'
          '${DateTimeUtil.fileStamp(capturedAt)}${AppStrings.fileExtension}';
      await shot.saveTo(rawPath);
      await File(shot.path).delete();
      return RawPhoto(file: File(rawPath), orientation: orientation);
    } on CameraException {
      throw const AppException(AppStrings.captureFailed);
    } on FileSystemException {
      throw const AppException(AppStrings.captureFailed);
    }
  }

  Future<void> dispose() async {
    await _orientationService.stop();
    final controller = _controller;
    _controller = null;
    await controller?.dispose();
  }
}
