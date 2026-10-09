import 'dart:async';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../core/constants/app_constants.dart';

/// How the phone is physically held, read from the accelerometer.
///
/// The app is locked to portrait, so the camera plugin always reports
/// portraitUp and always captures with rotation 0, whatever the user does.
class OrientationService {
  StreamSubscription<AccelerometerEvent>? _subscription;
  DeviceOrientation _current = DeviceOrientation.portraitUp;

  DeviceOrientation get current => _current;

  void start() {
    _subscription ??= accelerometerEventStream(
      samplingPeriod: const Duration(
        milliseconds: AppConstants.orientationSampleMs,
      ),
    ).listen(_onReading);
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  void _onReading(AccelerometerEvent event) {
    final x = event.x;
    final y = event.y;
    if (max(x.abs(), y.abs()) < AppConstants.orientationMinTilt) return;

    final DeviceOrientation held;
    if (y.abs() >= x.abs()) {
      held = y > 0
          ? DeviceOrientation.portraitUp
          : DeviceOrientation.portraitDown;
    } else {
      held = x > 0
          ? DeviceOrientation.landscapeLeft
          : DeviceOrientation.landscapeRight;
    }
    if (held == _current) return;

    final sameAxis = _isPortrait(held) == _isPortrait(_current);
    final lead = _isPortrait(held) ? y.abs() - x.abs() : x.abs() - y.abs();
    if (sameAxis || lead > AppConstants.orientationHysteresis) _current = held;
  }

  bool _isPortrait(DeviceOrientation orientation) {
    return orientation == DeviceOrientation.portraitUp ||
        orientation == DeviceOrientation.portraitDown;
  }
}
