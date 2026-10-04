import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../home/presentation/screens/workspace_screen.dart';
import 'remote_pairing_screen.dart';

/// Pantalla vertical moderna de bifurcación de inicio para Teléfonos Móviles.
/// Permite al docente elegir entre utilizar su dispositivo como Mando a Distancia
/// o rotar la pantalla y transmitir por cable HDMI / Duplicador de pantalla (Smart View).
class MobileLauncherScreen extends StatelessWidget {
  const MobileLauncherScreen({super.key});

  /// Inicia el modo proyector rotando forzadamente la orientación a horizontal
  Future<void> _startHdmiMode(BuildContext context) async {
    // 1. Configurar orientación horizontal estricta para la vista de proyector
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // 2. Activar modo inmersivo de pantalla completa
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const WorkspaceScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight > 32 ? constraints.maxHeight - 32 : constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 6),

                      // Cabecera institucional de EduSlide
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.co_present_rounded,
                            size: 40,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      const Text(
                        'EduSlide',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.displayTitle,
                      ),
                      const SizedBox(height: 4),

                      const Text(
                        'Sistema Integral de Proyección Didáctica',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.0,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 18),

                      const Text(
                        'Selecciona cómo deseas utilizar este teléfono:',
                        style: TextStyle(
                          fontSize: 12.0,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Opción 1: "Usar como mando"
                      _buildOptionCard(
                        context,
                        title: 'Usar como mando',
                        subtitle: 'Controla diapositivas, PDFs, videos y herramientas de pizarra a distancia desde tu móvil.',
                        badge: 'Control\nWi-Fi',
                        icon: Icons.settings_remote_rounded,
                        accentColor: AppColors.primary,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const RemotePairingScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),

                      // Opción 2: "Usar HDMI o Duplicador"
                      _buildOptionCard(
                        context,
                        title: 'Usar HDMI o Duplicador',
                        subtitle: 'Conecta tu móvil a un proyector por cable o pantalla inalámbrica. Rota a horizontal para ver el espacio completo.',
                        badge: 'Vista\nProyector',
                        icon: Icons.tv_rounded,
                        accentColor: AppColors.secondary,
                        onTap: () => _startHdmiMode(context),
                      ),

                      const Spacer(),
                      const SizedBox(height: 14),

                      // Pie de créditos pedagógicos institucionales
                      const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'EduProjects BO Educación y Tecnología',
                              style: TextStyle(
                                fontSize: 11.0,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                                letterSpacing: 0.3,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Desarrollado por Prof. Luis Choque',
                              style: TextStyle(
                                fontSize: 10.0,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildOptionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String badge,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.45),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.10),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Ícono distintivo con etiqueta ubicada debajo que no excede su ancho
              SizedBox(
                width: 56,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.4),
                          width: 1.2,
                        ),
                      ),
                      child: Center(
                        child: Icon(icon, size: 26, color: accentColor),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      width: 54,
                      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.35),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        badge,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                          height: 1.15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Contenido textual
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.cardTitle.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
