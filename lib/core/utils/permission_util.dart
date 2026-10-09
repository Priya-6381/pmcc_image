import 'package:media_store_plus/media_store_plus.dart';
import 'package:permission_handler/permission_handler.dart';

enum PermissionOutcome { granted, denied, permanentlyDenied }

class PermissionUtil {
  PermissionUtil._();

  static const _lastLegacyStorageSdk = 29;

  static Future<PermissionOutcome> requestCamera() {
    return _request(Permission.camera);
  }

  static Future<PermissionOutcome> requestStorage() async {
    final sdk = await MediaStore().getPlatformSDKInt();
    if (sdk > _lastLegacyStorageSdk) return PermissionOutcome.granted;
    return _request(Permission.storage);
  }

  static Future<bool> openSettings() => openAppSettings();

  static Future<PermissionOutcome> _request(Permission permission) async {
    final status = await permission.request();
    if (status.isGranted) return PermissionOutcome.granted;
    if (status.isPermanentlyDenied) return PermissionOutcome.permanentlyDenied;
    return PermissionOutcome.denied;
  }
}
