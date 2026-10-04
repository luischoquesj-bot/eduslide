import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_text_styles.dart';

/// Tarjeta central de bienvenida de EduSlide.
/// Proporciona al docente un acceso rápido para comenzar una pizarra libre
/// o explorar los recursos didácticos de la clase.
/// Totalmente responsiva con cálculos porcentuales para proyectores, tablets y pantallas de diversas resoluciones.
class WelcomeCard extends StatelessWidget {
  final VoidCallback onStartWhiteboard;
  final VoidCallback onExploreMaterials;

  const WelcomeCard({
    super.key,
    required this.onStartWhiteboard,
    required this.onExploreMaterials,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screenWidth = media.size.width;
    final screenHeight = media.size.height;

    // Cálculos porcentuales dinámicos para layout horizontal
    final cardMaxWidth = (screenWidth * 0.65).clamp(320.0, 580.0);
    final cardMaxHeight = screenHeight * 0.84;
    final horizontalPadding = (screenWidth * 0.025).clamp(16.0, 28.0);
    final verticalPadding = (screenHeight * 0.025).clamp(12.0, 24.0);
    final iconSize = (screenHeight * 0.09).clamp(36.0, 56.0);
    final spacing = (screenHeight * 0.016).clamp(8.0, 16.0);

    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: cardMaxWidth,
          maxHeight: cardMaxHeight,
        ),
        margin: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.04,
          vertical: screenHeight * 0.03,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderHighlight, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.1),
              blurRadius: 36,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Insignia / Ícono principal escalable porcentualmente
                Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.secondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(math.max(10, iconSize * 0.28)),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.auto_stories_rounded,
                    size: iconSize * 0.55,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: spacing),

                // 2. Título principal escalable
                Text(
                  AppStrings.welcomeTitle,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.displayTitle.copyWith(
                    fontSize: (screenHeight * 0.042).clamp(17.0, 22.0),
                  ),
                ),
                SizedBox(height: spacing * 0.5),

                // 3. Subtítulo descriptivo para proyección
                Text(
                  AppStrings.welcomeSubtitle,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: (screenHeight * 0.026).clamp(11.5, 13.5),
                  ),
                ),
                SizedBox(height: spacing * 1.3),

                // 4. Dos botones de acción principales requeridos
                Wrap(
                  spacing: 14,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    // [1] Iniciar Pizarra Libre
                    ElevatedButton.icon(
                      onPressed: onStartWhiteboard,
                      icon: const Icon(Icons.draw_rounded, size: 18),
                      label: const Text(AppStrings.startFreeWhiteboard),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: const Color(0xFF0F172A),
                        padding: EdgeInsets.symmetric(
                          horizontal: (screenWidth * 0.02).clamp(16.0, 24.0),
                          vertical: (screenHeight * 0.02).clamp(10.0, 16.0),
                        ),
                        elevation: 4,
                        shadowColor: AppColors.primary.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: AppTextStyles.button.copyWith(
                          fontSize: (screenHeight * 0.026).clamp(12.0, 14.0),
                          color: const Color(0xFF0F172A),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    // [2] Explorar Materiales Didácticos
                    OutlinedButton.icon(
                      onPressed: onExploreMaterials,
                      icon: const Icon(Icons.folder_special_rounded, size: 18),
                      label: const Text(AppStrings.exploreMaterials),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.surfaceLight.withValues(alpha: 0.5),
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(
                          color: AppColors.borderHighlight,
                          width: 1.5,
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: (screenWidth * 0.02).clamp(16.0, 24.0),
                          vertical: (screenHeight * 0.02).clamp(10.0, 16.0),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: AppTextStyles.button.copyWith(
                          fontSize: (screenHeight * 0.026).clamp(12.0, 14.0),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
