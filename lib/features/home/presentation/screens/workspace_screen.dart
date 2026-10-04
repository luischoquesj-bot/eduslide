import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../explorer/data/storage_service.dart';
import '../../../explorer/domain/models/grade_folder.dart';
import '../../../explorer/domain/models/resource_item.dart';
import '../../../explorer/domain/models/topic_folder.dart';
import '../../../explorer/presentation/widgets/folder_picker_dialog.dart';
import '../../../explorer/presentation/widgets/storage_source_dialog.dart';
import '../../../media_viewers/presentation/widgets/interactive_resource_viewer.dart';
import '../../../media_viewers/presentation/widgets/left_media_carousel.dart';
import '../../../media_viewers/presentation/widgets/right_media_carousel.dart';
import '../../../whiteboard/presentation/widgets/whiteboard_canvas.dart';
import '../widgets/control_bottom_sheet.dart';
import '../widgets/welcome_card.dart';

/// Pantalla Principal del Espacio de Trabajo (Workspace) de EduSlide.
/// Proporciona un entorno horizontal inmersivo de pantalla completa para proyectores,
/// con barras laterales conectadas al motor de archivos local/USB y pizarra central adaptable.
class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({super.key});

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  // Servicio de almacenamiento y exploración de archivos
  final StorageService _storageService = StorageService();

  // Estado del explorador curricular
  StorageUnit? _currentStorageUnit;
  TopicFolder? _currentTopic;
  ResourceItem? _selectedResource;

  // Recurso del carrusel derecho cargado en nuevo lienzo encima de la pizarra (Requisito 1)
  ResourceItem? _whiteboardOverlayResource;
  final GlobalKey _whiteboardKey = GlobalKey();

  // Estado de distribución de pantalla y proporción del recurso activo
  ScreenDistributionMode _layoutMode = ScreenDistributionMode.standard801010;
  double _resourceSplitRatio = 0.50; // 0.50 (50%), 0.75 (75%), 1.00 (100%)
  bool _isResourceOnLeft = false; // false = derecha de la pizarra, true = izquierda de la pizarra

  // Estado del mando remoto
  bool _isRemoteConnected = false;

  // Control de visualización de la tarjeta de bienvenida
  bool _showWelcomeCard = true;

  @override
  void initState() {
    super.initState();
    _initializeStorage();
  }

  /// Inicializa la detección de memorias y carga el tema curricular inicial
  Future<void> _initializeStorage() async {
    await _storageService.requestPermissions();
    final units = await _storageService.detectStorageUnits();

    StorageUnit defaultUnit = units.first;
    // Si hay un USB conectado, lo detectamos
    final usbUnit = units.where((u) => u.type == StorageType.usb).firstOrNull;
    final hasUsb = usbUnit != null;
    if (hasUsb) {
      defaultUnit = usbUnit;
    }

    final grades = await _storageService.scanCurricularStructure(defaultUnit.path);
    GradeFolder? defaultGrade = grades.isNotEmpty ? grades.first : null;
    TopicFolder? defaultTopic =
        (defaultGrade != null && defaultGrade.topics.isNotEmpty)
            ? defaultGrade.topics.first
            : null;

    if (mounted) {
      setState(() {
        _currentStorageUnit = defaultUnit;
        _currentTopic = defaultTopic;
      });

      // Si se detectó una unidad USB al arrancar, consultar activamente al profesor
      if (hasUsb) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _askStorageSource(units);
          }
        });
      }
    }
  }

  /// Consulta al docente si desea leer desde la Memoria USB detectada o desde la Memoria Interna
  void _askStorageSource([List<StorageUnit>? availableUnits]) async {
    final units = availableUnits ?? await _storageService.detectStorageUnits();
    if (!mounted) return;

    StorageSourceDialog.show(
      context,
      units: units,
      onSelectUnit: (selectedUnit) {
        setState(() {
          _currentStorageUnit = selectedUnit;
        });
        // Abrir inmediatamente el explorador de carpetas en la unidad elegida
        _openFolderPickerDialog(initialUnit: selectedUnit);
      },
    );
  }

  /// Abre el explorador táctil de carpetas para seleccionar cualquier directorio del USB o almacenamiento interno
  void _openFolderPickerDialog({StorageUnit? initialUnit}) {
    FolderPickerDialog.show(
      context,
      storageService: _storageService,
      initialUnit: initialUnit ?? _currentStorageUnit,
      initialPath: _currentTopic?.path,
      onFolderSelected: (unit, folder) {
        setState(() {
          _currentStorageUnit = unit;
          _currentTopic = folder;
          _showWelcomeCard = false; // Quitar tarjeta para visualizar la clase de inmediato
        });

        final leftCount = folder.leftPanelResources.length;
        final rightCount = folder.rightPanelResources.length;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  unit.type == StorageType.usb ? Icons.usb_rounded : Icons.folder_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Carpeta cargada: "${folder.name}" ($leftCount Slides/PDFs • $rightCount Medios)',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  void _onResourceSelected(ResourceItem item) {
    setState(() {
      _selectedResource = item;
      // Si la pizarra estaba ocupando el 100% libre, cambia a estándar para mostrar el recurso junto al espacio
      if (_layoutMode == ScreenDistributionMode.full100) {
        _layoutMode = ScreenDistributionMode.standard801010;
      }
    });
  }

  /// Selección de recursos del carrusel derecho (Imágenes, Videos, Audios, etc.) (Requisito 1):
  /// Se cargan en un nuevo lienzo encima de donde se encuentre la pizarra reemplazándola por completo,
  /// ocupando el mismo espacio y proporción asignada a la pizarra, sin borrar lo que esté dibujado en ella.
  void _onRightResourceSelected(ResourceItem item) {
    setState(() {
      _whiteboardOverlayResource = item;
      _showWelcomeCard = false;
    });
  }

  /// Construye el lienzo de la pizarra con soporte de superposición total de recursos del carrusel derecho.
  /// Mantiene la pizarra siempre montada debajo para no borrar ningún trazo.
  Widget _buildWhiteboardArea({bool isStandalone = false}) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Pizarra de dibujo activa e inalterada
        WhiteboardCanvas(
          key: _whiteboardKey,
          isStandalone: isStandalone,
        ),

        // 2. Nuevo lienzo superpuesto con el recurso del carrusel derecho (lo cubre por completo)
        if (_whiteboardOverlayResource != null)
          Positioned.fill(
            child: InteractiveResourceViewer(
              resource: _whiteboardOverlayResource!,
              currentRatio: 1.0,
              showLayoutControls: false,
              onClose: () {
                setState(() {
                  _whiteboardOverlayResource = null;
                });
              },
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: false,
        bottom: false,
        left: false,
        right: false,
        child: Stack(
          children: [
            // 1. Capa de layout horizontal adaptable ocupando el 100% de la pantalla (Sin AppBar)
            Positioned.fill(
              child: _buildAdaptiveWorkspaceLayout(),
            ),

            // 2. Tarjeta central de bienvenida (si está activa sobre la pizarra)
            if (_showWelcomeCard)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.55),
                  child: WelcomeCard(
                    onStartWhiteboard: () {
                      setState(() {
                        _showWelcomeCard = false;
                      });
                    },
                    onExploreMaterials: () {
                      setState(() {
                        _showWelcomeCard = false;
                      });
                      _askStorageSource();
                    },
                  ),
                ),
              ),

            // 3. Botón Flotante Central Inferior superpuesto directamente sobre la pizarra
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Center(
                child: _buildFloatingControlPill(),
              ),
            ),

            // 4. Atajo flotante discreto en esquina superior derecha para reabrir bienvenida
            if (!_showWelcomeCard)
              Positioned(
                top: 6,
                right: 6,
                child: Tooltip(
                  message: 'Mostrar Inicio / Bienvenida',
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _showWelcomeCard = true;
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.borderSubtle.withValues(alpha: 0.6),
                        ),
                      ),
                      child: const Icon(
                        Icons.help_outline_rounded,
                        size: 15,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Distribución horizontal de la pantalla con vinculación de listas de recursos reales
  Widget _buildAdaptiveWorkspaceLayout() {
    final leftResources = _currentTopic?.leftPanelResources;
    final rightResources = _currentTopic?.rightPanelResources;

    switch (_layoutMode) {
      case ScreenDistributionMode.full100:
        return Padding(
          padding: const EdgeInsets.all(1.5),
          child: _selectedResource != null
              ? InteractiveResourceViewer(
                  resource: _selectedResource!,
                  currentRatio: 1.0,
                  isResourceOnLeft: _isResourceOnLeft,
                  onClose: () {
                    setState(() {
                      _selectedResource = null;
                    });
                  },
                  onRatioChanged: (ratio) {
                    setState(() {
                      _resourceSplitRatio = ratio;
                      if (ratio < 0.95) {
                        _layoutMode = ScreenDistributionMode.standard801010;
                      }
                    });
                  },
                  onSideToggle: (onLeft) {
                    setState(() {
                      _isResourceOnLeft = onLeft;
                    });
                  },
                )
              : _buildWhiteboardArea(isStandalone: true),
        );

      case ScreenDistributionMode.split5050:
        return Padding(
          padding: const EdgeInsets.all(1.5),
          child: _buildSplitLayout(resourceFlex: 50, whiteboardFlex: 50),
        );

      case ScreenDistributionMode.split7525:
        return Padding(
          padding: const EdgeInsets.all(1.5),
          child: _buildSplitLayout(resourceFlex: 75, whiteboardFlex: 25),
        );

      case ScreenDistributionMode.standard801010:
        return Padding(
          padding: const EdgeInsets.all(1.5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Carrusel lateral izquierdo (PDFs y Diapositivas Flutter)
              Expanded(
                flex: 10,
                child: LeftMediaCarousel(
                  resources: leftResources,
                  onResourceTap: _onResourceSelected,
                  onOpenTopicSelector: () => _openFolderPickerDialog(),
                ),
              ),

              // 2. Área Central: Espacio de trabajo interactivo adaptable (Pizarra + Recurso cargado)
              Expanded(
                flex: 80,
                child: _buildCenterWorkspace(),
              ),

              // 3. Carrusel lateral derecho (Imágenes, Videos y Audios)
              // Al tocar un recurso, se carga sobre la pizarra en un nuevo lienzo (Requisito 1)
              Expanded(
                flex: 10,
                child: RightMediaCarousel(
                  resources: rightResources,
                  onResourceTap: _onRightResourceSelected,
                  onOpenTopicSelector: () => _openFolderPickerDialog(),
                ),
              ),
            ],
          ),
        );
    }
  }

  /// Área central del modo estándar: muestra la pizarra completa si no hay recurso seleccionado,
  /// o divide la pantalla entre el recurso activo (interactivo y real) y la pizarra según el porcentaje elegido.
  Widget _buildCenterWorkspace() {
    if (_selectedResource == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.0),
        child: _buildWhiteboardArea(),
      );
    }

    final viewer = InteractiveResourceViewer(
      resource: _selectedResource!,
      currentRatio: _resourceSplitRatio,
      isResourceOnLeft: _isResourceOnLeft,
      onClose: () {
        setState(() {
          _selectedResource = null;
        });
      },
      onRatioChanged: (ratio) {
        setState(() {
          _resourceSplitRatio = ratio;
        });
      },
      onSideToggle: (onLeft) {
        setState(() {
          _isResourceOnLeft = onLeft;
        });
      },
    );

    if (_resourceSplitRatio >= 0.95) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.0),
        child: viewer,
      );
    }

    final int resourceFlex = (_resourceSplitRatio * 100).toInt().clamp(20, 80);
    final int whiteboardFlex = 100 - resourceFlex;

    final resourceWidget = Expanded(
      flex: resourceFlex,
      child: viewer,
    );

    final whiteboardWidget = Expanded(
      flex: 100,
      child: _buildWhiteboardArea(),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _isResourceOnLeft
            ? [resourceWidget, const SizedBox(width: 4), Expanded(flex: whiteboardFlex, child: whiteboardWidget)]
            : [Expanded(flex: whiteboardFlex, child: whiteboardWidget), const SizedBox(width: 4), resourceWidget],
      ),
    );
  }

  /// Distribución dividida proporcional para modos 50/50 y 75/25
  Widget _buildSplitLayout({required int resourceFlex, required int whiteboardFlex}) {
    if (_selectedResource == null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: whiteboardFlex,
            child: _buildWhiteboardArea(),
          ),
          const SizedBox(width: 3),
          Expanded(
            flex: resourceFlex,
            child: _buildSplitResourceView(),
          ),
        ],
      );
    }

    final viewer = InteractiveResourceViewer(
      resource: _selectedResource!,
      currentRatio: resourceFlex / (resourceFlex + whiteboardFlex),
      isResourceOnLeft: _isResourceOnLeft,
      onClose: () {
        setState(() {
          _selectedResource = null;
        });
      },
      onRatioChanged: (ratio) {
        setState(() {
          _resourceSplitRatio = ratio;
          if (ratio >= 0.95) {
            _layoutMode = ScreenDistributionMode.full100;
          }
        });
      },
      onSideToggle: (onLeft) {
        setState(() {
          _isResourceOnLeft = onLeft;
        });
      },
    );

    final resourceWidget = Expanded(flex: resourceFlex, child: viewer);
    final whiteboardWidget = Expanded(flex: 100, child: _buildWhiteboardArea());

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _isResourceOnLeft
          ? [resourceWidget, const SizedBox(width: 4), Expanded(flex: whiteboardFlex, child: whiteboardWidget)]
          : [Expanded(flex: whiteboardFlex, child: whiteboardWidget), const SizedBox(width: 4), resourceWidget],
    );
  }

  /// Vista complementaria para el modo 50/50 y 75/25:
  /// Muestra una cuadrícula táctil con todos los recursos disponibles (PDFs, Slides, Fotos, Videos, Audios, Docs)
  /// de la carpeta o memoria activa para que el maestro seleccione y coloque al instante en ese espacio.
  Widget _buildSplitResourceView() {
    final allResources = [
      ...?_currentTopic?.leftPanelResources,
      ...?_currentTopic?.rightPanelResources,
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderHighlight, width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabecera con título de la carpeta activa y botón para cambiar de carpeta/USB
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: const BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.folder_open_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _currentTopic?.name ?? 'Recursos Educativos',
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.cardTitle.copyWith(fontSize: 12.5),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openFolderPickerDialog(),
                  icon: const Icon(Icons.storage_rounded, size: 14),
                  label: const Text('Cambiar Carpeta / USB', style: TextStyle(fontSize: 10.5)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  onPressed: () {
                    setState(() {
                      _layoutMode = ScreenDistributionMode.standard801010;
                    });
                  },
                ),
              ],
            ),
          ),

          // Lista de recursos encontrados o botón de apertura
          Expanded(
            child: allResources.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.folder_shared_rounded,
                            size: 46,
                            color: AppColors.primary.withValues(alpha: 0.6),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'No se encontraron archivos en esta carpeta',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.sectionTitle,
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Selecciona otra carpeta de tu memoria interna o memoria USB para cargar recursos.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            onPressed: () => _openFolderPickerDialog(),
                            icon: const Icon(Icons.folder_open_rounded, size: 16),
                            label: const Text('Elegir Carpeta o USB'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(8),
                    physics: const BouncingScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 140,
                      childAspectRatio: 0.95,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: allResources.length,
                    itemBuilder: (context, index) {
                      final item = allResources[index];
                      return InkWell(
                        onTap: () {
                          _onResourceSelected(item);
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: item.accentColor.withValues(alpha: 0.4),
                              width: 1.0,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    color: item.accentColor.withValues(alpha: 0.12),
                                    child: Center(
                                      child: Icon(
                                        item.icon,
                                        size: 28,
                                        color: item.accentColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    item.extension.toUpperCase().replaceAll('.', ''),
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color: item.accentColor,
                                    ),
                                  ),
                                  Text(
                                    item.formattedSize,
                                    style: const TextStyle(fontSize: 8, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// Botón Flotante Central Inferior compacto, situado delante de la pizarra
  Widget _buildFloatingControlPill() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openControlBottomSheet,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.65),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _isRemoteConnected
                      ? AppColors.accentGreen
                      : AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.dashboard_customize_rounded,
                size: 13,
                color: AppColors.primary,
              ),
              const SizedBox(width: 5),
              const Text(
                'Control de Espacio',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 3),
              const Icon(
                Icons.keyboard_arrow_up_rounded,
                size: 15,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openControlBottomSheet() {
    ControlBottomSheet.show(
      context,
      currentLayout: _layoutMode,
      onLayoutChanged: (newLayout) {
        setState(() {
          _layoutMode = newLayout;
        });
      },
      isRemoteConnected: _isRemoteConnected,
      onRemoteToggled: (connected) {
        setState(() {
          _isRemoteConnected = connected;
        });
      },
      currentSplitRatio: _resourceSplitRatio,
      onSplitRatioChanged: (ratio) {
        setState(() {
          _resourceSplitRatio = ratio;
          if (ratio >= 0.95 && _layoutMode == ScreenDistributionMode.full100) {
            // Se mantiene en pantalla completa
          } else if (_layoutMode == ScreenDistributionMode.full100 && ratio < 0.95) {
            _layoutMode = ScreenDistributionMode.standard801010;
          }
        });
      },
      isResourceOnLeft: _isResourceOnLeft,
      onResourceSideChanged: (onLeft) {
        setState(() {
          _isResourceOnLeft = onLeft;
        });
      },
      hasActiveResource: _selectedResource != null,
      onCloseResource: () {
        setState(() {
          _selectedResource = null;
        });
      },
    );
  }
}
