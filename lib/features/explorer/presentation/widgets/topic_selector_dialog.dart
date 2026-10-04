import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../data/storage_service.dart';
import '../../domain/models/grade_folder.dart';
import '../../domain/models/topic_folder.dart';

/// Diálogo interactivo moderno para seleccionar el origen de almacenamiento
/// (Memoria Interna vs USB OTG) y el Tema Curricular de Secundaria.
class TopicSelectorDialog extends StatefulWidget {
  final StorageService storageService;
  final StorageUnit? currentUnit;
  final GradeFolder? selectedGrade;
  final TopicFolder? selectedTopic;
  final void Function(StorageUnit unit, GradeFolder grade, TopicFolder topic) onTopicSelected;

  const TopicSelectorDialog({
    super.key,
    required this.storageService,
    this.currentUnit,
    this.selectedGrade,
    this.selectedTopic,
    required this.onTopicSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required StorageService storageService,
    StorageUnit? currentUnit,
    GradeFolder? selectedGrade,
    TopicFolder? selectedTopic,
    required void Function(StorageUnit unit, GradeFolder grade, TopicFolder topic) onTopicSelected,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => TopicSelectorDialog(
        storageService: storageService,
        currentUnit: currentUnit,
        selectedGrade: selectedGrade,
        selectedTopic: selectedTopic,
        onTopicSelected: onTopicSelected,
      ),
    );
  }

  @override
  State<TopicSelectorDialog> createState() => _TopicSelectorDialogState();
}

class _TopicSelectorDialogState extends State<TopicSelectorDialog> {
  List<StorageUnit> _units = [];
  List<GradeFolder> _grades = [];
  StorageUnit? _activeUnit;
  GradeFolder? _activeGrade;
  TopicFolder? _activeTopic;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStorageAndStructure();
  }

  Future<void> _loadStorageAndStructure() async {
    setState(() => _isLoading = true);

    await widget.storageService.requestPermissions();
    final units = await widget.storageService.detectStorageUnits();

    StorageUnit chosenUnit = widget.currentUnit ?? units.first;
    // Si hay un USB conectado y no se especificó unidad, podemos priorizar el USB
    final usbUnit = units.where((u) => u.type == StorageType.usb).firstOrNull;
    if (widget.currentUnit == null && usbUnit != null) {
      chosenUnit = usbUnit;
    }

    final grades = await widget.storageService.scanCurricularStructure(chosenUnit.path);

    GradeFolder? defaultGrade;
    TopicFolder? defaultTopic;

    if (grades.isNotEmpty) {
      defaultGrade = widget.selectedGrade ?? grades.first;
      if (defaultGrade.topics.isNotEmpty) {
        defaultTopic = widget.selectedTopic ?? defaultGrade.topics.first;
      }
    }

    if (mounted) {
      setState(() {
        _units = units;
        _activeUnit = chosenUnit;
        _grades = grades;
        _activeGrade = defaultGrade;
        _activeTopic = defaultTopic;
        _isLoading = false;
      });
    }
  }

  Future<void> _changeStorageUnit(StorageUnit unit) async {
    setState(() {
      _activeUnit = unit;
      _isLoading = true;
    });

    final grades = await widget.storageService.scanCurricularStructure(unit.path);
    GradeFolder? defaultGrade = grades.isNotEmpty ? grades.first : null;
    TopicFolder? defaultTopic =
        (defaultGrade != null && defaultGrade.topics.isNotEmpty)
            ? defaultGrade.topics.first
            : null;

    if (mounted) {
      setState(() {
        _grades = grades;
        _activeGrade = defaultGrade;
        _activeTopic = defaultTopic;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final dialogWidth = (media.size.width * 0.75).clamp(420.0, 780.0);
    final dialogHeight = (media.size.height * 0.82).clamp(320.0, 520.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderHighlight, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // 1. Cabecera del diálogo con título y botón de cierre
            _buildHeader(),

            const Divider(color: AppColors.borderSubtle, height: 1),

            // 2. Selector de Origen de Almacenamiento (Interno vs USB OTG)
            _buildStorageUnitSelector(),

            const Divider(color: AppColors.borderSubtle, height: 1),

            // 3. Contenido: Selector de Año Escolar y Temas Curriculares
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    )
                  : _grades.isEmpty
                      ? _buildEmptyState()
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Columna izquierda: Años escolares (1ero Sec. a 6to Sec.)
                            Expanded(
                              flex: 38,
                              child: _buildGradesList(),
                            ),

                            const VerticalDivider(
                              color: AppColors.borderSubtle,
                              width: 1,
                            ),

                            // Columna derecha: Temas curriculares y botón de confirmación
                            Expanded(
                              flex: 62,
                              child: _buildTopicsList(),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.folder_copy_rounded,
              color: AppColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Explorador Didáctico • Secundaria',
              style: AppTextStyles.cardTitle,
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
    );
  }

  /// Selector de unidad de almacenamiento (Interna vs USB OTG)
  Widget _buildStorageUnitSelector() {
    final hasUsb = _units.any((u) => u.type == StorageType.usb);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: AppColors.surfaceElevated.withValues(alpha: 0.5),
      child: Row(
        children: [
          Text(
            'Origen de Recursos:',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _units.map((unit) {
                  final isSelected = _activeUnit?.id == unit.id;
                  final isUsb = unit.type == StorageType.usb;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () => _changeStorageUnit(unit),
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isUsb
                                  ? AppColors.accentGreen.withValues(alpha: 0.2)
                                  : AppColors.primary.withValues(alpha: 0.2))
                              : AppColors.surfaceLight.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? (isUsb ? AppColors.accentGreen : AppColors.primary)
                                : AppColors.borderSubtle,
                            width: isSelected ? 1.4 : 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isUsb ? Icons.usb_rounded : Icons.phone_android_rounded,
                              size: 14,
                              color: isSelected
                                  ? (isUsb ? AppColors.accentGreen : AppColors.primary)
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              unit.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected
                                  ? (isUsb ? AppColors.accentGreen : AppColors.primary)
                                  : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          if (hasUsb)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.accentGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.accentGreen.withValues(alpha: 0.4)),
              ),
              child: const Text(
                'USB CONECTADO',
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accentGreen,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGradesList() {
    return Container(
      color: AppColors.surfaceElevated.withValues(alpha: 0.2),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        itemCount: _grades.length,
        separatorBuilder: (_, _) => const SizedBox(height: 4),
        itemBuilder: (context, index) {
          final grade = _grades[index];
          final isSelected = _activeGrade?.id == grade.id;

          return InkWell(
            onTap: () {
              setState(() {
                _activeGrade = grade;
                _activeTopic = grade.topics.isNotEmpty ? grade.topics.first : null;
              });
            },
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.18)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.school_rounded,
                    size: 16,
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      grade.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${grade.topics.length} temas',
                      style: const TextStyle(fontSize: 8.5, color: AppColors.textMuted),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopicsList() {
    final topics = _activeGrade?.topics ?? [];

    if (topics.isEmpty) {
      return const Center(
        child: Text(
          'No se encontraron temas en este año escolar.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Temas de ${_activeGrade?.name}:',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Toca para cargar en carruseles',
                style: TextStyle(fontSize: 9.5, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            itemCount: topics.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final topic = topics[index];
              final isSelected = _activeTopic?.id == topic.id;

              return InkWell(
                onTap: () {
                  setState(() {
                    _activeTopic = topic;
                  });
                  // Notificar y cerrar
                  if (_activeUnit != null && _activeGrade != null) {
                    widget.onTopicSelected(_activeUnit!, _activeGrade!, topic);
                    Navigator.of(context).pop();
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : AppColors.surfaceLight.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.borderSubtle,
                      width: isSelected ? 1.4 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.topic_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              topic.name,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${topic.leftPanelResources.length} Documentos / Slides • ${topic.rightPanelResources.length} Medios',
                              style: const TextStyle(
                                fontSize: 9.5,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 12,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Text(
        'No se encontraron carpetas curriculares.',
        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
      ),
    );
  }
}
