import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Modelo de datos para un trazo individual en la pizarra.
class WhiteboardStroke {
  final List<Offset> points;
  final Color color;
  final double width;

  WhiteboardStroke({
    required this.points,
    required this.color,
    required this.width,
  });
}

/// Modos de visualización de la pizarra.
enum WhiteboardMode {
  white, // Fondo blanco (marcador oscuro)
  schoolChalkboard, // Fondo verde pizarra oscuro escolar (tiza clara)
}

/// Lienzo interactivo de pizarra digital con dibujo táctil/puntero fluido,
/// borrador táctil en esquina inferior derecha que borra por repaso,
/// botón único conmutador de estado de pizarra y botón superior para limpiar todo.
class WhiteboardCanvas extends StatefulWidget {
  final VoidCallback? onToggleFullscreen;
  final bool isStandalone;

  const WhiteboardCanvas({
    super.key,
    this.onToggleFullscreen,
    this.isStandalone = false,
  });

  @override
  State<WhiteboardCanvas> createState() => _WhiteboardCanvasState();
}

class _WhiteboardCanvasState extends State<WhiteboardCanvas> {
  // 1. Estado de modo de pizarra: inicia por defecto en Pizarra Blanca
  WhiteboardMode _mode = WhiteboardMode.white;

  // Lista de trazos guardados y trazo en progreso
  final List<WhiteboardStroke> _strokes = [];
  List<Offset> _currentPoints = [];

  // Configuración de herramienta activa
  late Color _currentColor;
  double _strokeWidth = 3.5;

  // Modo borrador activo desde la esquina inferior derecha
  bool _isEraser = false;

  // Posición del cursor del borrador para feedback visual
  Offset? _eraserFeedbackPos;

  @override
  void initState() {
    super.initState();
    _syncColorWithMode();
  }

  /// Sincroniza el color predeterminado del trazo según el modo de pizarra
  void _syncColorWithMode() {
    if (_mode == WhiteboardMode.schoolChalkboard) {
      _currentColor = AppColors.chalkboardStrokeDefault;
    } else {
      _currentColor = AppColors.whiteboardStrokeDefault;
    }
  }

  /// Conmuta el estado de la pizarra entre Blanca y Oscura
  void _toggleWhiteboardMode() {
    setState(() {
      if (_mode == WhiteboardMode.white) {
        _mode = WhiteboardMode.schoolChalkboard;
      } else {
        _mode = WhiteboardMode.white;
      }
      _syncColorWithMode();
    });
  }

  void _onPanStart(DragStartDetails details) {
    if (_isEraser) {
      _eraseStrokesNear(details.localPosition);
      setState(() {
        _eraserFeedbackPos = details.localPosition;
      });
    } else {
      setState(() {
        _currentPoints = [details.localPosition];
      });
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isEraser) {
      _eraseStrokesNear(details.localPosition);
      setState(() {
        _eraserFeedbackPos = details.localPosition;
      });
    } else {
      setState(() {
        _currentPoints.add(details.localPosition);
      });
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isEraser) {
      setState(() {
        _eraserFeedbackPos = null;
      });
    } else if (_currentPoints.isNotEmpty) {
      setState(() {
        _strokes.add(
          WhiteboardStroke(
            points: List.from(_currentPoints),
            color: _currentColor,
            width: _strokeWidth,
          ),
        );
        _currentPoints = [];
      });
    }
  }

  /// Borra trazos dividiendo los segmentos que repasa el borrador en tiempo real
  void _eraseStrokesNear(Offset pos) {
    const double radius = 24.0;
    final List<WhiteboardStroke> nextStrokes = [];
    bool changed = false;

    for (final stroke in _strokes) {
      List<Offset> currentSegment = [];
      for (final p in stroke.points) {
        if ((p - pos).distance <= radius) {
          changed = true;
          // Si el punto está dentro del radio del borrador, cortamos el trazo
          if (currentSegment.isNotEmpty) {
            nextStrokes.add(
              WhiteboardStroke(
                points: List.from(currentSegment),
                color: stroke.color,
                width: stroke.width,
              ),
            );
            currentSegment = [];
          }
        } else {
          currentSegment.add(p);
        }
      }
      if (currentSegment.isNotEmpty) {
        nextStrokes.add(
          WhiteboardStroke(
            points: List.from(currentSegment),
            color: stroke.color,
            width: stroke.width,
          ),
        );
      }
    }

    if (changed) {
      setState(() {
        _strokes.clear();
        _strokes.addAll(nextStrokes);
      });
    }
  }

  Color _getCanvasBackgroundColor() {
    return _mode == WhiteboardMode.schoolChalkboard
        ? AppColors.chalkboardBg
        : AppColors.whiteboardBg;
  }

  /// Borra todo lo rayado con marcador dejando el lienzo completamente limpio
  void _clearCanvas() {
    setState(() {
      _strokes.clear();
      _currentPoints.clear();
    });
  }

  void _undoStroke() {
    if (_strokes.isNotEmpty) {
      setState(() {
        _strokes.removeLast();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isChalk = _mode == WhiteboardMode.schoolChalkboard;
    final bgColor = _getCanvasBackgroundColor();
    final gridColor =
        isChalk ? AppColors.chalkboardGrid : AppColors.whiteboardGrid;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isChalk ? const Color(0xFF28483B) : const Color(0xFFCBD5E1),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            // 1. Capa de cuadrícula decorativa de fondo (estilo escolar/milimetrada)
            Positioned.fill(
              child: CustomPaint(
                painter: _GridPainter(
                  gridColor: gridColor.withValues(alpha: 0.35),
                  step: 32.0,
                ),
              ),
            ),

            // 2. Lienzo táctil interactivo de trazo libre y borrado por repaso
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: CustomPaint(
                  painter: _StrokePainter(
                    strokes: _strokes,
                    activePoints: _currentPoints,
                    activeColor: _currentColor,
                    activeWidth: _strokeWidth,
                  ),
                ),
              ),
            ),

            // 3. Feedback visual del borrador cuando está activo y en movimiento
            if (_isEraser && _eraserFeedbackPos != null)
              Positioned(
                left: _eraserFeedbackPos!.dx - 24,
                top: _eraserFeedbackPos!.dy - 24,
                child: IgnorePointer(
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: 0.25),
                      border: Border.all(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.auto_fix_normal_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),

            // 4. Barra de control superior de la pizarra
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Si el ancho del contenedor es compacto o mediano
                  if (constraints.maxWidth < 840) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          // Botón único conmutador de pizarra
                          _buildSingleModeToggleButton(isChalk),
                          const SizedBox(width: 8),

                          // Botón a lado derecho para borrar toda la pizarra
                          _buildClearAllButton(isChalk),
                          const SizedBox(width: 12),

                          // Barra de herramientas de dibujo
                          _buildToolbar(isChalk),
                        ],
                      ),
                    );
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Grupo izquierdo: Conmutador único + Botón de borrar toda la pizarra
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildSingleModeToggleButton(isChalk),
                          const SizedBox(width: 8),
                          _buildClearAllButton(isChalk),
                        ],
                      ),

                      // Grupo derecho: Barra de herramientas (colores, grosor, deshacer)
                      _buildToolbar(isChalk),
                    ],
                  );
                },
              ),
            ),

            // 5. Botón de borrador por repaso en la ESQUINA INFERIOR DERECHA
            Positioned(
              bottom: 12,
              right: 12,
              child: _buildEraserFloatingButton(isChalk),
            ),
          ],
        ),
      ),
    );
  }

  /// [Requisito 5]: Botón único que muestra solo el ícono:
  /// - Si está en pizarra blanca muestra el ícono de noche/oscuro (Icons.dark_mode_rounded)
  /// - Si está en pizarra oscura muestra el ícono del sol (Icons.light_mode_rounded)
  Widget _buildSingleModeToggleButton(bool isChalk) {
    final activeBg = isChalk ? const Color(0xFF234235) : Colors.white;
    final icon = isChalk ? Icons.light_mode_rounded : Icons.dark_mode_rounded;
    final iconColor = isChalk ? Colors.amberAccent : const Color(0xFF1E293B);
    final tooltipText = isChalk
        ? 'Cambiar a Pizarra Blanca (Día)'
        : 'Cambiar a Pizarra Escolar Oscura (Noche)';

    return Tooltip(
      message: tooltipText,
      child: InkWell(
        onTap: _toggleWhiteboardMode,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: activeBg,
            shape: BoxShape.circle,
            border: Border.all(
              color: isChalk ? Colors.amberAccent.withValues(alpha: 0.6) : const Color(0xFF94A3B8),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            size: 17,
            color: iconColor,
          ),
        ),
      ),
    );
  }

  /// [Requisito 3]: Botón a lado derecho del selector para borrar toda la pizarra
  Widget _buildClearAllButton(bool isChalk) {
    return Tooltip(
      message: 'Borrar todo lo rayado con marcador',
      child: InkWell(
        onTap: _strokes.isEmpty && _currentPoints.isEmpty ? null : _clearCanvas,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: isChalk
                ? const Color(0xFF1E2F28).withValues(alpha: 0.9)
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _strokes.isEmpty
                  ? (isChalk ? Colors.white24 : Colors.black12)
                  : AppColors.accentRose.withValues(alpha: 0.7),
              width: 1.1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.delete_sweep_rounded,
                size: 15,
                color: _strokes.isEmpty
                    ? (isChalk ? Colors.white30 : Colors.black26)
                    : AppColors.accentRose,
              ),
              const SizedBox(width: 5),
              Text(
                'Borrar Pizarra',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _strokes.isEmpty
                      ? (isChalk ? Colors.white30 : Colors.black26)
                      : (isChalk ? Colors.white : const Color(0xFF0F172A)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// [Requisito 2]: Botón de borrador situado abajo en la esquina inferior derecha
  /// que borra lo que se ha pintado con el marcador conforme se repasa por donde se pintó
  Widget _buildEraserFloatingButton(bool isChalk) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _isEraser = !_isEraser;
          });
        },
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _isEraser
                ? AppColors.primary
                : (isChalk
                    ? const Color(0xFF0F1E19).withValues(alpha: 0.92)
                    : const Color(0xFFE2E8F0).withValues(alpha: 0.95)),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _isEraser
                  ? Colors.white
                  : (isChalk ? const Color(0xFF2A4D3F) : const Color(0xFF94A3B8)),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _isEraser
                    ? AppColors.primary.withValues(alpha: 0.45)
                    : Colors.black.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_fix_normal_rounded,
                size: 16,
                color: _isEraser
                    ? const Color(0xFF0F172A)
                    : (isChalk ? Colors.white : const Color(0xFF1E293B)),
              ),
              const SizedBox(width: 7),
              Text(
                _isEraser ? 'Borrando...' : 'Borrador',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: _isEraser
                      ? const Color(0xFF0F172A)
                      : (isChalk ? Colors.white : const Color(0xFF1E293B)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Barra flotante con selector de colores de marcador/tiza, grosor y deshacer
  Widget _buildToolbar(bool isChalk) {
    final colors = isChalk
        ? [
            const Color(0xFFFFFFFF), // Tiza blanca
            const Color(0xFFFDE047), // Tiza amarilla
            const Color(0xFF38BDF8), // Tiza cian
            const Color(0xFFF472B6), // Tiza rosa pastel
            const Color(0xFF4ADE80), // Tiza verde claro
          ]
        : [
            const Color(0xFF0F172A), // Rotulador negro pizarra
            const Color(0xFF2563EB), // Azul marcador
            const Color(0xFFDC2626), // Rojo marcador
            const Color(0xFF059669), // Verde marcador
            const Color(0xFF7C3AED), // Púrpura
          ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isChalk
            ? const Color(0xFF0F1E19).withValues(alpha: 0.85)
            : const Color(0xFFE2E8F0).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isChalk
              ? const Color(0xFF2A4D3F)
              : const Color(0xFFCBD5E1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Paleta de colores circulares
          for (final color in colors) ...[
            GestureDetector(
              onTap: () {
                setState(() {
                  _currentColor = color;
                  _isEraser = false;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _currentColor == color && !_isEraser
                        ? AppColors.primary
                        : Colors.white38,
                    width: _currentColor == color && !_isEraser ? 2.5 : 1,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(width: 8),

          // Selector de grosor
          _toolbarIconButton(
            icon: Icons.line_weight_rounded,
            tooltip: 'Grosor (${_strokeWidth.toInt()}px)',
            isActive: false,
            isChalk: isChalk,
            onPressed: () {
              setState(() {
                if (_strokeWidth == 2.5) {
                  _strokeWidth = 4.5;
                } else if (_strokeWidth == 4.5) {
                  _strokeWidth = 8.0;
                } else {
                  _strokeWidth = 2.5;
                }
              });
            },
          ),

          // Deshacer trazo
          _toolbarIconButton(
            icon: Icons.undo_rounded,
            tooltip: 'Deshacer último trazo',
            isActive: false,
            isChalk: isChalk,
            onPressed: _strokes.isEmpty ? null : _undoStroke,
          ),
        ],
      ),
    );
  }

  Widget _toolbarIconButton({
    required IconData icon,
    required String tooltip,
    required bool isActive,
    required bool isChalk,
    required VoidCallback? onPressed,
  }) {
    final activeColor = AppColors.primary;
    final defaultColor = isChalk ? Colors.white70 : const Color(0xFF334155);

    return Tooltip(
      message: tooltip,
      child: IconButton(
        padding: const EdgeInsets.all(4),
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        icon: Icon(
          icon,
          size: 18,
          color: onPressed == null
              ? (isChalk ? Colors.white24 : Colors.black26)
              : (isActive ? activeColor : defaultColor),
        ),
        onPressed: onPressed,
      ),
    );
  }
}

/// CustomPainter para renderizar la cuadrícula milimetrada de fondo
class _GridPainter extends CustomPainter {
  final Color gridColor;
  final double step;

  _GridPainter({required this.gridColor, required this.step});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;

    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.gridColor != gridColor || oldDelegate.step != step;
}

/// CustomPainter para trazos de tiza/rotulador con uniones redondeadas
class _StrokePainter extends CustomPainter {
  final List<WhiteboardStroke> strokes;
  final List<Offset> activePoints;
  final Color activeColor;
  final double activeWidth;

  _StrokePainter({
    required this.strokes,
    required this.activePoints,
    required this.activeColor,
    required this.activeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      _drawPath(canvas, stroke.points, stroke.color, stroke.width);
    }
    if (activePoints.isNotEmpty) {
      _drawPath(canvas, activePoints, activeColor, activeWidth);
    }
  }

  void _drawPath(
    Canvas canvas,
    List<Offset> points,
    Color color,
    double strokeWidth,
  ) {
    if (points.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    if (points.length == 1) {
      canvas.drawCircle(points.first, strokeWidth / 2, paint..style = PaintingStyle.fill);
      return;
    }

    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _StrokePainter oldDelegate) => true;
}
