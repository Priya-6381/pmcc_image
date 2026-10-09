import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/date_time_util.dart';

class ImageProcessorService {
  Future<File> process(File source, DateTime capturedAt) async {
    final tempDir = await getTemporaryDirectory();
    final outputPath = '${tempDir.path}/${AppStrings.filePrefix}'
        '${DateTimeUtil.fileStamp(capturedAt)}${AppStrings.fileExtension}';
    final request = _ProcessRequest(
      sourcePath: source.path,
      outputPath: outputPath,
      lines: [
        AppStrings.watermarkLabel,
        DateTimeUtil.watermarkStamp(capturedAt),
      ],
    );

    final bool written;
    try {
      written = await compute(_processImage, request);
    } catch (_) {
      throw const AppException(AppStrings.processFailed);
    }
    if (!written) throw const AppException(AppStrings.sizeLimitFailed);
    return File(outputPath);
  }
}

class _ProcessRequest {
  final String sourcePath;
  final String outputPath;
  final List<String> lines;

  const _ProcessRequest({
    required this.sourcePath,
    required this.outputPath,
    required this.lines,
  });
}

Future<bool> _processImage(_ProcessRequest request) async {
  final decoded = await img.decodeImageFile(request.sourcePath);
  if (decoded == null) throw const FormatException('Unsupported image');

  final oriented = img.bakeOrientation(decoded);
  final bytes = _encodeWithinLimit(oriented, request.lines);
  if (bytes == null) return false;

  await File(request.outputPath).writeAsBytes(bytes, flush: true);
  return true;
}

Uint8List? _encodeWithinLimit(img.Image oriented, List<String> lines) {
  final limit = AppConstants.maxFileSizeKb * AppConstants.bytesPerKb;

  for (final side in AppConstants.imageSideSteps) {
    final image = _limitSize(oriented, side);
    _drawWatermark(image, lines);

    for (var quality = AppConstants.jpegQuality;
        quality >= AppConstants.minJpegQuality;
        quality -= AppConstants.jpegQualityStep) {
      final bytes = img.encodeJpg(image, quality: quality);
      if (bytes.length <= limit) return bytes;
    }
  }
  return null;
}

img.Image _limitSize(img.Image image, int maxSide) {
  final longSide = image.width > image.height ? image.width : image.height;
  if (longSide <= maxSide) return image.clone();

  return image.width >= image.height
      ? img.copyResize(image, width: maxSide)
      : img.copyResize(image, height: maxSide);
}

void _drawWatermark(img.Image image, List<String> lines) {
  final font = img.arial48;
  final outline = AppConstants.watermarkOutlineSize;
  final textColor = _toImgColor(AppColors.watermarkText);
  final outlineColor = _toImgColor(AppColors.watermarkOutline);

  final textWidth = lines.map((line) => _textWidth(font, line)).reduce(
        (a, b) => a > b ? a : b,
      );
  final overlay = img.Image(
    width: textWidth + outline * 2,
    height: font.lineHeight * lines.length + outline * 2,
    numChannels: 4,
  );

  for (var i = 0; i < lines.length; i++) {
    final y = outline + i * font.lineHeight;
    for (var dx = -outline; dx <= outline; dx++) {
      for (var dy = -outline; dy <= outline; dy++) {
        if (dx == 0 && dy == 0) continue;
        img.drawString(
          overlay,
          lines[i],
          font: font,
          x: outline + dx,
          y: y + dy,
          color: outlineColor,
        );
      }
    }
    img.drawString(
      overlay,
      lines[i],
      font: font,
      x: outline,
      y: y,
      color: textColor,
    );
  }

  final targetWidth = (image.width * AppConstants.watermarkWidthRatio).round();
  final scaled = img.copyResize(
    overlay,
    width: targetWidth,
    interpolation: img.Interpolation.cubic,
  );
  final margin = (image.width * AppConstants.watermarkMarginRatio).round();

  img.compositeImage(
    image,
    scaled,
    dstX: margin,
    dstY: image.height - scaled.height - margin,
  );
}

int _textWidth(img.BitmapFont font, String text) {
  return text.split('').fold(0, (sum, ch) => sum + font.characterXAdvance(ch));
}

img.Color _toImgColor(Color color) {
  final value = color.toARGB32();
  return img.ColorRgba8(
    (value >> 16) & 0xFF,
    (value >> 8) & 0xFF,
    value & 0xFF,
    (value >> 24) & 0xFF,
  );
}
