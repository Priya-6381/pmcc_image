import 'dart:io';

import 'package:media_store_plus/media_store_plus.dart';

import '../../core/constants/app_strings.dart';
import '../../core/utils/app_exception.dart';

class SavedPhoto {
  final String name;
  final String path;

  const SavedPhoto({required this.name, required this.path});
}

class StorageService {
  final _mediaStore = MediaStore();
  bool _ready = false;

  Future<SavedPhoto> saveToDownloads(File file) async {
    try {
      await _prepare();
      final info = await _mediaStore.saveFile(
        tempFilePath: file.path,
        dirType: DirType.download,
        dirName: DirName.download,
        relativePath: AppStrings.folderName,
      );
      if (info == null) throw const AppException(AppStrings.saveFailed);

      final folder = DirType.download.fullPath(
        relativePath: AppStrings.folderName,
        dirName: DirName.download,
      );
      return SavedPhoto(name: info.name, path: '$folder/${info.name}');
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException(AppStrings.saveFailed);
    }
  }

  Future<void> _prepare() async {
    if (_ready) return;
    await MediaStore.ensureInitialized();
    MediaStore.appFolder = AppStrings.folderName;
    _ready = true;
  }
}
