import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';

class VcCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? borderColor;
  final EdgeInsetsGeometry? padding;

  const VcCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderColor,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding ?? const EdgeInsets.all(AppConstants.paddingMD),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusLG),
          border: borderColor != null
              ? Border.all(
                  color: AppColors.isHighContrast
                      ? AppColors.cardBorder
                      : borderColor!,
                  width: AppColors.isHighContrast ? 2 : 1.5,
                )
              : (AppColors.isHighContrast
                    ? Border.all(color: AppColors.cardBorder, width: 2)
                    : null),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: AppColors.isDark ? 0.3 : 0.05,
              ),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}
