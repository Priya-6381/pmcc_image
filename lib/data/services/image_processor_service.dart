import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/date_time_util.dart';

enum _Outcome { saved, tooLarge, corrupt }

class _Encoded {
  final Uint8List bytes;
  final int width;
  final int height;

  const _Encoded(this.bytes, this.width, this.height);
}

class ImageProcessorService {
  Future<File> process(
    File source,
    DateTime capturedAt,
    DeviceOrientation orientation,
  ) async {
    final tempDir = await getTemporaryDirectory();
    final outputPath =
        '${tempDir.path}/${AppStrings.filePrefix}'
        '${DateTimeUtil.fileStamp(capturedAt)}${AppStrings.fileExtension}';
    final request = _ProcessRequest(
      sourcePath: source.path,
      outputPath: outputPath,
      rotationDegrees: _rotationFor(orientation),
      lines: [
        AppStrings.watermarkLabel,
        DateTimeUtil.watermarkStamp(capturedAt),
      ],
    );

    final _Outcome outcome;
    try {
      outcome = await compute(_processImage, request);
    } catch (_) {
      throw const AppException(AppStrings.processFailed);
    }
    switch (outcome) {
      case _Outcome.saved:
        return File(outputPath);
      case _Outcome.tooLarge:
        throw const AppException(AppStrings.sizeLimitFailed);
      case _Outcome.corrupt:
        throw const AppException(AppStrings.processFailed);
    }
  }
}

/// Degrees clockwise that turn a photo taken with the phone held this way
/// (the camera always saves it as if the phone were upright) upright.
int _rotationFor(DeviceOrientation orientation) {
  switch (orientation) {
    case DeviceOrientation.portraitUp:
      return AppConstants.portraitUpRotationDegrees;
    case DeviceOrientation.landscapeLeft:
      return AppConstants.landscapeLeftRotationDegrees;
    case DeviceOrientation.landscapeRight:
      return AppConstants.landscapeRightRotationDegrees;
    case DeviceOrientation.portraitDown:
      return AppConstants.portraitDownRotationDegrees;
  }
}

class _ProcessRequest {
  final String sourcePath;
  final String outputPath;
  final int rotationDegrees;
  final List<String> lines;

  const _ProcessRequest({
    required this.sourcePath,
    required this.outputPath,
    required this.rotationDegrees,
    required this.lines,
  });
}

const _hardLimitBytes = AppConstants.maxFileSizeKb * AppConstants.bytesPerKb;

Future<_Outcome> _processImage(_ProcessRequest request) async {
  final decoded = await img.decodeImageFile(request.sourcePath);
  if (decoded == null) throw const FormatException('Unsupported image');

  final source = _Source(decoded, request.lines, request.rotationDegrees);
  final file = File(request.outputPath);
  var targetKb = AppConstants.maxTargetKb;

  for (var retry = 0; retry <= AppConstants.maxTargetRetries; retry++) {
    final encoded = _encodeWithinLimit(
      source,
      targetKb * AppConstants.bytesPerKb,
    );
    if (encoded == null) break;

    await file.writeAsBytes(encoded.bytes, flush: true);
    if (!await _isIntact(file, encoded)) {
      await _delete(file);
      return _Outcome.corrupt;
    }
    if (await file.length() <= _hardLimitBytes) return _Outcome.saved;

    targetKb -= AppConstants.retryTargetStepKb;
  }

  await _delete(file);
  return _Outcome.tooLarge;
}

Future<void> _delete(File file) async {
  if (await file.exists()) await file.delete();
}

Future<bool> _isIntact(File file, _Encoded expected) async {
  if (await file.length() != expected.bytes.length) return false;
  final check = await img.decodeJpgFile(file.path);
  return check != null &&
      check.width == expected.width &&
      check.height == expected.height;
}

/// The decoded camera photo, kept in sensor orientation so a full-size
/// rotation copy is never made. Orientation is applied to each resized
/// render instead, which gives the same pixels for far less memory and time.
class _Source {
  final img.Image pixels;
  final int orientation;
  final img.Image watermark;
  final int rotationDegrees;

  _Source(this.pixels, List<String> lines, this.rotationDegrees)
    : orientation = pixels.exif.imageIfd.orientation ?? 1,
      watermark = _buildWatermark(lines) {
    pixels.exif.imageIfd.orientation = null;
  }

  int get longSide => max(pixels.width, pixels.height);

  img.Image _turn(img.Image image) {
    if (rotationDegrees != 0) {
      return img.copyRotate(image, angle: rotationDegrees);
    }
    if (image.width <= image.height) return image;
    return img.copyRotate(image, angle: AppConstants.landscapeRotationDegrees);
  }

  img.Image resized(double scale) {
    if (scale >= 1) return img.Image.from(pixels);
    return _averageResize(
      pixels,
      max(1, (pixels.width * scale).round()),
      max(1, (pixels.height * scale).round()),
    );
  }

  /// The final picture: resized once from the original, turned upright for the
  /// way the phone was held, without metadata, with the watermark drawn last.
  /// A photo taken with the phone held upright that is still wider than tall
  /// is turned into portrait. Turning happens on the already downscaled copy,
  /// so it costs almost nothing.
  img.Image render(double scale) {
    final resized = this.resized(scale);
    resized.exif.imageIfd.orientation = orientation;
    final upright = img.bakeOrientation(resized);
    final image = _turn(upright);
    image.exif = img.ExifData();
    _applyWatermark(image, watermark);
    return image;
  }
}

/// Same box average as `img.copyResize` with [img.Interpolation.average], but
/// read straight from the byte buffer. The package version goes through a
/// pixel object per source pixel, which takes seconds on a 12 MP photo.
img.Image _averageResize(img.Image src, int width, int height) {
  final channels = src.numChannels;
  final input = src.toUint8List();
  final dst = img.Image(width: width, height: height, numChannels: channels);
  final output = dst.toUint8List();
  final dx = src.width / width;
  final dy = src.height / height;
  final sums = Uint32List(channels);

  final xStart = List<int>.generate(width, (x) => (x * dx).toInt());
  final xEnd = List<int>.generate(width, (x) {
    final end = ((x + 1) * dx).toInt();
    return min(end == xStart[x] ? end + 1 : end, src.width);
  });

  var out = 0;
  for (var y = 0; y < height; y++) {
    final y1 = (y * dy).toInt();
    var y2 = ((y + 1) * dy).toInt();
    if (y2 == y1) y2++;
    y2 = min(y2, src.height);

    for (var x = 0; x < width; x++) {
      sums.fillRange(0, channels, 0);
      var count = 0;
      for (var sy = y1; sy < y2; sy++) {
        var i = (sy * src.width + xStart[x]) * channels;
        for (var sx = xStart[x]; sx < xEnd[x]; sx++, count++) {
          for (var c = 0; c < channels; c++) {
            sums[c] += input[i++];
          }
        }
      }
      final inv = 1.0 / count;
      for (var c = 0; c < channels; c++) {
        output[out++] = (sums[c] * inv).toInt();
      }
    }
  }
  return dst;
}

/// Predicts JPEG size from two cheap encodes of a small copy of the photo, so
/// the real encodes (the slow part) only happen near the final size.
/// bytes ~ pixels ^ jpegSizeExponent, and grows by a constant factor per
/// quality point. Every prediction is still confirmed by a real encode.
class _SizeModel {
  final double scale;
  final double bytesAtMin;
  final double perQuality;

  const _SizeModel(this.scale, this.bytesAtMin, this.perQuality);

  factory _SizeModel.measure(_Source source) {
    final scale = min(1.0, AppConstants.estimateLongSidePx / source.longSide);
    final sample = source.resized(scale);
    final low = img.encodeJpg(sample, quality: AppConstants.minJpegQuality);
    final high = img.encodeJpg(sample, quality: AppConstants.startJpegQuality);
    final growth =
        log(high.length / low.length) /
        (AppConstants.startJpegQuality - AppConstants.minJpegQuality);
    return _SizeModel(
      scale,
      low.length.toDouble(),
      growth.isFinite && growth > 0
          ? growth
          : AppConstants.defaultQualityGrowth,
    );
  }

  double _qualityFactor(int quality) =>
      exp(perQuality * (quality - AppConstants.minJpegQuality));

  double _pixelFactor(double scale) =>
      pow(scale / this.scale, 2 * AppConstants.jpegSizeExponent).toDouble();

  double bytesAt(double scale, int quality) =>
      bytesAtMin * _pixelFactor(scale) * _qualityFactor(quality);

  double scaleFor(int quality, int limit) {
    final ratio = limit / (bytesAtMin * _qualityFactor(quality));
    return scale * pow(ratio, 1 / (2 * AppConstants.jpegSizeExponent));
  }

  int qualityFor(double scale, int limit) {
    final room = limit / bytesAt(scale, AppConstants.minJpegQuality);
    return (AppConstants.minJpegQuality + log(room) / perQuality).floor();
  }

  /// Same curve, re-anchored on a real encode.
  _SizeModel anchored(double scale, int quality, int bytes) {
    return _SizeModel(
      this.scale,
      bytes / (_pixelFactor(scale) * _qualityFactor(quality)),
      perQuality,
    );
  }
}

_Encoded? _encodeWithinLimit(_Source source, int limit) {
  final floor = min(1.0, AppConstants.minLongSidePx / source.longSide);

  int allowedQuality(int wanted) =>
      wanted.clamp(AppConstants.minJpegQuality, AppConstants.startJpegQuality);

  // The first guess aims a little under the limit, so it usually fits.
  final aimLimit = (limit * AppConstants.planMargin).round();
  var model = _SizeModel.measure(source);
  var scale = min(
    1.0,
    max(floor, model.scaleFor(AppConstants.aimJpegQuality, aimLimit)),
  );
  var quality = allowedQuality(model.qualityFor(scale, aimLimit));
  img.Image? image;

  for (var i = 0; i < AppConstants.modelEncodes; i++) {
    image ??= source.render(scale);
    final bytes = img.encodeJpg(image, quality: quality);
    if (bytes.length <= limit) {
      return _Encoded(bytes, image.width, image.height);
    }

    model = model.anchored(scale, quality, bytes.length);
    final lower = min(quality, model.qualityFor(scale, limit)) - 1;
    if (lower == allowedQuality(lower)) {
      quality = lower;
      continue;
    }

    final smaller = model.scaleFor(AppConstants.aimJpegQuality, limit);
    final next = max(floor, min(scale, smaller) * AppConstants.scaleMargin);
    if (next >= scale) break;
    scale = next;
    quality = allowedQuality(model.qualityFor(scale, limit));
    image = null;
  }

  return _shrinkUntilFits(source, scale, limit, floor);
}

/// Slow but sure: shrink in fixed steps and binary-search the quality.
_Encoded? _shrinkUntilFits(
  _Source source,
  double from,
  int limit,
  double floor,
) {
  var scale = from;
  while (true) {
    scale = max(floor, scale * AppConstants.scaleStep);
    final image = source.render(scale);
    final found = _highestQuality(image, AppConstants.minJpegQuality, limit);
    if (found != null || scale <= floor) return found;
  }
}

/// Binary search for the highest quality in [low, startJpegQuality] that fits.
_Encoded? _highestQuality(img.Image image, int low, int limit) {
  var high = AppConstants.startJpegQuality;
  _Encoded? best;
  while (low <= high) {
    final quality = (low + high + 1) ~/ 2;
    final bytes = img.encodeJpg(image, quality: quality);
    if (bytes.length <= limit) {
      best = _Encoded(bytes, image.width, image.height);
      low = quality + 1;
    } else {
      high = quality - 1;
    }
  }
  return best;
}

img.Image _buildWatermark(List<String> lines) {
  final font = img.arial48;
  final outline = AppConstants.watermarkOutlineSize;
  final textColor = _toImgColor(AppColors.watermarkText);
  final outlineColor = _toImgColor(AppColors.watermarkOutline);

  final textWidth = lines
      .map((line) => _textWidth(font, line))
      .reduce((a, b) => a > b ? a : b);
  final overlay = img.Image(
    width: textWidth + outline * 2,
    height: font.lineHeight * lines.length + outline * 2,
    numChannels: 4,
  );

  for (var i = 0; i < lines.length; i++) {
    final y = outline + i * font.lineHeight;
    for (var dx = -outline; dx <= outline; dx += outline) {
      for (var dy = -outline; dy <= outline; dy += outline) {
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

  return overlay;
}

void _applyWatermark(img.Image image, img.Image overlay) {
  final width = (image.width * AppConstants.watermarkWidthRatio).round();
  final height = max(1, (overlay.height * width / overlay.width).round());
  final scaled = width < overlay.width
      ? _averageResize(overlay, width, height)
      : img.copyResize(
          overlay,
          width: width,
          height: height,
          interpolation: img.Interpolation.linear,
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
