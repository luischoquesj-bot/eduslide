import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../explorer/data/storage_service.dart';
import '../../../explorer/domain/models/grade_folder.dart';
import '../../../explorer/domain/models/resource_item.dart';
import '../../../explorer/domain/models/topic_folder.dart';
import '../../../explorer/presentation/widgets/folder_picker_dialog.dart';
import '../../../explorer/presentation/widgets/storage_source_dialog.dart';
import '../../../explorer/presentation/widgets/topic_selector_dialog.dart';
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
  GradeFolder? _currentGrade;
  TopicFolder? _currentTopic;
  ResourceItem? _selectedResource;
  bool _hasUsbDetected = false;

  // Estado de distribución de pantalla y proporción del recurso activo
  ScreenDistributionMode _layoutMode = ScreenDistributionMode.standard801010;
  double _resourceSplitRatio = 0.50; // 0.50 (50%), 0.75 (75%), 1.00 (100%)
  bool _isResourceOnLeft = false; // false = derecha de la pizarra, true = izquierda de la pizarra

  // Estado del mando remoto
  bool _isRemoteConnected = false;

  // Control de visualización de la tarjeta de bienvenida
  bool _showWelcomeCard = true;

  // Título del recurso activo
  String? _activeMediaTitle;

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
        _currentGrade = defaultGrade;
        _currentTopic = defaultTopic;
        _hasUsbDetected = hasUsb;
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

  void _openTopicSelectorDialog() {
    TopicSelectorDialog.show(
      context,
      storageService: _storageService,
      currentUnit: _currentStorageUnit,
      selectedGrade: _currentGrade,
      selectedTopic: _currentTopic,
      onTopicSelected: (unit, grade, topic) {
        setState(() {
          _currentStorageUnit = unit;
          _currentGrade = grade;
          _currentTopic = topic;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Tema activo: ${topic.name} (${grade.name})',
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  void _onResourceSelected(ResourceItem item) {
    setState(() {
      _selectedResource = item;
      _activeMediaTitle = item.name;
      // Si la pizarra estaba ocupando el 100% libre, cambia a estándar para mostrar el recurso junto al espacio
      if (_layoutMode == ScreenDistributionMode.full100) {
        _layoutMode = ScreenDistributionMode.standard801010;
      }
    });
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

            // 4. Barra flotante superior de estado curricular y carpeta activa
            Positioned(
              top: 6,
              left: 0,
              right: 0,
              child: Center(
                child: _buildCurricularStatusPill(),
              ),
            ),

            // 5. Atajo flotante discreto en esquina superior derecha para reabrir bienvenida
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

  /// Píldora interactiva superior que muestra la unidad y carpeta activa con acceso rápido al explorador
  Widget _buildCurricularStatusPill() {
    final unitText = _currentStorageUnit?.label ?? 'Almacenamiento';
    final folderText = _currentTopic?.name ?? 'Recursos de Clase';
    final isUsb = (_currentStorageUnit?.type == StorageType.usb) || _hasUsbDetected;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openFolderPickerDialog(),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isUsb
                  ? AppColors.accentGreen.withValues(alpha: 0.7)
                  : AppColors.borderHighlight,
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isUsb ? Icons.usb_rounded : Icons.folder_rounded,
                size: 13,
                color: isUsb ? AppColors.accentGreen : AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                '$unitText • $folderText',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.arrow_drop_down_rounded,
                size: 16,
                color: AppColors.textSecondary,
              ),
            ],
          ),
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
              : const WhiteboardCanvas(isStandalone: true),
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
              Expanded(
                flex: 10,
                child: RightMediaCarousel(
                  resources: rightResources,
                  onResourceTap: _onResourceSelected,
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
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 2.0),
        child: WhiteboardCanvas(),
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

    final whiteboardWidget = const Expanded(
      flex: 100,
      child: WhiteboardCanvas(),
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
            child: const WhiteboardCanvas(),
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
    final whiteboardWidget = const Expanded(flex: 100, child: WhiteboardCanvas());

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _isResourceOnLeft
          ? [resourceWidget, const SizedBox(width: 4), Expanded(flex: whiteboardFlex, child: whiteboardWidget)]
          : [Expanded(flex: whiteboardFlex, child: whiteboardWidget), const SizedBox(width: 4), resourceWidget],
    );
  }

  /// Vista complementaria para el modo 50/50 con previsualización del recurso activo
  Widget _buildSplitResourceView() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderHighlight, width: 1.2),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Icon(
                  _selectedResource?.icon ?? Icons.auto_stories_rounded,
                  size: 16,
                  color: _selectedResource?.accentColor ?? AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedResource?.name ?? (_activeMediaTitle ?? 'Visor Didáctico Activo'),
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.cardTitle.copyWith(fontSize: 13),
                  ),
                ),
                if (_selectedResource != null)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _selectedResource!.accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _selectedResource!.categoryLabel,
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        color: _selectedResource!.accentColor,
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () {
                    setState(() {
                      _layoutMode = ScreenDistributionMode.standard801010;
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: (_selectedResource?.accentColor ?? AppColors.primary)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: (_selectedResource?.accentColor ?? AppColors.primary)
                              .withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        _selectedResource?.icon ?? Icons.touch_app_rounded,
                        size: 30,
                        color: _selectedResource?.accentColor ?? AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _selectedResource != null
                          ? _selectedResource!.name
                          : 'Material Didáctico Preparado',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.sectionTitle.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedResource != null
                          ? 'Tamaño: ${_selectedResource!.formattedSize} • Tipo: ${_selectedResource!.extension.toUpperCase()}'
                          : 'Selecciona un archivo del carrusel izquierdo o derecho',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _openTopicSelectorDialog,
                      icon: const Icon(Icons.folder_open_rounded, size: 15),
                      label: const Text('Cambiar Tema o Unidad'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
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
