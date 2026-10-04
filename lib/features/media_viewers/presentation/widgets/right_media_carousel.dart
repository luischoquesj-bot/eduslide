import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../explorer/domain/models/resource_item.dart';
import 'marquee_text.dart';

/// Carrusel lateral derecho (10% de ancho nominal en Workspace)
/// Pegado al borde lateral derecho de la pantalla (~1mm) aprovechando al máximo
/// el área visual para previsualizar Imágenes, Videos y Audios escolares del tema activo.
class RightMediaCarousel extends StatefulWidget {
  final List<ResourceItem>? resources;
  final ValueChanged<ResourceItem>? onResourceTap;
  final VoidCallback? onOpenTopicSelector;
  final bool isCollapsed;
  final VoidCallback? onToggleCollapse;

  const RightMediaCarousel({
    super.key,
    this.resources,
    this.onResourceTap,
    this.onOpenTopicSelector,
    this.isCollapsed = false,
    this.onToggleCollapse,
  });

  @override
  State<RightMediaCarousel> createState() => _RightMediaCarouselState();
}

class _RightMediaCarouselState extends State<RightMediaCarousel> {
  // Lista de recursos multimedia de respaldo
  static const List<ResourceItem> _fallbackResources = [
    ResourceItem(
      id: 'img_celula',
      path: '/storage/img/celula_humana.png',
      name: 'Célula Humana',
      extension: '.png',
      sizeBytes: 2500000,
      type: ResourceType.image,
    ),
    ResourceItem(
      id: 'vid_volcan',
      path: '/storage/vid/volcan.mp4',
      name: 'Erupción Volcán',
      extension: '.mp4',
      sizeBytes: 14200000,
      type: ResourceType.video,
    ),
    ResourceItem(
      id: 'aud_pronuncia',
      path: '/storage/aud/fonetica.mp3',
      name: 'Audio Fonético',
      extension: '.mp3',
      sizeBytes: 1200000,
      type: ResourceType.audio,
    ),
    ResourceItem(
      id: 'img_mapa',
      path: '/storage/img/mapa_bolivia.jpg',
      name: 'Mapa Bolivia',
      extension: '.jpg',
      sizeBytes: 3100000,
      type: ResourceType.image,
    ),
    ResourceItem(
      id: 'vid_gravedad',
      path: '/storage/vid/caida_libre.mp4',
      name: 'Física y Caída',
      extension: '.mp4',
      sizeBytes: 16800000,
      type: ResourceType.video,
    ),
  ];

  String? _selectedId;

  List<ResourceItem> get _items =>
      (widget.resources != null && widget.resources!.isNotEmpty)
          ? widget.resources!
          : _fallbackResources;

  @override
  Widget build(BuildContext context) {
    return Container(
      // Pegado al borde lateral derecho, superior e inferior (~1mm de separación mínima)
      margin: const EdgeInsets.only(right: 1.0, top: 1.0, bottom: 1.0, left: 1.5),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.95),
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
        border: Border.all(color: AppColors.borderSubtle, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(-1, 2),
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
            child: ListView.separated(
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
              Icons.perm_media_rounded,
              size: 13,
              color: AppColors.secondary,
            ),
            const SizedBox(width: 4),
            const Expanded(
              child: Text(
                'Galería & Medios',
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
              // Miniatura de previsualización tipo tarjeta visual multimedia
              AspectRatio(
                aspectRatio: 16 / 10,
                child: Container(
                  decoration: BoxDecoration(
                    color: item.accentColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: item.accentColor.withValues(alpha: 0.3),
                      width: 0.6,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Badge tipo minúsculo en la esquina superior
                      Positioned(
                        top: 2,
                        right: 3,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            item.type == ResourceType.video
                                ? 'VID'
                                : item.type == ResourceType.audio
                                    ? 'AUD'
                                    : 'IMG',
                            style: TextStyle(
                              fontSize: 6.5,
                              fontWeight: FontWeight.bold,
                              color: item.accentColor,
                            ),
                          ),
                        ),
                      ),
                      Icon(
                        item.icon,
                        size: 20,
                        color: item.accentColor,
                      ),
                    ],
                  ),
                ),
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
                item.formattedSize,
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
              Icons.perm_media_outlined,
              size: 14,
              color: AppColors.secondary,
            ),
          ),
        ),
      ),
    );
  }
}
