import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';

class CaptureButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const CaptureButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: AppSizes.captureButtonSize,
        height: AppSizes.captureButtonSize,
        padding: const EdgeInsets.all(AppSizes.captureButtonRingWidth),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.captureButtonRing,
            width: AppSizes.captureButtonRingWidth,
          ),
        ),
        child: const DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.captureButton,
          ),
        ),
      ),
    );
  }
}
