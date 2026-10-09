import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/utils/permission_util.dart';
import '../../../data/services/camera_service.dart';
import '../../../data/services/image_processor_service.dart';
import '../../../data/services/storage_service.dart';

enum CameraStatus {
  initializing,
  ready,
  permissionDenied,
  permissionPermanentlyDenied,
  failed,
}

class CaptureResult {
  final Uint8List bytes;
  final String path;

  const CaptureResult({required this.bytes, required this.path});
}

class CameraScreenController extends GetxController {
  final CameraService _cameraService;
  final ImageProcessorService _imageProcessor;
  final StorageService _storageService;

  CameraScreenController({
    required this._cameraService,
    required this._imageProcessor,
    required this._storageService,
  });

  final status = CameraStatus.initializing.obs;
  final errorMessage = ''.obs;
  final busyMessage = RxnString();
  final result = Rxn<CaptureResult>();
  final focusRing = Rxn<Offset>();
  Timer? _focusRingTimer;

  CameraController? get previewController => _cameraService.controller;
  bool get isBusy => busyMessage.value != null;

  @override
  void onReady() {
    super.onReady();
    startCamera();
  }

  @override
  void onClose() {
    _focusRingTimer?.cancel();
    _cameraService.dispose();
    super.onClose();
  }

  Future<void> startCamera() async {
    status.value = CameraStatus.initializing;

    final permission = await PermissionUtil.requestCamera();
    switch (permission) {
      case PermissionOutcome.denied:
        status.value = CameraStatus.permissionDenied;
        errorMessage.value = AppStrings.cameraPermissionDenied;
        return;
      case PermissionOutcome.permanentlyDenied:
        status.value = CameraStatus.permissionPermanentlyDenied;
        errorMessage.value = AppStrings.cameraPermissionPermanentlyDenied;
        return;
      case PermissionOutcome.granted:
        break;
    }

    try {
      await _cameraService.initialize();
      status.value = CameraStatus.ready;
    } on AppException catch (e) {
      errorMessage.value = e.message;
      status.value = CameraStatus.failed;
    }
  }

  Future<void> openSettings() => PermissionUtil.openSettings();

  Future<void> capture() async {
    if (isBusy || status.value != CameraStatus.ready) return;

    final storagePermission = await PermissionUtil.requestStorage();
    if (storagePermission != PermissionOutcome.granted) {
      _showStoragePermissionError(storagePermission);
      return;
    }

    File? rawFile;
    File? processedFile;
    try {
      final capturedAt = DateTime.now();

      busyMessage.value = AppStrings.capturing;
      final raw = await _cameraService.captureToTemp(capturedAt);
      rawFile = raw.file;

      busyMessage.value = AppStrings.processing;
      processedFile = await _imageProcessor.process(
        raw.file,
        capturedAt,
        raw.orientation,
      );
      final bytes = await processedFile.readAsBytes();

      busyMessage.value = AppStrings.saving;
      final saved = await _storageService.saveToDownloads(processedFile);

      result.value = CaptureResult(bytes: bytes, path: saved.path);
    } on AppException catch (e) {
      _showError(e.message);
    } finally {
      await _deleteQuietly(rawFile);
      await _deleteQuietly(processedFile);
      busyMessage.value = null;
    }
  }

  Future<void> focusAt(Offset position, Size previewSize) async {
    if (isBusy || status.value != CameraStatus.ready) return;

    focusRing.value = position;
    _focusRingTimer?.cancel();
    _focusRingTimer = Timer(
      const Duration(milliseconds: AppConstants.focusRingMs),
      () => focusRing.value = null,
    );
    await _cameraService.focusAt(
      Offset(position.dx / previewSize.width, position.dy / previewSize.height),
    );
  }

  void onCancel() => Get.back();

  void _showStoragePermissionError(PermissionOutcome outcome) {
    if (outcome == PermissionOutcome.permanentlyDenied) {
      _showError(
        AppStrings.storagePermissionPermanentlyDenied,
        action: TextButton(
          onPressed: openSettings,
          child: const Text(
            AppStrings.openSettings,
            style: TextStyle(color: AppColors.onPrimary),
          ),
        ),
      );
      return;
    }
    _showError(AppStrings.storagePermissionDenied);
  }

  void _showError(String message, {TextButton? action}) {
    Get.snackbar(
      AppStrings.errorTitle,
      message,
      backgroundColor: AppColors.error,
      colorText: AppColors.onPrimary,
      mainButton: action,
      snackPosition: SnackPosition.TOP,
    );
  }

  Future<void> _deleteQuietly(File? file) async {
    if (file == null) return;
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      return;
    }
  }
}
