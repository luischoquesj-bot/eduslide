import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../data/storage_service.dart';
import '../../domain/models/resource_item.dart';
import '../../domain/models/topic_folder.dart';

/// Diálogo interactivo táctil para navegar y seleccionar cualquier carpeta
/// de la Memoria Interna o Memoria USB / OTG en proyectores y tablets.
class FolderPickerDialog extends StatefulWidget {
  final StorageService storageService;
  final StorageUnit? initialUnit;
  final String? initialPath;
  final void Function(StorageUnit unit, TopicFolder folder) onFolderSelected;

  const FolderPickerDialog({
    super.key,
    required this.storageService,
    this.initialUnit,
    this.initialPath,
    required this.onFolderSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required StorageService storageService,
    StorageUnit? initialUnit,
    String? initialPath,
    required void Function(StorageUnit unit, TopicFolder folder) onFolderSelected,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => FolderPickerDialog(
        storageService: storageService,
        initialUnit: initialUnit,
        initialPath: initialPath,
        onFolderSelected: onFolderSelected,
      ),
    );
  }

  @override
  State<FolderPickerDialog> createState() => _FolderPickerDialogState();
}

class _FolderPickerDialogState extends State<FolderPickerDialog> {
  List<StorageUnit> _units = [];
  StorageUnit? _currentUnit;
  String _currentPath = '';
  List<Directory> _subdirectories = [];
  List<ResourceItem> _currentFolderResources = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() => _isLoading = true);
    await widget.storageService.requestPermissions();
    final units = await widget.storageService.detectStorageUnits();

    StorageUnit unit = widget.initialUnit ?? units.first;
    // Si no se pasó unidad y hay USB, dejamos que el usuario vea ambas
    final usbUnit = units.where((u) => u.type == StorageType.usb).firstOrNull;
    if (widget.initialUnit == null && usbUnit != null) {
      unit = usbUnit;
    }

    final startPath = widget.initialPath ?? unit.path;

    if (mounted) {
      setState(() {
        _units = units;
        _currentUnit = unit;
        _currentPath = startPath;
      });
      await _loadDirectoryContents(startPath);
    }
  }

  Future<void> _loadDirectoryContents(String path) async {
    setState(() => _isLoading = true);

    final dirs = await widget.storageService.listSubdirectories(path);
    // Cargamos los recursos de la carpeta actual y subcarpetas para visualización completa
    final resources = await widget.storageService.loadResourcesFromDirectory(
      path,
      includeSubdirectories: true,
    );

    if (mounted) {
      setState(() {
        _currentPath = path;
        _subdirectories = dirs;
        _currentFolderResources = resources;
        _isLoading = false;
      });
    }
  }

  void _switchUnit(StorageUnit unit) {
    if (_currentUnit?.id == unit.id) return;
    setState(() {
      _currentUnit = unit;
      _currentPath = unit.path;
    });
    _loadDirectoryContents(unit.path);
  }

  void _navigateToSubdirectory(Directory dir) {
    _loadDirectoryContents(dir.path);
  }

  void _navigateUp() {
    if (_currentUnit == null) return;
    final parent = p.dirname(_currentPath);
    // No subir más allá de la raíz de la unidad seleccionada
    if (_currentPath != _currentUnit!.path && parent.startsWith(_currentUnit!.path)) {
      _loadDirectoryContents(parent);
    } else if (_currentPath != _currentUnit!.path) {
      _loadDirectoryContents(_currentUnit!.path);
    }
  }

  bool get _canNavigateUp {
    if (_currentUnit == null) return false;
    return _currentPath != _currentUnit!.path && _currentPath.length > _currentUnit!.path.length;
  }

  Future<void> _confirmSelection() async {
    if (_currentUnit == null) return;

    setState(() => _isLoading = true);

    // Escanear recursivamente los recursos para que si tiene subcarpetas también se aprovechen
    final allResources = await widget.storageService.loadResourcesFromDirectory(
      _currentPath,
      includeSubdirectories: true,
    );

    final folderName = p.basename(_currentPath);
    final topic = TopicFolder(
      id: _currentPath,
      name: folderName.isEmpty ? _currentUnit!.label : folderName,
      path: _currentPath,
      resources: allResources,
    );

    if (mounted) {
      widget.onFolderSelected(_currentUnit!, topic);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final dialogWidth = (media.size.width * 0.82).clamp(480.0, 840.0);
    final dialogHeight = (media.size.height * 0.86).clamp(340.0, 560.0);

    final leftCount = _currentFolderResources.where((r) => r.isLeftPanelResource).length;
    final rightCount = _currentFolderResources.where((r) => r.isRightPanelResource).length;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderHighlight, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 32,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // 1. Cabecera con selector de unidad de almacenamiento (Interna vs USB)
            _buildHeader(),

            const Divider(color: AppColors.borderSubtle, height: 1),

            // 2. Barra de ruta actual y botón de subir nivel
            _buildPathBar(),

            const Divider(color: AppColors.borderSubtle, height: 1),

            // 3. Contenido: Lista de subcarpetas y archivos detectados
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    )
                  : _buildFolderContent(),
            ),

            const Divider(color: AppColors.borderSubtle, height: 1),

            // 4. Barra inferior de confirmación
            _buildBottomBar(leftCount, rightCount),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.snippet_folder_rounded,
              color: AppColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Seleccionar Carpeta de Recursos',
            style: AppTextStyles.cardTitle,
          ),
          const Spacer(),

          // Selector de Unidades de Almacenamiento
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _units.map((unit) {
                final isSelected = _currentUnit?.id == unit.id;
                final isUsb = unit.type == StorageType.usb;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: InkWell(
                    onTap: () => _switchUnit(unit),
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isUsb
                                ? AppColors.accentGreen.withValues(alpha: 0.25)
                                : AppColors.primary.withValues(alpha: 0.25))
                            : AppColors.surfaceLight.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? (isUsb ? AppColors.accentGreen : AppColors.primary)
                              : AppColors.borderSubtle,
                          width: isSelected ? 1.4 : 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isUsb ? Icons.usb_rounded : Icons.phone_android_rounded,
                            size: 13,
                            color: isSelected
                                ? (isUsb ? AppColors.accentGreen : AppColors.primary)
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            unit.label,
                            style: TextStyle(
                              fontSize: 10.5,
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

          const SizedBox(width: 6),
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

  Widget _buildPathBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: AppColors.surfaceElevated.withValues(alpha: 0.4),
      child: Row(
        children: [
          // Botón Back / Subir nivel con borde prominente y espacio de interacción ergonómico
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _canNavigateUp ? _navigateUp : null,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _canNavigateUp
                      ? AppColors.primary.withValues(alpha: 0.16)
                      : AppColors.surfaceLight.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _canNavigateUp
                        ? AppColors.primary.withValues(alpha: 0.75)
                        : AppColors.borderSubtle,
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_back_rounded,
                      size: 15,
                      color: _canNavigateUp ? AppColors.primary : AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Atrás',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _canNavigateUp ? AppColors.primary : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.folder_open_rounded, size: 15, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _currentPath,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 10.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 16),
            tooltip: 'Recargar carpeta',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: () => _loadDirectoryContents(_currentPath),
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildFolderContent() {
    if (_subdirectories.isEmpty && _currentFolderResources.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.folder_off_rounded, size: 40, color: AppColors.textMuted),
              const SizedBox(height: 8),
              const Text(
                'No se detectaron archivos ni subcarpetas en este directorio.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Formatos: PDF, Diapositivas (.eslide, .json, .ppt), Imágenes (JPG, PNG), Videos (MP4) y Audios (MP3)',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.8), fontSize: 10),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Columna Izquierda: Subcarpetas navegables
        Expanded(
          flex: 55,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Text(
                  'Subcarpetas (${_subdirectories.length}):',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Expanded(
                child: _subdirectories.isEmpty
                    ? const Center(
                        child: Text(
                          'No hay más subcarpetas aquí.',
                          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        itemCount: _subdirectories.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 3),
                        itemBuilder: (context, index) {
                          final dir = _subdirectories[index];
                          final dirName = p.basename(dir.path);

                          return InkWell(
                            onTap: () => _navigateToSubdirectory(dir),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLight.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.borderSubtle.withValues(alpha: 0.6),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.folder_rounded,
                                    size: 16,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      dirName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    size: 15,
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
          ),
        ),

        const VerticalDivider(color: AppColors.borderSubtle, width: 1),

        // Columna Derecha: Recursos detectados directamente en la carpeta actual
        Expanded(
          flex: 45,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Text(
                  'Archivos Detectados (${_currentFolderResources.length}):',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Expanded(
                child: _currentFolderResources.isEmpty
                    ? const Center(
                        child: Text(
                          'No hay archivos sueltos en este nivel.\nPuedes explorar las subcarpetas a la izquierda.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        itemCount: _currentFolderResources.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 3),
                        itemBuilder: (context, index) {
                          final res = _currentFolderResources[index];
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: res.accentColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Icon(res.icon, size: 14, color: res.accentColor),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    res.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                Text(
                                  res.categoryLabel,
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.bold,
                                    color: res.accentColor,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(int leftCount, int rightCount) {
    final folderName = p.basename(_currentPath);
    final displayName = folderName.isEmpty ? (_currentUnit?.label ?? 'Carpeta') : folderName;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: AppColors.surfaceElevated.withValues(alpha: 0.6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Carpeta: $displayName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$leftCount Slides/PDFs • $rightCount Fotos/Videos/Audios (y subcarpetas)',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _confirmSelection,
            icon: const Icon(Icons.check_circle_rounded, size: 16),
            label: const Text('Cargar Recursos de esta Carpeta'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: const Color(0xFF0F172A),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
