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
  int _selectedMode = 0; // 0 = Wi-Fi / Hotspot, 1 = Bluetooth PAN

  String get _currentUrl =>
      _selectedMode == 0 ? _serverService.wifiUrl : _serverService.bluetoothUrl;

  @override
  void initState() {
    super.initState();
    _initServer();
  }

  Future<void> _initServer() async {
    await _serverService.startServer();
    if (mounted) {
      setState(() {
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
        width: 450,
        constraints: BoxConstraints(
          maxHeight: media.size.height * 0.92,
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
                          'Comunicación dual Wi-Fi Local o Red Bluetooth',
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

            // Selector interactivo de canal de comunicación: Wi-Fi vs Bluetooth
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _selectedMode = 0),
                        borderRadius: BorderRadius.circular(9),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(
                            color: _selectedMode == 0 ? AppColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.wifi_rounded,
                                size: 15,
                                color: _selectedMode == 0 ? Colors.white : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Wi-Fi / Zona Wi-Fi',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _selectedMode == 0 ? Colors.white : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _selectedMode = 1),
                        borderRadius: BorderRadius.circular(9),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(
                            color: _selectedMode == 1 ? AppColors.secondary : Colors.transparent,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.bluetooth_rounded,
                                size: 15,
                                color: _selectedMode == 1 ? Colors.white : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Red Bluetooth',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _selectedMode == 1 ? Colors.white : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

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
                              data: _currentUrl,
                              version: QrVersions.auto,
                              size: isCompact ? 125 : 150,
                              backgroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Enlace de texto visible y botón de copiado
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.borderSubtle),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _selectedMode == 0 ? Icons.wifi_rounded : Icons.bluetooth_rounded,
                                  size: 16,
                                  color: _selectedMode == 0 ? AppColors.primary : AppColors.secondary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: SelectableText(
                                    _currentUrl,
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
                                    Clipboard.setData(ClipboardData(text: _currentUrl));
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
                          const SizedBox(height: 10),

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

                          // Pasos explicativos contextuales para el docente
                          Text(
                            _selectedMode == 0
                                ? '1. Conecta tu teléfono a la misma red Wi-Fi o Hotspot del proyector.\n'
                                  '2. Abre EduSlide en tu móvil y selecciona "Usar como mando".\n'
                                  '3. Escanea el código QR o introduce la dirección indicada arriba.'
                                : '1. Empareja tu teléfono con el proyector por Bluetooth en los Ajustes de Android.\n'
                                  '2. En tu móvil activa "Anclaje de red por Bluetooth" (Bluetooth Tethering).\n'
                                  '3. En el mando de EduSlide selecciona "Modo Bluetooth" y pulsa Conectar.',
                            style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted, height: 1.4),
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
