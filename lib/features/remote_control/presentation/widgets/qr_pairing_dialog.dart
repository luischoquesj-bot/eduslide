import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../data/remote_server_service.dart';

/// Diálogo modal del proyector para vincular el teléfono móvil como mando remoto.
/// Despliega el código QR con la URL del servidor WebSocket local y el enlace textual.
class QrPairingDialog extends StatefulWidget {
  const QrPairingDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => const QrPairingDialog(),
    );
  }

  @override
  State<QrPairingDialog> createState() => _QrPairingDialogState();
}

class _QrPairingDialogState extends State<QrPairingDialog> {
  final RemoteServerService _serverService = RemoteServerService();
  bool _isLoading = true;
  String _wsUrl = '';

  @override
  void initState() {
    super.initState();
    _initServer();
  }

  Future<void> _initServer() async {
    await _serverService.startServer();
    if (mounted) {
      setState(() {
        _wsUrl = _serverService.serverUrl;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isCompact = media.size.height < 500;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Container(
        width: 440,
        constraints: BoxConstraints(
          maxHeight: media.size.height * 0.90,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderHighlight, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 30,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Cabecera con título y botón de cierre
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.vertical(top: Radius.circular(19)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.settings_remote_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Enlazar Mando a Distancia',
                          style: AppTextStyles.cardTitle,
                        ),
                        Text(
                          'Conexión local por Wi-Fi o Zona Wi-Fi',
                          style: TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.borderSubtle, height: 1),

            // 2. Contenido Central: Código QR e Indicaciones
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: CircularProgressIndicator(color: AppColors.primary),
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Código QR centrado con fondo blanco y esquinas redondeadas
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: QrImageView(
                              data: _wsUrl,
                              version: QrVersions.auto,
                              size: isCompact ? 130 : 160,
                              backgroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Enlace de texto visible y botón de copiado
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.borderSubtle),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.link_rounded, size: 16, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: SelectableText(
                                    _wsUrl,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded, size: 16),
                                  tooltip: 'Copiar enlace',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: _wsUrl));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Enlace copiado al portapapeles'),
                                        duration: Duration(seconds: 2),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Estado de conexión reactivo del mando
                          ValueListenableBuilder<bool>(
                            valueListenable: _serverService.isClientConnected,
                            builder: (context, isConnected, child) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isConnected
                                      ? AppColors.accentGreen.withValues(alpha: 0.15)
                                      : AppColors.accentAmber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isConnected
                                        ? AppColors.accentGreen
                                        : AppColors.accentAmber.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isConnected
                                            ? AppColors.accentGreen
                                            : AppColors.accentAmber,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isConnected
                                          ? '¡Mando Móvil Conectado y Activo!'
                                          : 'Esperando conexión desde tu teléfono móvil...',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isConnected
                                            ? AppColors.accentGreen
                                            : AppColors.accentAmber,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 10),

                          // Pasos explicativos para el docente
                          const Text(
                            '1. Conecta tu teléfono a la misma red Wi-Fi o Hotspot del proyector.\n'
                            '2. Abre EduSlide en tu móvil y selecciona "Usar como mando".\n'
                            '3. Escanea el código QR o introduce la dirección indicada arriba.',
                            style: TextStyle(fontSize: 10.5, color: AppColors.textMuted, height: 1.4),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
