import 'resource_item.dart';

/// Representa un tema curricular (segundo nivel de carpetas)
/// Ejemplo: "Los minimedios", "Obras y autores bolivianos", "El Teatro y la Poesía"
class TopicFolder {
  final String id;
  final String name;
  final String path;
  final List<ResourceItem> resources;

  const TopicFolder({
    required this.id,
    required this.name,
    required this.path,
    required this.resources,
  });

  /// Lista de documentos didácticos para el carrusel izquierdo (.pdf, .eslide, .json)
  List<ResourceItem> get leftPanelResources =>
      resources.where((r) => r.isLeftPanelResource).toList();

  /// Lista de archivos multimedia para el carrusel derecho (imágenes, videos, audios)
  List<ResourceItem> get rightPanelResources =>
      resources.where((r) => r.isRightPanelResource).toList();
}
