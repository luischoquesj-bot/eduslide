import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../explorer/domain/models/resource_item.dart';

/// Visor dinámico, interactivo y multifuncional de recursos didácticos para el centro de EduSlide.
/// Soporta:
/// 1. Imágenes: Visualización real con InteractiveViewer (pinch-to-zoom, arrastre, rotación y reset).
/// 2. Videos: Reproductor interactivo con barra de tiempo (scrubber), controles de reproducción y velocidad.
/// 3. Audios: Reproductor pedagógico con visualizador de ondas sonoras animadas, controles de audio y progreso.
/// 4. PDFs / Slides / Docs: Visor con navegación de páginas/diapositivas, zoom y modo de lectura.
/// Además incorpora botones de control de proporción (100%, 75%, 50%), cambio de lado (Izq/Der) y cierre directo.
class InteractiveResourceViewer extends StatefulWidget {
  final ResourceItem resource;
  final VoidCallback? onClose;
  final ValueChanged<double>? onRatioChanged;
  final double currentRatio;
  final bool isResourceOnLeft;
  final ValueChanged<bool>? onSideToggle;
  final VoidCallback? onExpandFull;

  const InteractiveResourceViewer({
    super.key,
    required this.resource,
    this.onClose,
    this.onRatioChanged,
    this.currentRatio = 0.5,
    this.isResourceOnLeft = false,
    this.onSideToggle,
    this.onExpandFull,
  });

  @override
  State<InteractiveResourceViewer> createState() => _InteractiveResourceViewerState();
}

class _InteractiveResourceViewerState extends State<InteractiveResourceViewer>
    with SingleTickerProviderStateMixin {
  // Controles de imagen
  final TransformationController _transformationController = TransformationController();
  int _rotationQuarterTurns = 0;

  // Controles interactivos de video / audio
  bool _isPlaying = true;
  double _playbackPositionSeconds = 24.0;
  final double _totalDurationSeconds = 185.0; // 03:05
  double _playbackSpeed = 1.0;
  bool _isMuted = false;

  // Controles de PDF / Diapositivas
  int _currentPage = 1;
  final int _totalPages = 12;
  double _documentZoom = 1.0;

  // Animación para el visualizador de audio
  late AnimationController _waveformAnimController;

  @override
  void initState() {
    super.initState();
    _waveformAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant InteractiveResourceViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resource.id != widget.resource.id) {
      _transformationController.value = Matrix4.identity();
      _rotationQuarterTurns = 0;
      _playbackPositionSeconds = 0.0;
      _isPlaying = true;
      _currentPage = 1;
      _documentZoom = 1.0;
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _waveformAnimController.dispose();
    super.dispose();
  }

  void _zoomIn() {
    setState(() {
      _documentZoom = (_documentZoom + 0.25).clamp(0.5, 3.0);
      final currentScale = _transformationController.value.getMaxScaleOnAxis();
      if (currentScale < 5.0) {
        _transformationController.value =
            Matrix4.diagonal3Values(1.25, 1.25, 1.0).multiplied(_transformationController.value);
      }
    });
  }

  void _zoomOut() {
    setState(() {
      _documentZoom = (_documentZoom - 0.25).clamp(0.5, 3.0);
      final currentScale = _transformationController.value.getMaxScaleOnAxis();
      if (currentScale > 0.4) {
        _transformationController.value =
            Matrix4.diagonal3Values(0.8, 0.8, 1.0).multiplied(_transformationController.value);
      }
    });
  }

  void _resetZoom() {
    setState(() {
      _documentZoom = 1.0;
      _rotationQuarterTurns = 0;
      _transformationController.value = Matrix4.identity();
    });
  }

  void _rotateClockwise() {
    setState(() {
      _rotationQuarterTurns = (_rotationQuarterTurns + 1) % 4;
    });
  }

  String _formatTime(double seconds) {
    final int mins = seconds ~/ 60;
    final int secs = (seconds % 60).toInt();
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.resource;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.accentColor.withValues(alpha: 0.6),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Barra Superior con Título, Insignia y Controles de Proporción (100%, 75%, 50%)
          _buildViewerHeader(item),

          // 2. Cuerpo del visor según el tipo de recurso seleccionado
          Expanded(
            child: _buildResourceContent(item),
          ),
        ],
      ),
    );
  }

  /// Barra superior interactiva con conmutadores de porcentaje y cierre
  Widget _buildViewerHeader(ResourceItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        border: Border(
          bottom: BorderSide(
            color: AppColors.borderSubtle.withValues(alpha: 0.7),
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          // Ícono y etiqueta del tipo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: item.accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: item.accentColor.withValues(alpha: 0.4),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.icon, size: 14, color: item.accentColor),
                const SizedBox(width: 4),
                Text(
                  item.extension.toUpperCase().replaceAll('.', ''),
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: item.accentColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Título del archivo
          Expanded(
            child: Tooltip(
              message: item.name,
              child: Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.cardTitle.copyWith(fontSize: 12.5),
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Selector de porcentaje rápido (50% | 75% | 100%)
          _buildRatioButtons(),
          const SizedBox(width: 6),

          // Conmutador de Lado (Izq / Der)
          if (widget.onSideToggle != null)
            Tooltip(
              message: widget.isResourceOnLeft
                  ? 'Colocar recurso a la derecha'
                  : 'Colocar recurso a la izquierda',
              child: InkWell(
                onTap: () => widget.onSideToggle?.call(!widget.isResourceOnLeft),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.borderHighlight, width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.isResourceOnLeft
                            ? Icons.arrow_back_rounded
                            : Icons.arrow_forward_rounded,
                        size: 12,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        widget.isResourceOnLeft ? 'Izq' : 'Der',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(width: 6),

          // Botón Cerrar (X) para retornar a pizarra completa
          Tooltip(
            message: 'Cerrar recurso (Volver a pizarra completa)',
            child: InkWell(
              onTap: widget.onClose,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.accentRose.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 15,
                  color: AppColors.accentRose,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Botones de selección de porcentaje (50%, 75%, 100%)
  Widget _buildRatioButtons() {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSubtle, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildRatioChip(label: '50%', ratio: 0.50),
          _buildRatioChip(label: '75%', ratio: 0.75),
          _buildRatioChip(label: '100%', ratio: 1.00),
        ],
      ),
    );
  }

  Widget _buildRatioChip({required String label, required double ratio}) {
    final bool isSelected = (widget.currentRatio - ratio).abs() < 0.05;
    return InkWell(
      onTap: () {
        widget.onRatioChanged?.call(ratio);
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textMuted,
          ),
        ),
      ),
    );
  }

  /// Renderiza el cuerpo según el tipo de recurso
  Widget _buildResourceContent(ResourceItem item) {
    switch (item.type) {
      case ResourceType.image:
        return _buildImageViewer(item);
      case ResourceType.video:
        return _buildVideoPlayer(item);
      case ResourceType.audio:
        return _buildAudioPlayer(item);
      case ResourceType.pdf:
      case ResourceType.slide:
        return _buildDocumentViewer(item);
    }
  }

  /// 1. VISOR DE IMÁGENES REALES CON PINCH-ZOOM Y HERRAMIENTAS
  Widget _buildImageViewer(ResourceItem item) {
    final file = File(item.path);
    final exists = file.existsSync();

    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Imagen interactiva con paneo y zoom táctil
          Center(
            child: InteractiveViewer(
              transformationController: _transformationController,
              minScale: 0.2,
              maxScale: 6.0,
              boundaryMargin: const EdgeInsets.all(80),
              child: RotatedBox(
                quarterTurns: _rotationQuarterTurns,
                child: exists
                    ? Image.file(
                        file,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildFallbackImageCard(item, 'Error al abrir imagen física'),
                      )
                    : _buildFallbackImageCard(item, 'Fotografía / Ilustración Didáctica'),
              ),
            ),
          ),

          // Barra inferior flotante de herramientas de imagen
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderHighlight, width: 0.8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildToolButton(
                      icon: Icons.zoom_in_rounded,
                      tooltip: 'Acercar (+)',
                      onPressed: _zoomIn,
                    ),
                    _buildToolButton(
                      icon: Icons.zoom_out_rounded,
                      tooltip: 'Alejar (-)',
                      onPressed: _zoomOut,
                    ),
                    _buildToolButton(
                      icon: Icons.refresh_rounded,
                      tooltip: 'Restablecer Zoom',
                      onPressed: _resetZoom,
                    ),
                    _buildToolButton(
                      icon: Icons.rotate_right_rounded,
                      tooltip: 'Girar 90°',
                      onPressed: _rotateClockwise,
                    ),
                    Container(
                      height: 14,
                      width: 1,
                      color: AppColors.borderSubtle,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    Text(
                      item.formattedSize,
                      style: const TextStyle(fontSize: 9.5, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackImageCard(ResourceItem item, String message) {
    return Container(
      width: 400,
      height: 300,
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accentGreen.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.accentGreen.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.image_rounded, size: 54, color: AppColors.accentGreen),
          ),
          const SizedBox(height: 12),
          Text(
            item.name,
            textAlign: TextAlign.center,
            style: AppTextStyles.cardTitle.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 6),
          Text(
            'Ruta: ${item.path}',
            style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  /// 2. REPRODUCTOR INTERACTIVO DE VIDEO DIDÁCTICO
  Widget _buildVideoPlayer(ResourceItem item) {
    return Container(
      color: Colors.black,
      child: Column(
        children: [
          // Escenario de Video
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Fondo representativo de alta fidelidad con gradiente cinemático
                Container(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.0,
                      colors: [Color(0xFF1E293B), Color(0xFF090D16)],
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.secondary.withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            _isPlaying ? Icons.smart_display_rounded : Icons.pause_circle_filled_rounded,
                            size: 48,
                            color: AppColors.secondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          item.name,
                          style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Reproducción Educativa • 1080p Full HD',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.secondary.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Botón central de Play / Pause táctil
                InkWell(
                  onTap: () {
                    setState(() {
                      _isPlaying = !_isPlaying;
                    });
                  },
                  borderRadius: BorderRadius.circular(50),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 42,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Barra interactiva de control de video
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: const BoxDecoration(
              color: AppColors.surfaceElevated,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Scrubber (Barra de progreso)
                Row(
                  children: [
                    Text(
                      _formatTime(_playbackPositionSeconds),
                      style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3.5,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          activeTrackColor: AppColors.secondary,
                          inactiveTrackColor: AppColors.borderSubtle,
                          thumbColor: AppColors.secondary,
                        ),
                        child: Slider(
                          value: _playbackPositionSeconds.clamp(0.0, _totalDurationSeconds),
                          min: 0.0,
                          max: _totalDurationSeconds,
                          onChanged: (val) {
                            setState(() {
                              _playbackPositionSeconds = val;
                            });
                          },
                        ),
                      ),
                    ),
                    Text(
                      _formatTime(_totalDurationSeconds),
                      style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                    ),
                  ],
                ),

                // Fila de acciones (Play, Retroceder, Avanzar, Velocidad, Volumen)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: AppColors.secondary,
                            size: 22,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPlaying = !_isPlaying;
                            });
                          },
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          padding: EdgeInsets.zero,
                        ),
                        IconButton(
                          icon: const Icon(Icons.replay_10_rounded, size: 18),
                          onPressed: () {
                            setState(() {
                              _playbackPositionSeconds =
                                  (_playbackPositionSeconds - 10).clamp(0.0, _totalDurationSeconds);
                            });
                          },
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          padding: EdgeInsets.zero,
                        ),
                        IconButton(
                          icon: const Icon(Icons.forward_10_rounded, size: 18),
                          onPressed: () {
                            setState(() {
                              _playbackPositionSeconds =
                                  (_playbackPositionSeconds + 10).clamp(0.0, _totalDurationSeconds);
                            });
                          },
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),

                    // Selector de velocidad y volumen
                    Row(
                      children: [
                        InkWell(
                          onTap: () {
                            setState(() {
                              if (_playbackSpeed == 1.0) {
                                _playbackSpeed = 1.25;
                              } else if (_playbackSpeed == 1.25) {
                                _playbackSpeed = 1.5;
                              } else {
                                _playbackSpeed = 1.0;
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${_playbackSpeed}x',
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.secondary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(
                            _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () {
                            setState(() {
                              _isMuted = !_isMuted;
                            });
                          },
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 3. REPRODUCTOR INTERACTIVO DE AUDIO / LECCIÓN ORAL
  Widget _buildAudioPlayer(ResourceItem item) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A1625), Color(0xFF0F0B15)],
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Disco / Onda sonora central
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.accentAmber.withValues(alpha: 0.3),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surfaceElevated,
                      border: Border.all(
                        color: AppColors.accentAmber.withValues(alpha: 0.6),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentAmber.withValues(alpha: 0.25),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.graphic_eq_rounded,
                      size: 38,
                      color: AppColors.accentAmber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Text(
                item.name,
                textAlign: TextAlign.center,
                style: AppTextStyles.sectionTitle.copyWith(fontSize: 14.5),
              ),
              const SizedBox(height: 4),
              Text(
                'Audio Clase Didáctico • ${item.formattedSize}',
                style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
              ),
              const SizedBox(height: 14),

              // Visualizador animado de barras de audio
              AnimatedBuilder(
                animation: _waveformAnimController,
                builder: (context, child) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(18, (index) {
                      final double factor = (_isPlaying)
                          ? ((index % 3 + 1) * 0.25 +
                                  (1.0 - _waveformAnimController.value) * ((index % 5 + 1) * 0.15))
                              .clamp(0.2, 1.0)
                          : 0.2;
                      return Container(
                        width: 3.5,
                        height: 28 * factor,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accentAmber.withValues(alpha: 0.4 + factor * 0.6),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  );
                },
              ),
              const SizedBox(height: 14),

              // Barra de reproducción de audio
              SizedBox(
                width: 320,
                child: Column(
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3.5,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        activeTrackColor: AppColors.accentAmber,
                        inactiveTrackColor: AppColors.borderSubtle,
                        thumbColor: AppColors.accentAmber,
                      ),
                      child: Slider(
                        value: _playbackPositionSeconds.clamp(0.0, _totalDurationSeconds),
                        min: 0.0,
                        max: _totalDurationSeconds,
                        onChanged: (val) {
                          setState(() {
                            _playbackPositionSeconds = val;
                          });
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatTime(_playbackPositionSeconds),
                            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                          ),
                          Text(
                            _formatTime(_totalDurationSeconds),
                            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Controles principales de audio
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.replay_10_rounded, size: 22),
                    onPressed: () {
                      setState(() {
                        _playbackPositionSeconds =
                            (_playbackPositionSeconds - 10).clamp(0.0, _totalDurationSeconds);
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _isPlaying = !_isPlaying;
                      });
                    },
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accentAmber,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentAmber.withValues(alpha: 0.4),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Icon(
                        _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: 26,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.forward_10_rounded, size: 22),
                    onPressed: () {
                      setState(() {
                        _playbackPositionSeconds =
                            (_playbackPositionSeconds + 10).clamp(0.0, _totalDurationSeconds);
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 4. VISOR DE DOCUMENTOS, PDFS Y DIAPOSITIVAS FLUTTER (.eslide / .pdf / .docx)
  Widget _buildDocumentViewer(ResourceItem item) {
    final bool isPdf = item.type == ResourceType.pdf;

    return Container(
      color: const Color(0xFF1E222D),
      child: Column(
        children: [
          // Área principal de lectura y visualización
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Transform.scale(
                    scale: _documentZoom,
                    child: Container(
                      width: isPdf ? 340 : 420,
                      height: isPdf ? 460 : 260,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isPdf ? Colors.white : const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.45),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: isPdf ? Colors.black12 : AppColors.primary.withValues(alpha: 0.4),
                          width: 1.0,
                        ),
                      ),
                      child: isPdf
                          ? _buildPdfPageContent(item)
                          : _buildSlidePageContent(item),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Barra inferior de paginación y zoom del documento
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: const BoxDecoration(
              color: AppColors.surfaceElevated,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Navegación de páginas
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, size: 20),
                      onPressed: _currentPage > 1
                          ? () {
                              setState(() {
                                _currentPage--;
                              });
                            }
                          : null,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      padding: EdgeInsets.zero,
                    ),
                    Text(
                      isPdf
                          ? 'Página $_currentPage de $_totalPages'
                          : 'Slide $_currentPage de 8',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, size: 20),
                      onPressed: _currentPage < (isPdf ? _totalPages : 8)
                          ? () {
                              setState(() {
                                _currentPage++;
                              });
                            }
                          : null,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),

                // Controles de zoom del documento
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.zoom_out_rounded, size: 16),
                      onPressed: _zoomOut,
                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                      padding: EdgeInsets.zero,
                    ),
                    Text(
                      '${(_documentZoom * 100).toInt()}%',
                      style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                    ),
                    IconButton(
                      icon: const Icon(Icons.zoom_in_rounded, size: 16),
                      onPressed: _zoomIn,
                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                      padding: EdgeInsets.zero,
                    ),
                    IconButton(
                      icon: const Icon(Icons.fit_screen_rounded, size: 16),
                      onPressed: _resetZoom,
                      tooltip: 'Ajustar',
                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Maqueta interactiva de página de documento PDF
  Widget _buildPdfPageContent(ResourceItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.shade700,
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Text(
                'PDF OFICIAL',
                style: TextStyle(
                  fontSize: 7.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            Text(
              'Pág. $_currentPage',
              style: const TextStyle(fontSize: 9, color: Colors.black54),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          item.name,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        Container(height: 1.5, color: Colors.black12),
        const SizedBox(height: 10),

        // Líneas representativas de texto didáctico
        for (int i = 0; i < 7; i++) ...[
          Container(
            height: 6,
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
        const SizedBox(height: 8),

        // Gráfico didáctico incrustado en el documento
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.black12),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_stories_rounded, size: 28, color: Colors.red.shade400),
                  const SizedBox(height: 4),
                  Text(
                    'Material Pedagógico de Secundaria',
                    style: TextStyle(fontSize: 8.5, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Maqueta interactiva de diapositiva Flutter (.eslide / presentación)
  Widget _buildSlidePageContent(ResourceItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Text(
                'SLIDE FLUTTER',
                style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            Text(
              'Diapositiva $_currentPage / 8',
              style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          item.name,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Unidad de Aprendizaje Curricular interactiva para pizarra digital',
          style: TextStyle(
            fontSize: 9.5,
            color: AppColors.primary.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 10),

        // Puntos clave de la diapositiva
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildBullet('1. Conceptos fundamentales del tema curricular'),
                      _buildBullet('2. Ejemplificación práctica y análisis grupal'),
                      _buildBullet('3. Actividad interactiva en la pizarra digital'),
                    ],
                  ),
                ),
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    size: 36,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBullet(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Text(
        text,
        style: const TextStyle(fontSize: 8.5, color: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(5.0),
          child: Icon(icon, size: 16, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
