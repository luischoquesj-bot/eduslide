import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../explorer/domain/models/resource_item.dart';
import 'marquee_text.dart';

/// Carrusel lateral izquierdo (10% de ancho nominal en Workspace)
/// Pegado a los bordes de la pantalla (1mm) aprovechando al máximo el espacio
/// para previsualización clara de Diapositivas Flutter (.eslide/.json) y documentos PDF.
class LeftMediaCarousel extends StatefulWidget {
  final List<ResourceItem>? resources;
  final ValueChanged<ResourceItem>? onResourceTap;
  final VoidCallback? onOpenTopicSelector;
  final bool isCollapsed;
  final VoidCallback? onToggleCollapse;

  const LeftMediaCarousel({
    super.key,
    this.resources,
    this.onResourceTap,
    this.onOpenTopicSelector,
    this.isCollapsed = false,
    this.onToggleCollapse,
  });

  @override
  State<LeftMediaCarousel> createState() => _LeftMediaCarouselState();
}

class _LeftMediaCarouselState extends State<LeftMediaCarousel> {
  // Lista de materiales de respaldo en caso de inicialización sin tema activo
  static const List<ResourceItem> _fallbackResources = [
    ResourceItem(
      id: 'slide_1',
      path: '/storage/slides/sistema_solar.eslide',
      name: 'Sistema Solar 3D',
      extension: '.eslide',
      sizeBytes: 1400000,
      type: ResourceType.slide,
    ),
    ResourceItem(
      id: 'pdf_1',
      path: '/storage/docs/guia_geometria.pdf',
      name: 'Guía Geometría',
      extension: '.pdf',
      sizeBytes: 2100000,
      type: ResourceType.pdf,
    ),
    ResourceItem(
      id: 'slide_2',
      path: '/storage/slides/ecuaciones.json',
      name: 'Ecuaciones Paso a Paso',
      extension: '.json',
      sizeBytes: 950000,
      type: ResourceType.slide,
    ),
    ResourceItem(
      id: 'pdf_2',
      path: '/storage/docs/diagnostico.pdf',
      name: 'Examen Diagnóstico',
      extension: '.pdf',
      sizeBytes: 1800000,
      type: ResourceType.pdf,
    ),
  ];

  String? _selectedId;

  List<ResourceItem> get _items =>
      widget.resources ?? _fallbackResources;

  @override
  Widget build(BuildContext context) {
    return Container(
      // Pegado al borde lateral izquierdo, superior e inferior (~1mm de separación mínima)
      margin: const EdgeInsets.only(left: 1.0, top: 1.0, bottom: 1.0, right: 1.5),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.95),
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
        border: Border.all(color: AppColors.borderSubtle, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(1, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Cabecera compacta para aprovechar al máximo el espacio vertical
          _buildCompactHeader(),

          const Divider(height: 1, color: AppColors.borderSubtle),

          // Lista vertical deslizable de previsualizaciones pegada a los bordes
          Expanded(
            child: _items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.picture_as_pdf_outlined,
                            size: 20,
                            color: AppColors.textMuted.withValues(alpha: 0.6),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Sin PDFs\nni Slides',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 8.5,
                              color: AppColors.textMuted,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2.5),
                    physics: const BouncingScrollPhysics(),
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 5),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final isSelected = _selectedId == item.id;
                      return _buildMediaTile(item, isSelected);
                    },
                  ),
          ),

          // Botón inferior compacto para abrir el explorador de temas y USB
          _buildCompactAddButton(),
        ],
      ),
    );
  }

  Widget _buildCompactHeader() {
    return InkWell(
      onTap: widget.onOpenTopicSelector,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.auto_stories_rounded,
              size: 13,
              color: AppColors.primary,
            ),
            const SizedBox(width: 4),
            const Expanded(
              child: Text(
                'Slides & PDF',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            if (widget.onOpenTopicSelector != null)
              const Icon(
                Icons.unfold_more_rounded,
                size: 12,
                color: AppColors.textMuted,
              ),
          ],
        ),
      ),
    );
  }

  /// Tarjeta de previsualización visual con bordes redondeados (R12)
  Widget _buildMediaTile(ResourceItem item, bool isSelected) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedId = item.id;
          });
          widget.onResourceTap?.call(item);
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(3.5),
          decoration: BoxDecoration(
            color: isSelected
                ? item.accentColor.withValues(alpha: 0.2)
                : AppColors.surfaceLight.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? item.accentColor : AppColors.borderSubtle,
              width: isSelected ? 1.4 : 0.8,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Miniatura de previsualización visual temática
              AspectRatio(
                aspectRatio: 16 / 10,
                child: _buildThumbnail(item),
              ),
              const SizedBox(height: 3),

              // Título con rotación continua (Marquee) para títulos largos
              MarqueeText(
                text: item.name,
                style: const TextStyle(
                  fontSize: 9.0,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                item.categoryLabel,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 7.5,
                  fontWeight: FontWeight.bold,
                  color: item.accentColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactAddButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: Tooltip(
        message: 'Cambiar Año, Tema o Memoria USB',
        child: InkWell(
          onTap: widget.onOpenTopicSelector,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.borderHighlight,
                width: 0.8,
              ),
            ),
            child: const Icon(
              Icons.folder_open_rounded,
              size: 14,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }

  /// Genera una miniatura rica y realista del recurso para certeza visual del maestro
  Widget _buildThumbnail(ResourceItem item) {
    final bool isPdf = item.type == ResourceType.pdf;

    return Container(
      decoration: BoxDecoration(
        color: isPdf ? const Color(0xFF2B1D24) : const Color(0xFF132238),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: item.accentColor.withValues(alpha: 0.4),
          width: 0.7,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Maqueta visual de miniatura de página o diapositiva
          Positioned(
            top: 4,
            left: 5,
            right: 5,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: isPdf ? Colors.white.withValues(alpha: 0.08) : AppColors.surfaceLight.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 2.5,
                        decoration: BoxDecoration(
                          color: item.accentColor,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Container(
                          height: 1.5,
                          color: Colors.white24,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Container(height: 1.5, width: 22, color: Colors.white12),
                  const SizedBox(height: 2),
                  Container(height: 1.5, width: 16, color: Colors.white12),
                ],
              ),
            ),
          ),

          // Ícono central representativo
          Icon(
            item.icon,
            size: 20,
            color: item.accentColor,
          ),

          // Badge en la esquina superior derecha
          Positioned(
            top: 2,
            right: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                isPdf ? 'PDF' : item.extension.toUpperCase().replaceAll('.', ''),
                style: TextStyle(
                  fontSize: 6.0,
                  fontWeight: FontWeight.bold,
                  color: item.accentColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
