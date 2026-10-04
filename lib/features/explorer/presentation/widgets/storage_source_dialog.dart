import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../data/storage_service.dart';

/// Diálogo interactivo que consulta al docente si desea cargar recursos
/// desde la Memoria USB detectada o desde el Almacenamiento Interno.
class StorageSourceDialog extends StatelessWidget {
  final List<StorageUnit> units;
  final ValueChanged<StorageUnit> onSelectUnit;

  const StorageSourceDialog({
    super.key,
    required this.units,
    required this.onSelectUnit,
  });

  static Future<void> show(
    BuildContext context, {
    required List<StorageUnit> units,
    required ValueChanged<StorageUnit> onSelectUnit,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StorageSourceDialog(
        units: units,
        onSelectUnit: onSelectUnit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final dialogWidth = (media.size.width * 0.55).clamp(380.0, 520.0);
    final hasUsb = units.any((u) => u.type == StorageType.usb);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Container(
        width: dialogWidth,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: hasUsb ? AppColors.accentGreen.withValues(alpha: 0.8) : AppColors.borderHighlight,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: 28,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabecera con icono dinámico
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: hasUsb
                        ? AppColors.accentGreen.withValues(alpha: 0.2)
                        : AppColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    hasUsb ? Icons.usb_rounded : Icons.storage_rounded,
                    color: hasUsb ? AppColors.accentGreen : AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasUsb
                            ? '¡Memoria USB Detectada!'
                            : 'Origen de Almacenamiento',
                        style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '¿Desde dónde deseas leer los recursos de tu clase?',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Opciones de almacenamiento
            ...units.map((unit) {
              final isUsb = unit.type == StorageType.usb;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).pop();
                      onSelectUnit(unit);
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isUsb
                            ? AppColors.accentGreen.withValues(alpha: 0.15)
                            : AppColors.surfaceLight.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isUsb
                              ? AppColors.accentGreen.withValues(alpha: 0.7)
                              : AppColors.borderHighlight,
                          width: isUsb ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isUsb ? Icons.usb_rounded : Icons.phone_android_rounded,
                            size: 20,
                            color: isUsb ? AppColors.accentGreen : AppColors.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  unit.label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isUsb ? AppColors.textPrimary : AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  unit.path,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    color: AppColors.textMuted,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isUsb)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.accentGreen,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'USB RECOMENDADO',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 13,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
