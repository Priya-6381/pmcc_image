import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../controller/camera_screen_controller.dart';

class CaptureResultPanel extends StatelessWidget {
  final CaptureResult result;
  final VoidCallback onCancel;
  final VoidCallback onDone;

  const CaptureResultPanel({
    super.key,
    required this.result,
    required this.onCancel,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.contentPadding),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
              child: Image.memory(result.bytes, fit: BoxFit.contain),
            ),
          ),
          const SizedBox(height: AppSizes.gapL),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: AppColors.success),
              SizedBox(width: AppSizes.gapS),
              Text(
                AppStrings.savedSuccess,
                style: TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          // const SizedBox(height: 8),
          // Text(
          //   '${AppStrings.savedTo}: ${result.path}',
          //   textAlign: TextAlign.center,
          //   style: textTheme.bodyMedium?.copyWith(
          //     color: AppColors.textSecondary,
          //   ),
          // ),
          const SizedBox(height: AppSizes.gapL),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  child: const Text(AppStrings.cancel),
                ),
              ),
              const SizedBox(width: AppSizes.gapM),
              Expanded(
                child: ElevatedButton(
                  onPressed: onDone,
                  child: const Text(AppStrings.done),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
