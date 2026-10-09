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
      final expectedLength = await file.length();
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
      final path = '$folder/${info.name}';
      if (!await _matchesLength(path, expectedLength)) {
        await _discard(info.name);
        throw const AppException(AppStrings.saveFailed);
      }
      return SavedPhoto(name: info.name, path: path);
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException(AppStrings.saveFailed);
    }
  }

  Future<bool> _matchesLength(String path, int expected) async {
    final saved = File(path);
    return await saved.exists() && await saved.length() == expected;
  }

  Future<void> _discard(String name) async {
    try {
      await _mediaStore.deleteFile(
        fileName: name,
        dirType: DirType.download,
        dirName: DirName.download,
        relativePath: AppStrings.folderName,
      );
    } catch (_) {
      return;
    }
  }

  Future<void> _prepare() async {
    if (_ready) return;
    await MediaStore.ensureInitialized();
    MediaStore.appFolder = AppStrings.folderName;
    _ready = true;
  }
}
