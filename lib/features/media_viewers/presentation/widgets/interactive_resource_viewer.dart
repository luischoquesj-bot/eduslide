import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../explorer/domain/models/resource_item.dart';

/// Visor dinámico, interactivo y real de recursos didácticos para el centro de EduSlide.
/// Integra soporte nativo real para:
/// 1. Imágenes: Visualización a pantalla completa sin marcos restrictivos, con InteractiveViewer y zoom infinito.
/// 2. PDFs: Lector nativo real de archivos PDF mediante flutter_pdfview con navegación de páginas.
/// 3. Videos: Reproductor nativo real de video mediante video_player con scrubber, velocidad y volumen.
/// 4. Audios: Reproductor nativo real de audio mediante ExoPlayer (video_player) con visualizador de ondas sonoras.
/// 5. Documentos .docx: Extracción y renderizado de texto real de archivos de Word (.docx) mediante archive.
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

  // Lector de PDF real
  PDFViewController? _pdfViewController;
  int _pdfCurrentPage = 0;
  int _pdfTotalPages = 0;
  bool _pdfReady = false;

  // Reproductor de Video real
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  // Reproductor de Audio real (ExoPlayer nativo)
  VideoPlayerController? _audioController;
  bool _isAudioInitialized = false;

  // Extracción de texto de documentos .docx
  List<String> _docxParagraphs = [];
  bool _isDocxLoaded = false;

  // Animación para el visualizador de audio
  late AnimationController _waveformAnimController;

  @override
  void initState() {
    super.initState();
    _waveformAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _initResourceEngines();
  }

  @override
  void didUpdateWidget(covariant InteractiveResourceViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resource.id != widget.resource.id ||
        oldWidget.resource.path != widget.resource.path) {
      _disposeEngines();
      _transformationController.value = Matrix4.identity();
      _rotationQuarterTurns = 0;
      _initResourceEngines();
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _waveformAnimController.dispose();
    _disposeEngines();
    super.dispose();
  }

  void _disposeEngines() {
    _videoController?.dispose();
    _videoController = null;
    _isVideoInitialized = false;

    _audioController?.dispose();
    _audioController = null;
    _isAudioInitialized = false;

    _docxParagraphs = [];
    _isDocxLoaded = false;
    _pdfReady = false;
    _pdfCurrentPage = 0;
    _pdfTotalPages = 0;
  }

  void _initResourceEngines() {
    final item = widget.resource;
    final file = File(item.path);
    final exists = file.existsSync();

    if (item.type == ResourceType.video && exists) {
      _videoController = VideoPlayerController.file(file)
        ..initialize().then((_) {
          if (mounted) {
            setState(() {
              _isVideoInitialized = true;
            });
            _videoController!.play();
          }
        }).catchError((error) {
          debugPrint('Error inicializando video: $error');
        });

      _videoController!.addListener(() {
        if (mounted) {
          setState(() {});
        }
      });
    } else if (item.type == ResourceType.audio && exists) {
      _audioController = VideoPlayerController.file(file)
        ..initialize().then((_) {
          if (mounted) {
            setState(() {
              _isAudioInitialized = true;
            });
            _audioController!.play();
          }
        }).catchError((error) {
          debugPrint('Error inicializando audio: $error');
        });

      _audioController!.addListener(() {
        if (mounted) {
          setState(() {});
        }
      });
    } else if (item.extension.toLowerCase().contains('doc') && exists) {
      _loadDocxContent(file);
    }
  }

  Future<void> _loadDocxContent(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final documentXmlFile = archive.findFile('word/document.xml');

      if (documentXmlFile != null) {
        final xmlString = utf8.decode(documentXmlFile.content as List<int>);
        // Extracción sencilla de párrafos <w:p> y textos <w:t>
        final regex = RegExp(r'<w:p[ >](.*?)</w:p>');
        final matches = regex.allMatches(xmlString);
        final List<String> paragraphs = [];

        for (final match in matches) {
          final pXml = match.group(1) ?? '';
          final textMatches = RegExp(r'<w:t[^>]*>(.*?)</w:t>').allMatches(pXml);
          final pText = textMatches.map((m) => m.group(1) ?? '').join().trim();
          if (pText.isNotEmpty) {
            paragraphs.add(pText);
          }
        }

        if (mounted) {
          setState(() {
            _docxParagraphs = paragraphs;
            _isDocxLoaded = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error al leer DOCX: $e');
    }
  }

  void _zoomIn() {
    setState(() {
      final currentScale = _transformationController.value.getMaxScaleOnAxis();
      if (currentScale < 8.0) {
        _transformationController.value =
            Matrix4.diagonal3Values(1.3, 1.3, 1.0).multiplied(_transformationController.value);
      }
    });
  }

  void _zoomOut() {
    setState(() {
      final currentScale = _transformationController.value.getMaxScaleOnAxis();
      if (currentScale > 0.3) {
        _transformationController.value =
            Matrix4.diagonal3Values(0.77, 0.77, 1.0).multiplied(_transformationController.value);
      }
    });
  }

  void _resetZoom() {
    setState(() {
      _rotationQuarterTurns = 0;
      _transformationController.value = Matrix4.identity();
    });
  }

  void _rotateClockwise() {
    setState(() {
      _rotationQuarterTurns = (_rotationQuarterTurns + 1) % 4;
    });
  }

  String _formatDuration(Duration d) {
    final int mins = d.inMinutes;
    final int secs = d.inSeconds % 60;
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
          color: item.accentColor.withValues(alpha: 0.5),
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
    if (item.extension.toLowerCase().contains('doc')) {
      return _buildDocxViewer(item);
    }

    switch (item.type) {
      case ResourceType.image:
        return _buildImageViewer(item);
      case ResourceType.video:
        return _buildVideoPlayer(item);
      case ResourceType.audio:
        return _buildAudioPlayer(item);
      case ResourceType.pdf:
        return _buildPdfViewer(item);
      case ResourceType.slide:
        return _buildSlideViewer(item);
    }
  }

  /// 1. VISOR DE IMÁGENES REALES SIN MARCOS OSCUROS RESTRICTIVOS (Requisito 8)
  /// Ocupa el 100% del lienzo y permite expansión ilimitada con InteractiveViewer
  Widget _buildImageViewer(ResourceItem item) {
    final file = File(item.path);
    final exists = file.existsSync();

    return Container(
      color: Colors.transparent, // Sin marco oscuro interior
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Imagen interactiva con expansión total y boundaryMargin libre
          InteractiveViewer(
            transformationController: _transformationController,
            minScale: 0.4,
            maxScale: 10.0,
            boundaryMargin: const EdgeInsets.all(double.infinity), // Sin límite de zoom
            clipBehavior: Clip.none, // Ocupa todo el espacio sin recorte interno
            child: SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.contain,
                child: RotatedBox(
                  quarterTurns: _rotationQuarterTurns,
                  child: exists
                      ? Image.file(
                          file,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildFallbackImageCard(item, 'Error al abrir imagen física'),
                        )
                      : _buildFallbackImageCard(item, 'Fotografía / Ilustración Didáctica'),
                ),
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

  /// 2. REPRODUCTOR REAL DE VIDEO DIDÁCTICO (Requisito 4)
  Widget _buildVideoPlayer(ResourceItem item) {
    final bool hasController = _videoController != null && _isVideoInitialized;

    return Container(
      color: Colors.black,
      child: Column(
        children: [
          // Escenario de Video Real
          Expanded(
            child: hasController
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      Center(
                        child: AspectRatio(
                          aspectRatio: _videoController!.value.aspectRatio > 0
                              ? _videoController!.value.aspectRatio
                              : 16 / 9,
                          child: VideoPlayer(_videoController!),
                        ),
                      ),
                      // Botón central de pausa/play
                      InkWell(
                        onTap: () {
                          setState(() {
                            if (_videoController!.value.isPlaying) {
                              _videoController!.pause();
                            } else {
                              _videoController!.play();
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(50),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _videoController!.value.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 44,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: AppColors.secondary),
                        const SizedBox(height: 12),
                        Text(
                          'Cargando video: ${item.name}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
          ),

          // Barra interactiva de control de video
          if (hasController)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: const BoxDecoration(
                color: AppColors.surfaceElevated,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Scrubber (Barra de progreso del video)
                  Row(
                    children: [
                      Text(
                        _formatDuration(_videoController!.value.position),
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
                            value: _videoController!.value.position.inSeconds
                                .toDouble()
                                .clamp(0.0, _videoController!.value.duration.inSeconds.toDouble()),
                            min: 0.0,
                            max: _videoController!.value.duration.inSeconds.toDouble() > 0
                                ? _videoController!.value.duration.inSeconds.toDouble()
                                : 1.0,
                            onChanged: (val) {
                              _videoController!.seekTo(Duration(seconds: val.toInt()));
                            },
                          ),
                        ),
                      ),
                      Text(
                        _formatDuration(_videoController!.value.duration),
                        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                      ),
                    ],
                  ),

                  // Fila de acciones (Play, Retroceder 10s, Avanzar 10s, Velocidad, Volumen)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              _videoController!.value.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: AppColors.secondary,
                              size: 22,
                            ),
                            onPressed: () {
                              setState(() {
                                if (_videoController!.value.isPlaying) {
                                  _videoController!.pause();
                                } else {
                                  _videoController!.play();
                                }
                              });
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.replay_10_rounded, size: 18),
                            onPressed: () {
                              final newPos =
                                  _videoController!.value.position - const Duration(seconds: 10);
                              _videoController!.seekTo(newPos > Duration.zero ? newPos : Duration.zero);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.forward_10_rounded, size: 18),
                            onPressed: () {
                              final newPos =
                                  _videoController!.value.position + const Duration(seconds: 10);
                              _videoController!.seekTo(newPos);
                            },
                          ),
                        ],
                      ),

                      // Selector de velocidad y volumen
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              _videoController!.value.volume > 0
                                  ? Icons.volume_up_rounded
                                  : Icons.volume_off_rounded,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                            onPressed: () {
                              setState(() {
                                if (_videoController!.value.volume > 0) {
                                  _videoController!.setVolume(0.0);
                                } else {
                                  _videoController!.setVolume(1.0);
                                }
                              });
                            },
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

  /// 3. REPRODUCTOR REAL DE AUDIO (Requisito 4)
  Widget _buildAudioPlayer(ResourceItem item) {
    final bool hasController = _audioController != null && _isAudioInitialized;
    final bool isPlaying = hasController && _audioController!.value.isPlaying;
    final Duration audioPos = hasController ? _audioController!.value.position : Duration.zero;
    final Duration audioDur = hasController ? _audioController!.value.duration : Duration.zero;

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
                'Audio Clase • ${item.formattedSize}',
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
                      final double factor = (isPlaying)
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
                        value: audioPos.inSeconds
                            .toDouble()
                            .clamp(0.0, audioDur.inSeconds.toDouble() > 0 ? audioDur.inSeconds.toDouble() : 1.0),
                        min: 0.0,
                        max: audioDur.inSeconds.toDouble() > 0
                            ? audioDur.inSeconds.toDouble()
                            : 1.0,
                        onChanged: (val) {
                          _audioController?.seekTo(Duration(seconds: val.toInt()));
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(audioPos),
                            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                          ),
                          Text(
                            _formatDuration(audioDur),
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
                      final newPos = audioPos - const Duration(seconds: 10);
                      _audioController?.seekTo(newPos > Duration.zero ? newPos : Duration.zero);
                    },
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      if (_audioController == null) {
                        _initResourceEngines();
                        return;
                      }
                      setState(() {
                        if (isPlaying) {
                          _audioController!.pause();
                        } else {
                          _audioController!.play();
                        }
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
                        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: 26,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.forward_10_rounded, size: 22),
                    onPressed: () {
                      final newPos = audioPos + const Duration(seconds: 10);
                      _audioController?.seekTo(newPos);
                    },
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      hasController && _audioController!.value.volume > 0
                          ? Icons.volume_up_rounded
                          : Icons.volume_off_rounded,
                      size: 20,
                      color: AppColors.accentAmber,
                    ),
                    onPressed: () {
                      if (hasController) {
                        setState(() {
                          if (_audioController!.value.volume > 0) {
                            _audioController!.setVolume(0.0);
                          } else {
                            _audioController!.setVolume(1.0);
                          }
                        });
                      }
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

  /// 4. LECTOR REAL DE ARCHIVOS PDF (Requisito 3 - flutter_pdfview)
  Widget _buildPdfViewer(ResourceItem item) {
    final file = File(item.path);
    final exists = file.existsSync();

    if (!exists) {
      return Center(
        child: Text('Archivo PDF no encontrado: ${item.path}'),
      );
    }

    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // Visor Nativo de PDF
          PDFView(
            filePath: file.path,
            enableSwipe: true,
            swipeHorizontal: false,
            autoSpacing: true,
            pageFling: true,
            pageSnap: true,
            defaultPage: _pdfCurrentPage,
            fitPolicy: FitPolicy.BOTH,
            preventLinkNavigation: false,
            onRender: (pages) {
              setState(() {
                _pdfTotalPages = pages ?? 0;
                _pdfReady = true;
              });
            },
            onViewCreated: (controller) {
              _pdfViewController = controller;
            },
            onPageChanged: (page, total) {
              setState(() {
                _pdfCurrentPage = page ?? 0;
                _pdfTotalPages = total ?? 0;
              });
            },
            onError: (error) {
              debugPrint('Error en PDFView: $error');
            },
          ),

          // Barra inferior de control de páginas PDF
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
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, size: 20),
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      padding: EdgeInsets.zero,
                      onPressed: _pdfReady && _pdfCurrentPage > 0
                          ? () => _pdfViewController?.setPage(_pdfCurrentPage - 1)
                          : null,
                    ),
                    Text(
                      'Pág. ${_pdfCurrentPage + 1} de ${_pdfTotalPages > 0 ? _pdfTotalPages : 1}',
                      style: const TextStyle(fontSize: 10.5, color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, size: 20),
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      padding: EdgeInsets.zero,
                      onPressed: _pdfReady && _pdfCurrentPage < _pdfTotalPages - 1
                          ? () => _pdfViewController?.setPage(_pdfCurrentPage + 1)
                          : null,
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

  /// 5. LECTOR REAL DE ARCHIVOS WORD (.docx) (Requisito 4)
  Widget _buildDocxViewer(ResourceItem item) {
    if (!_isDocxLoaded) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 10),
            Text(
              'Extrayendo documento Word: ${item.name}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Container(
      color: const Color(0xFF1E222D),
      child: Center(
        child: Container(
          width: 500,
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            itemCount: _docxParagraphs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final text = _docxParagraphs[index];
              final isHeader = index == 0 || text.length < 50 && !text.endsWith('.');
              return Text(
                text,
                style: TextStyle(
                  fontSize: isHeader ? 14.5 : 12.0,
                  fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
                  color: isHeader ? const Color(0xFF0F172A) : const Color(0xFF334155),
                  height: 1.4,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// 6. VISOR DE DIAPOSITIVAS FLUTTER (.eslide / .json)
  Widget _buildSlideViewer(ResourceItem item) {
    return Container(
      color: const Color(0xFF0F172A),
      child: Center(
        child: Container(
          width: 440,
          height: 270,
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 12,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'SLIDE EDUCATIVO',
                      style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  Text(
                    item.formattedSize,
                    style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                item.name,
                style: AppTextStyles.sectionTitle.copyWith(fontSize: 15),
              ),
              const SizedBox(height: 6),
              const Text(
                'Presentación interactiva para proyección en pizarra digital',
                style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.touch_app_rounded, size: 16, color: AppColors.primary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Diapositiva lista para interactuar y rayar con la pizarra digital.',
                        style: TextStyle(fontSize: 9.5, color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
