import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../explorer/data/storage_service.dart';
import '../../../explorer/domain/models/grade_folder.dart';
import '../../../explorer/domain/models/resource_item.dart';
import '../../../explorer/domain/models/topic_folder.dart';
import '../../../explorer/presentation/widgets/topic_selector_dialog.dart';
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

  // Estado de distribución de pantalla
  ScreenDistributionMode _layoutMode = ScreenDistributionMode.standard801010;

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

      // Si se detectó una unidad USB al arrancar, avisamos discretamente al profesor
      if (hasUsb) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Memoria USB detectada: ${defaultUnit.label}. Recursos listos.',
            ),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Explorar',
              onPressed: _openTopicSelectorDialog,
            ),
          ),
        );
      }
    }
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
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(item.icon, color: item.accentColor, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Cargado: ${item.name} (${item.formattedSize})',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 1400),
        behavior: SnackBarBehavior.floating,
      ),
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
                        _layoutMode = ScreenDistributionMode.split5050;
                      });
                      _openTopicSelectorDialog();
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

            // 4. Barra flotante superior de estado curricular (Discreta, pegada arriba al centro)
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

  /// Píldora interactiva superior que muestra el tema curricular activo y acceso al selector
  Widget _buildCurricularStatusPill() {
    final gradeText = _currentGrade?.name ?? '1ero Sec.';
    final topicText = _currentTopic?.name ?? 'Lengua Castellana';
    final isUsb = (_currentStorageUnit?.type == StorageType.usb) || _hasUsbDetected;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openTopicSelectorDialog,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isUsb
                  ? AppColors.accentGreen.withValues(alpha: 0.6)
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
                isUsb ? Icons.usb_rounded : Icons.school_rounded,
                size: 13,
                color: isUsb ? AppColors.accentGreen : AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                '$gradeText • $topicText',
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
        return const Padding(
          padding: EdgeInsets.all(1.5),
          child: WhiteboardCanvas(isStandalone: true),
        );

      case ScreenDistributionMode.split5050:
        return Padding(
          padding: const EdgeInsets.all(1.5),
          child: Row(
            children: [
              const Expanded(
                flex: 50,
                child: WhiteboardCanvas(),
              ),
              const SizedBox(width: 3),
              Expanded(
                flex: 50,
                child: _buildSplitResourceView(),
              ),
            ],
          ),
        );

      case ScreenDistributionMode.split7525:
        return Padding(
          padding: const EdgeInsets.all(1.5),
          child: Row(
            children: [
              const Expanded(
                flex: 75,
                child: WhiteboardCanvas(),
              ),
              const SizedBox(width: 3),
              Expanded(
                flex: 25,
                child: LeftMediaCarousel(
                  resources: leftResources,
                  onResourceTap: _onResourceSelected,
                  onOpenTopicSelector: _openTopicSelectorDialog,
                ),
              ),
            ],
          ),
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
                  onOpenTopicSelector: _openTopicSelectorDialog,
                ),
              ),

              // 2. Área Central: Pizarra
              const Expanded(
                flex: 80,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 2.0),
                  child: WhiteboardCanvas(),
                ),
              ),

              // 3. Carrusel lateral derecho (Imágenes, Videos y Audios)
              Expanded(
                flex: 10,
                child: RightMediaCarousel(
                  resources: rightResources,
                  onResourceTap: _onResourceSelected,
                  onOpenTopicSelector: _openTopicSelectorDialog,
                ),
              ),
            ],
          ),
        );
    }
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
    );
  }
}
