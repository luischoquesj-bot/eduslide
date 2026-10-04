import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Clasificación de tipos de recursos didácticos en EduSlide
enum ResourceType {
  pdf,
  docx,
  xlsx,
  pptx,
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

  /// Retorna si la extensión de archivo corresponde a un recurso educativo soportado
  static bool isSupportedExtension(String ext) {
    final clean = ext.toLowerCase().replaceAll('.', '').trim();
    return const {
      'pdf',
      'eslide',
      'eduslide',
      'json',
      'doc',
      'docx',
      // 'xls',
      // 'xlsx',
      // 'ppt',
      // 'pptx',
      // 'odp',
      'txt',
      'epub',
      'jpg',
      'jpeg',
      'png',
      'webp',
      'gif',
      'bmp',
      'svg',
      'heic',
      'heif',
      'mp4',
      'mkv',
      'avi',
      'mov',
      '3gp',
      'wmv',
      'webm',
      'flv',
      'm4v',
      'mp3',
      'wav',
      'm4a',
      'ogg',
      'flac',
      'aac',
      'wma',
      'opus',
      'amr',
    }.contains(clean);
  }

  /// Determina el tipo de recurso a partir de su extensión de archivo
  static ResourceType typeFromExtension(String ext) {
    final cleanExt = ext.toLowerCase().replaceAll('.', '').trim();
    switch (cleanExt) {
      case 'pdf':
        return ResourceType.pdf;
      case 'doc':
      case 'docx':
        return ResourceType.docx;
      case 'xls':
      case 'xlsx':
        return ResourceType.xlsx;
      case 'ppt':
      case 'pptx':
      case 'odp':
        return ResourceType.pptx;
      case 'eslide':
      case 'eduslide':
      case 'json':
      case 'txt':
      case 'epub':
        return ResourceType.slide;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'webp':
      case 'gif':
      case 'bmp':
      case 'svg':
      case 'heic':
      case 'heif':
        return ResourceType.image;
      case 'mp4':
      case 'mkv':
      case 'avi':
      case 'mov':
      case '3gp':
      case 'wmv':
      case 'webm':
      case 'flv':
      case 'm4v':
        return ResourceType.video;
      case 'mp3':
      case 'wav':
      case 'm4a':
      case 'ogg':
      case 'flac':
      case 'aac':
      case 'wma':
      case 'opus':
      case 'amr':
        return ResourceType.audio;
      default:
        return ResourceType.slide;
    }
  }

  /// Retorna si el archivo es un documento ofimático convertible a PDF
  bool get isOfficeDocument =>
      type == ResourceType.docx ||
      type == ResourceType.xlsx ||
      type == ResourceType.pptx;

  /// Retorna si el archivo corresponde al panel izquierdo (Slides, PDFs y Documentos Ofimáticos)
  bool get isLeftPanelResource =>
      type == ResourceType.pdf ||
      type == ResourceType.docx ||
      type == ResourceType.xlsx ||
      type == ResourceType.pptx ||
      type == ResourceType.slide;

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
      case ResourceType.docx:
        return Icons.article_rounded;
      case ResourceType.xlsx:
        return Icons.table_chart_rounded;
      case ResourceType.pptx:
        return Icons.co_present_rounded;
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

  /// Color corporativo de acento visual según el formato del archivo
  Color get accentColor {
    switch (type) {
      case ResourceType.pdf:
        return const Color(0xFFD32F2F); // Rojo institucional PDF
      case ResourceType.docx:
        return const Color(0xFF185ABD); // Azul Word oficial
      case ResourceType.xlsx:
        return const Color(0xFF107C41); // Verde Excel oficial
      case ResourceType.pptx:
        return const Color(0xFFD24726); // Naranja PowerPoint oficial
      case ResourceType.slide:
        return const Color(0xFF00897B); // Verde azulado EduSlide
      case ResourceType.image:
        return AppColors.accentGreen;
      case ResourceType.video:
        return AppColors.secondary;
      case ResourceType.audio:
        return AppColors.accentAmber;
    }
  }

  /// Etiqueta corta institucional (Badge) para el carrusel y visor
  String get badgeLabel {
    switch (type) {
      case ResourceType.pdf:
        return 'PDF';
      case ResourceType.docx:
        return 'DOCX';
      case ResourceType.xlsx:
        return 'XLSX';
      case ResourceType.pptx:
        return 'PPTX';
      case ResourceType.slide:
        return 'SLIDE';
      case ResourceType.image:
        return 'IMG';
      case ResourceType.video:
        return 'VIDEO';
      case ResourceType.audio:
        return 'AUDIO';
    }
  }

  /// Categoría en texto breve para la tarjeta
  String get categoryLabel {
    switch (type) {
      case ResourceType.pdf:
        return 'Documento PDF';
      case ResourceType.docx:
        return 'Documento Word';
      case ResourceType.xlsx:
        return 'Hoja de Cálculo Excel';
      case ResourceType.pptx:
        return 'Presentación PPTX';
      case ResourceType.slide:
        return 'Diapositiva EduSlide';
      case ResourceType.image:
        return 'Imagen HD';
      case ResourceType.video:
        return 'Video Didáctico';
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
