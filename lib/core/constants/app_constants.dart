class AppConstants {
  AppConstants._();

  static const maxFileSizeKb = 200;
  static const maxTargetKb = 195;
  static const retryTargetStepKb = 5;
  static const maxTargetRetries = 2;
  static const bytesPerKb = 1024;
  static const startJpegQuality = 95;
  static const minJpegQuality = 70;
  static const scaleStep = 0.9;
  static const minLongSidePx = 640;
  static const aimJpegQuality = 75;
  static const estimateLongSidePx = 480;
  static const jpegSizeExponent = 0.8;
  static const defaultQualityGrowth = 0.05;
  static const scaleMargin = 0.98;
  static const planMargin = 0.9;
  static const modelEncodes = 3;

  static const focusWarmupMs = 2000;
  static const focusSettleMs = 250;
  static const focusRingMs = 1200;

  static const orientationSampleMs = 100;
  static const orientationMinTilt = 4.0;
  static const orientationHysteresis = 1.5;

  static const portraitUpRotationDegrees = 0;
  static const landscapeLeftRotationDegrees = 270;
  static const landscapeRightRotationDegrees = 90;
  static const portraitDownRotationDegrees = 180;
  static const landscapeRotationDegrees = 90;

  static const watermarkWidthRatio = 0.4;
  static const watermarkMarginRatio = 0.03;
  static const watermarkOutlineSize = 2;
}
