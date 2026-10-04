import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';

/// Pantalla de Vinculación y Mando a Distancia Móvil.
/// Permite conectarse al servidor WebSocket del proyector mediante IP/URL o lectura rápida,
/// y proporciona controles táctiles gigantes (Anterior, Siguiente, Lápiz, Pausa/Play, Touchpad).
class RemotePairingScreen extends StatefulWidget {
  const RemotePairingScreen({super.key});

  @override
  State<RemotePairingScreen> createState() => _RemotePairingScreenState();
}

class _RemotePairingScreenState extends State<RemotePairingScreen> {
  final TextEditingController _urlController = TextEditingController(text: 'ws://192.168.43.1:8080');

  WebSocket? _socket;
  bool _isConnecting = false;
  bool _isConnected = false;
  String? _errorMessage;
  int _selectedPairingMode = 0; // 0 = Wi-Fi, 1 = Bluetooth
  String? _connectedDeviceName;
  String? _activeResourceOnProjector;

  // Estado del mando remoto
  bool _isPlaying = true;
  bool _isPenActive = false;
  bool _isEraserActive = false;

  @override
  void dispose() {
    _socket?.close();
    _urlController.dispose();
    super.dispose();
  }

  /// Conecta con el servidor WebSocket del proyector
  Future<void> _connectToProjector([String? directUrl]) async {
    final targetUrl = directUrl ?? _urlController.text.trim();
    if (targetUrl.isEmpty) return;

    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    try {
      final ws = await WebSocket.connect(targetUrl).timeout(const Duration(seconds: 5));
      _socket = ws;

      if (mounted) {
        setState(() {
          _isConnected = true;
          _isConnecting = false;
        });
      }

      ws.listen(
        (data) {
          // Escuchar eventos bidireccionales provenientes del proyector
          try {
            final decoded = jsonDecode(data.toString());
            if (decoded is Map<String, dynamic>) {
              _handleIncomingProjectorMessage(decoded);
            }
          } catch (e) {
            debugPrint('Error procesando mensaje bidireccional: $e');
          }
        },
        onDone: () {
          if (mounted) {
            setState(() {
              _isConnected = false;
              _socket = null;
            });
          }
        },
        onError: (err) {
          if (mounted) {
            setState(() {
              _isConnected = false;
              _socket = null;
              _errorMessage = 'Error de conexión: $err';
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _isConnected = false;
          _errorMessage = 'No se pudo conectar a $targetUrl.\n'
              '${_selectedPairingMode == 0 ? 'Verifica que ambos dispositivos estén en el mismo Wi-Fi o Hotspot.' : 'Verifica que ambos dispositivos estén vinculados por Bluetooth con "Anclaje de red Bluetooth" activo.'}';
        });
      }
    }
  }

  void _handleIncomingProjectorMessage(Map<String, dynamic> msg) {
    if (!mounted) return;
    setState(() {
      if (msg['device'] != null) {
        _connectedDeviceName = msg['device'].toString();
      }
      if (msg['activeResource'] != null) {
        _activeResourceOnProjector = msg['activeResource'].toString();
      }
      if (msg['isPenActive'] is bool) {
        _isPenActive = msg['isPenActive'] as bool;
      }
      if (msg['isEraserActive'] is bool) {
        _isEraserActive = msg['isEraserActive'] as bool;
      }
    });
  }

  /// Envía un comando en formato JSON al proyector
  void _sendCommand(String action, [Map<String, dynamic>? extra]) {
    if (_socket != null && _isConnected) {
      final payload = {
        'action': action,
        ...?extra,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      _socket!.add(jsonEncode(payload));
    }
  }

  void _disconnect() {
    _socket?.close();
    setState(() {
      _isConnected = false;
      _socket = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          _isConnected ? 'Mando Remoto Conectado' : 'Vincular con Proyector',
          style: AppTextStyles.cardTitle.copyWith(fontSize: 16),
        ),
        actions: [
          if (_isConnected)
            IconButton(
              icon: const Icon(Icons.link_off_rounded, color: AppColors.accentRose),
              tooltip: 'Desconectar mando',
              onPressed: _disconnect,
            ),
        ],
      ),
      body: SafeArea(
        child: _isConnected ? _buildActiveRemoteControlView() : _buildPairingView(),
      ),
    );
  }

  // ==========================================
  // VISTA 1: FORMULARIO DE VINCULACIÓN
  // ==========================================
  Widget _buildPairingView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
              ),
              child: const Icon(
                Icons.settings_remote_rounded,
                size: 50,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Control Remoto EduSlide',
            textAlign: TextAlign.center,
            style: AppTextStyles.displayTitle,
          ),
          const SizedBox(height: 6),
          const Text(
            'Ingresa la dirección WebSocket mostrada en la pantalla del proyector para sincronizar.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 18),

          // Selector de Canal de Comunicación: Wi-Fi vs Red Bluetooth
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedPairingMode = 0;
                        if (_urlController.text.contains('192.168.44')) {
                          _urlController.text = 'ws://192.168.43.1:8080';
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(9),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedPairingMode == 0 ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.wifi_rounded,
                            size: 15,
                            color: _selectedPairingMode == 0 ? Colors.white : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Modo Wi-Fi',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: _selectedPairingMode == 0 ? Colors.white : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedPairingMode = 1;
                        if (_urlController.text.contains('192.168.43')) {
                          _urlController.text = 'ws://192.168.44.1:8080';
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(9),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedPairingMode == 1 ? AppColors.secondary : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.bluetooth_rounded,
                            size: 15,
                            color: _selectedPairingMode == 1 ? Colors.white : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Modo Bluetooth',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: _selectedPairingMode == 1 ? Colors.white : AppColors.textSecondary,
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
          const SizedBox(height: 16),

          // Campo de texto de dirección IP / WebSocket
          TextField(
            controller: _urlController,
            style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
            decoration: InputDecoration(
              labelText: _selectedPairingMode == 0 ? 'Enlace Wi-Fi del Proyector' : 'Enlace Bluetooth (PAN) del Proyector',
              labelStyle: const TextStyle(color: AppColors.textSecondary),
              hintText: _selectedPairingMode == 0 ? 'ws://192.168.43.1:8080' : 'ws://192.168.44.1:8080',
              hintStyle: const TextStyle(color: AppColors.textMuted),
              prefixIcon: Icon(
                _selectedPairingMode == 0 ? Icons.wifi_tethering_rounded : Icons.bluetooth_connected_rounded,
                color: _selectedPairingMode == 0 ? AppColors.primary : AppColors.secondary,
              ),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.borderSubtle),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: _selectedPairingMode == 0 ? AppColors.primary : AppColors.secondary,
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Botón de Conexión
          ElevatedButton.icon(
            onPressed: _isConnecting ? null : () => _connectToProjector(),
            icon: _isConnecting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Icon(_selectedPairingMode == 0 ? Icons.wifi_rounded : Icons.bluetooth_rounded),
            label: Text(_isConnecting
                ? 'Conectando...'
                : (_selectedPairingMode == 0 ? 'Conectar por Wi-Fi' : 'Conectar por Bluetooth')),
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedPairingMode == 0 ? AppColors.primary : AppColors.secondary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 4,
            ),
          ),
          const SizedBox(height: 16),

          // Botón secundario para lectura rápida por cámara / simulación QR
          OutlinedButton.icon(
            onPressed: () => _showManualQrInputDialog(),
            icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.secondary),
            label: const Text('Escanear o Pegar Código QR', style: TextStyle(color: AppColors.secondary)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 13),
              side: const BorderSide(color: AppColors.secondary, width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accentRose.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accentRose.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.accentRose, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppColors.accentRose, fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),
          const Divider(color: AppColors.borderSubtle),
          const SizedBox(height: 12),
          Text(
            _selectedPairingMode == 0
                ? 'Instrucciones para Modo Wi-Fi:'
                : 'Instrucciones para Modo Bluetooth:',
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            _selectedPairingMode == 0
                ? '1. Conecta tu teléfono al mismo Wi-Fi o Hotspot que el proyector.\n'
                  '2. En el proyector, pulsa el botón QR en la barra inferior para ver la dirección.\n'
                  '3. Pulsa "Conectar por Wi-Fi" o escanea el QR con tu cámara.'
                : '1. Empareja teléfono y proyector por Bluetooth en los Ajustes de Android.\n'
                  '2. En tu móvil activa "Anclaje de red por Bluetooth" (Bluetooth Tethering).\n'
                  '3. En el proyector selecciona "Red Bluetooth" en el diálogo QR y pulsa "Conectar por Bluetooth".',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.45),
          ),
        ],
      ),
    );
  }

  void _showManualQrInputDialog() {
    final controller = TextEditingController(text: _urlController.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Row(
          children: [
            Icon(Icons.qr_code_scanner_rounded, color: AppColors.secondary),
            SizedBox(width: 8),
            Text('Escanear Enlace QR', style: AppTextStyles.cardTitle),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Pega o escribe el contenido del código QR mostrado en el proyector:',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: const TextStyle(fontFamily: 'monospace', color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.surfaceLight,
                hintText: 'ws://192.168.x.x:8080',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = controller.text.trim();
              Navigator.of(ctx).pop();
              if (val.isNotEmpty) {
                _urlController.text = val;
                _connectToProjector(val);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Conectar'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // VISTA 2: BOTONERA GIGANTE DEL MANDO REMOTO
  // ==========================================
  Widget _buildActiveRemoteControlView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Barra de estado de conexión con modo activo (Wi-Fi / Bluetooth) y sincronización bidireccional
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.accentGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.accentGreen.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Icon(
                  _selectedPairingMode == 0 ? Icons.wifi_rounded : Icons.bluetooth_rounded,
                  size: 16,
                  color: AppColors.accentGreen,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Enlace Bidireccional Activo (${_selectedPairingMode == 0 ? 'Wi-Fi' : 'Red Bluetooth'})',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accentGreen,
                        ),
                      ),
                      if (_connectedDeviceName != null || _activeResourceOnProjector != null)
                        Text(
                          '${_connectedDeviceName ?? 'Proyector'}${_activeResourceOnProjector != null ? ' • ${_activeResourceOnProjector!}' : ''}',
                          style: const TextStyle(fontSize: 9.5, color: AppColors.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accentGreen,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _selectedPairingMode == 0 ? 'WIFI' : 'BT',
                    style: const TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 1. Botones Gigantes de Navegación (Anterior / Siguiente)
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Expanded(
                  child: _buildGiantButton(
                    label: 'ANTERIOR',
                    sublabel: 'Página / Slide',
                    icon: Icons.arrow_back_ios_new_rounded,
                    color: AppColors.primary,
                    onTap: () => _sendCommand('prev'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildGiantButton(
                    label: 'SIGUIENTE',
                    sublabel: 'Página / Slide',
                    icon: Icons.arrow_forward_ios_rounded,
                    color: AppColors.secondary,
                    onTap: () => _sendCommand('next'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 2. Fila de Acciones Didácticas (Play/Pausa, Lápiz, Borrador)
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    label: _isPlaying ? 'Pausar' : 'Reproducir',
                    color: AppColors.accentAmber,
                    onTap: () {
                      setState(() {
                        _isPlaying = !_isPlaying;
                      });
                      _sendCommand('play_pause');
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.edit_rounded,
                    label: 'Lápiz Didáctico',
                    color: _isPenActive ? AppColors.accentGreen : AppColors.surfaceElevated,
                    textColor: _isPenActive ? Colors.white : AppColors.textPrimary,
                    onTap: () {
                      setState(() {
                        _isPenActive = !_isPenActive;
                        _isEraserActive = false;
                      });
                      _sendCommand('pen');
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.auto_fix_high_rounded,
                    label: 'Borrador',
                    color: _isEraserActive ? AppColors.accentRose : AppColors.surfaceElevated,
                    textColor: _isEraserActive ? Colors.white : AppColors.textPrimary,
                    onTap: () {
                      setState(() {
                        _isEraserActive = !_isEraserActive;
                        _isPenActive = false;
                      });
                      _sendCommand('eraser');
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 3. Touchpad Virtual / Área de Deslizamiento Táctil
          Expanded(
            flex: 3,
            child: GestureDetector(
              onPanUpdate: (details) {
                _sendCommand('cursor', {
                  'dx': details.delta.dx,
                  'dy': details.delta.dy,
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderHighlight, width: 1.2),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.touch_app_rounded, size: 36, color: AppColors.primary.withValues(alpha: 0.6)),
                      const SizedBox(height: 6),
                      const Text(
                        'Touchpad Virtual',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Desliza tu dedo aquí para mover el puntero',
                        style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 4. Botones Rápidos de Distribución de Pantalla
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _sendCommand('split_50'),
                  icon: const Icon(Icons.vertical_split_rounded, size: 16),
                  label: const Text('Dividir 50/50', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.borderHighlight),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _sendCommand('full_100'),
                  icon: const Icon(Icons.fullscreen_rounded, size: 16),
                  label: const Text('100% Pantalla', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.borderHighlight),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGiantButton({
    required String label,
    required String sublabel,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.5), width: 1.8),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 44, color: color),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: color,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sublabel,
                style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    Color? textColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderHighlight, width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 26, color: textColor ?? Colors.white),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: textColor ?? Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
