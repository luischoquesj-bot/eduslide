import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Clasificación de tipos de recursos didácticos en EduSlide
enum ResourceType {
  pdf,
  slide,
  image,
  video,
  audio,
}

/// Representa un archivo individual encontrado en el almacenamiento local o USB.
class ResourceItem {
  final String id;
  final String path;
  final String name;
  final String extension;
  final int sizeBytes;
  final ResourceType type;

  const ResourceItem({
    required this.id,
    required this.path,
    required this.name,
    required this.extension,
    required this.sizeBytes,
    required this.type,
  });

  /// Determina el tipo de recurso a partir de su extensión de archivo
  static ResourceType typeFromExtension(String ext) {
    final cleanExt = ext.toLowerCase().replaceAll('.', '');
    switch (cleanExt) {
      case 'pdf':
        return ResourceType.pdf;
      case 'eslide':
      case 'json':
      case 'ppt':
      case 'pptx':
        return ResourceType.slide;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'webp':
      case 'gif':
        return ResourceType.image;
      case 'mp4':
      case 'mkv':
      case 'avi':
      case 'mov':
        return ResourceType.video;
      case 'mp3':
      case 'wav':
      case 'm4a':
      case 'ogg':
        return ResourceType.audio;
      default:
        return ResourceType.slide;
    }
  }

  /// Retorna si el archivo corresponde al panel izquierdo (Slides y PDFs)
  bool get isLeftPanelResource =>
      type == ResourceType.pdf || type == ResourceType.slide;

  /// Retorna si el archivo corresponde al panel derecho (Multimedia)
  bool get isRightPanelResource =>
      type == ResourceType.image ||
      type == ResourceType.video ||
      type == ResourceType.audio;

  /// Ícono representativo según el tipo de archivo
  IconData get icon {
    switch (type) {
      case ResourceType.pdf:
        return Icons.picture_as_pdf_rounded;
      case ResourceType.slide:
        return Icons.slideshow_rounded;
      case ResourceType.image:
        return Icons.image_rounded;
      case ResourceType.video:
        return Icons.smart_display_rounded;
      case ResourceType.audio:
        return Icons.graphic_eq_rounded;
    }
  }

  /// Color de acento visual según el tipo de archivo
  Color get accentColor {
    switch (type) {
      case ResourceType.pdf:
        return AppColors.accentRose;
      case ResourceType.slide:
        return AppColors.primary;
      case ResourceType.image:
        return AppColors.accentGreen;
      case ResourceType.video:
        return AppColors.secondary;
      case ResourceType.audio:
        return AppColors.accentAmber;
    }
  }

  /// Categoría en texto breve para la tarjeta
  String get categoryLabel {
    switch (type) {
      case ResourceType.pdf:
        return 'PDF Doc';
      case ResourceType.slide:
        return 'Slide Flutter';
      case ResourceType.image:
        return 'HD Imagen';
      case ResourceType.video:
        return 'Video HD';
      case ResourceType.audio:
        return 'Audio Clase';
    }
  }

  /// Formato legible del tamaño del archivo
  String get formattedSize {
    if (sizeBytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double size = sizeBytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }
}
