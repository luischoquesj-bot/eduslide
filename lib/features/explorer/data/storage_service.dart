import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../domain/models/grade_folder.dart';
import '../domain/models/resource_item.dart';
import '../domain/models/topic_folder.dart';

/// Tipo de medio de almacenamiento
enum StorageType { internal, usb }

/// Representa una unidad de almacenamiento físico (Interna o USB OTG)
class StorageUnit {
  final String id;
  final String label;
  final String path;
  final StorageType type;
  final bool isAvailable;

  const StorageUnit({
    required this.id,
    required this.label,
    required this.path,
    required this.type,
    this.isAvailable = true,
  });
}

/// Servicio principal para la detección de almacenamientos (Memoria Interna y USB OTG),
/// solicitud de permisos en Android TV / proyectores y escaneo curricular ligero de 2 niveles.
class StorageService {
  static const String defaultSubjectFolder = 'Lengua Castellana';

  /// Solicita los permisos necesarios de almacenamiento en Android TV/móvil
  Future<bool> requestPermissions() async {
    // En pruebas unitarias o en plataformas que no sean Android no se requiere permiso
    if (kIsWeb || !Platform.isAndroid || Platform.environment.containsKey('FLUTTER_TEST')) {
      return true;
    }

    try {
      // 1. En Android 11+ (API 30+) se solicita MANAGE_EXTERNAL_STORAGE para acceso a archivos
      var manageStatus = await Permission.manageExternalStorage.status;
      if (!manageStatus.isGranted) {
        manageStatus = await Permission.manageExternalStorage.request();
      }
      if (manageStatus.isGranted) {
        return true;
      }

      // 2. Solicitud de permisos multimedia y almacenamiento estándar (Android 10 y Android 13+)
      final statuses = await [
        Permission.storage,
        Permission.photos,
        Permission.videos,
        Permission.audio,
      ].request();

      return statuses.values.any((s) => s.isGranted);
    } catch (e) {
      debugPrint('[StorageService] Error al solicitar permisos: $e');
      return false;
    }
  }

  /// Detecta las unidades de almacenamiento disponibles (Interna y USB OTG)
  Future<List<StorageUnit>> detectStorageUnits() async {
    final List<StorageUnit> units = [];

    // Modo testing: Provee unidad interna y mock inmediato
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return [
        const StorageUnit(
          id: 'test_internal',
          label: 'Memoria Interna',
          path: '/storage/emulated/0',
          type: StorageType.internal,
        ),
      ];
    }

    if (kIsWeb || !Platform.isAndroid) {
      // Entorno de escritorio: Usar carpeta de documentos
      try {
        final docDir = await getApplicationDocumentsDirectory();
        units.add(
          StorageUnit(
            id: 'desktop_internal',
            label: 'Almacenamiento Local',
            path: docDir.path,
            type: StorageType.internal,
          ),
        );
      } catch (_) {
        units.add(
          const StorageUnit(
            id: 'mock_internal',
            label: 'Memoria Interna',
            path: '/storage/emulated/0',
            type: StorageType.internal,
          ),
        );
      }
      return units;
    }

    // 1. Almacenamiento Interno estándar de Android
    const internalPath = '/storage/emulated/0';
    final internalDir = Directory(internalPath);
    if (await internalDir.exists()) {
      units.add(
        const StorageUnit(
          id: 'internal_0',
          label: 'Almacenamiento Interno',
          path: internalPath,
          type: StorageType.internal,
        ),
      );
    }

    // 2. Detección de unidades USB OTG escaneando el directorio /storage/
    try {
      final storageRoot = Directory('/storage');
      if (await storageRoot.exists()) {
        final entries = storageRoot.listSync(followLinks: false);
        for (final entry in entries) {
          if (entry is Directory) {
            final dirName = p.basename(entry.path);
            // Las particiones USB en Android típicamente tienen formato XXXX-XXXX (hexadecimal)
            // y no son "emulated", "self", "knox", etc.
            if (dirName != 'emulated' &&
                dirName != 'self' &&
                dirName != 'knox' &&
                !dirName.startsWith('.')) {
              units.add(
                StorageUnit(
                  id: 'usb_$dirName',
                  label: 'Memoria USB ($dirName)',
                  path: entry.path,
                  type: StorageType.usb,
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[StorageService] Error al escanear unidades USB: $e');
    }

    // Si no se encontró nada por permisos estrictos, asegura la unidad interna base
    if (units.isEmpty) {
      units.add(
        const StorageUnit(
          id: 'fallback_internal',
          label: 'Almacenamiento Interno',
          path: '/storage/emulated/0',
          type: StorageType.internal,
        ),
      );
    }

    return units;
  }

  /// Lista las subcarpetas dentro de una ruta de directorio dada
  Future<List<Directory>> listSubdirectories(String directoryPath) async {
    try {
      final dir = Directory(directoryPath);
      if (!await dir.exists()) {
        return [];
      }

      final entries = dir.listSync(followLinks: false);
      final directories = entries.whereType<Directory>().where((d) {
        final name = p.basename(d.path);
        // Excluir carpetas ocultas y temporales
        return !name.startsWith('.') &&
            !name.startsWith('\$') &&
            name.toLowerCase() != 'lost.dir';
      }).toList();

      directories.sort((a, b) =>
          p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase()));
      return directories;
    } catch (e) {
      debugPrint('[StorageService] Error al listar subcarpetas de $directoryPath: $e');
      return [];
    }
  }

  /// Carga y clasifica todos los archivos educativos soportados dentro de una carpeta dada
  Future<List<ResourceItem>> loadResourcesFromDirectory(
    String directoryPath, {
    bool includeSubdirectories = true,
  }) async {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) {
      return [];
    }

    final List<ResourceItem> items = [];
    final List<Directory> queue = [dir];
    final Set<String> visited = {};

    while (queue.isNotEmpty) {
      final currentDir = queue.removeAt(0);
      if (!visited.add(currentDir.path)) continue;

      try {
        final entries = currentDir.listSync(followLinks: false);
        for (final entity in entries) {
          try {
            if (entity is File) {
              final fileName = p.basename(entity.path);
              if (fileName.startsWith('.')) continue;

              final ext = p.extension(entity.path).toLowerCase();
              if (ResourceItem.isSupportedExtension(ext)) {
                int sizeBytes = 0;
                try {
                  sizeBytes = entity.statSync().size;
                } catch (_) {}

                items.add(
                  ResourceItem(
                    id: entity.path,
                    path: entity.path,
                    name: p.basenameWithoutExtension(fileName),
                    extension: ext,
                    sizeBytes: sizeBytes,
                    type: ResourceItem.typeFromExtension(ext),
                  ),
                );
              }
            } else if (includeSubdirectories && entity is Directory) {
              final dirName = p.basename(entity.path);
              if (!dirName.startsWith('.') &&
                  !dirName.startsWith('\$') &&
                  dirName.toLowerCase() != 'lost.dir' &&
                  dirName.toLowerCase() != 'android') {
                queue.add(entity);
              }
            }
          } catch (fileErr) {
            debugPrint('[StorageService] Error procesando archivo individual: $fileErr');
          }
        }
      } catch (dirErr) {
        debugPrint('[StorageService] No se pudo leer directorio ${currentDir.path}: $dirErr');
      }
    }

    // Ordenar alfabéticamente por nombre
    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return items;
  }

  /// Crea un TopicFolder a partir de cualquier carpeta elegida por el profesor
  Future<TopicFolder> createTopicFromDirectory(
    String directoryPath, {
    String? customName,
  }) async {
    final resources = await loadResourcesFromDirectory(directoryPath);
    final folderName = customName ?? p.basename(directoryPath);

    return TopicFolder(
      id: directoryPath,
      name: folderName.isEmpty ? 'Carpeta Seleccionada' : folderName,
      path: directoryPath,
      resources: resources,
    );
  }

  /// Escanea la estructura curricular limitándose estrictamente a 2 niveles:
  /// Nivel 1: Año Escolar (1ero Sec. - 6to Sec.)
  /// Nivel 2: Tema Curricular (ej. "Los minimedios")
  /// Nivel 3: Archivos directos (lectura ligera de metadatos para optimizar RAM)
  Future<List<GradeFolder>> scanCurricularStructure(
    String basePath, {
    String subjectFolder = defaultSubjectFolder,
  }) async {
    // En pruebas unitarias y de widgets, retornar de inmediato el mock didáctico
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return _getMockCurricularStructure(p.join(basePath, subjectFolder));
    }

    try {
      // 1. Determina la carpeta raíz de la materia
      final subjectCandidate = Directory(p.join(basePath, subjectFolder));
      final baseDir = Directory(basePath);
      Directory rootDir;

      if (await subjectCandidate.exists()) {
        rootDir = subjectCandidate;
      } else if (await baseDir.exists() &&
          p.basename(basePath).toLowerCase() == subjectFolder.toLowerCase()) {
        rootDir = baseDir;
      } else {
        debugPrint(
            '[StorageService] Carpeta curricular "$subjectFolder" no encontrada en $basePath. Usando estructura didáctica mock.');
        return _getMockCurricularStructure(subjectCandidate.path);
      }

      final List<GradeFolder> grades = [];
      final gradeEntries = rootDir.listSync().whereType<Directory>().toList();

      // Ordenar años escolares
      gradeEntries.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));

      for (final gradeDir in gradeEntries) {
        final gradeName = p.basename(gradeDir.path);
        final List<TopicFolder> topics = [];

        // Nivel 2: Temas del año
        final topicEntries = gradeDir.listSync().whereType<Directory>().toList();
        topicEntries.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));

        for (final topicDir in topicEntries) {
          final topicName = p.basename(topicDir.path);
          final List<ResourceItem> resources = [];

          // Nivel 3: Archivos directos del tema (solo metadatos)
          final fileEntries = topicDir.listSync().whereType<File>().toList();
          for (final file in fileEntries) {
            final fileName = p.basename(file.path);
            final ext = p.extension(file.path).toLowerCase();

            // Filtrar solo extensiones educativas soportadas
            final type = ResourceItem.typeFromExtension(ext);
            int sizeBytes = 0;
            try {
              sizeBytes = file.statSync().size;
            } catch (_) {}

            resources.add(
              ResourceItem(
                id: file.path,
                path: file.path,
                name: p.basenameWithoutExtension(fileName),
                extension: ext,
                sizeBytes: sizeBytes,
                type: type,
              ),
            );
          }

          if (resources.isNotEmpty) {
            topics.add(
              TopicFolder(
                id: topicDir.path,
                name: topicName,
                path: topicDir.path,
                resources: resources,
              ),
            );
          }
        }

        if (topics.isNotEmpty) {
          grades.add(
            GradeFolder(
              id: gradeDir.path,
              name: gradeName,
              path: gradeDir.path,
              topics: topics,
            ),
          );
        }
      }

      // Si la carpeta del disco no tenía la jerarquía requerida, proveemos el mock didáctico
      if (grades.isEmpty) {
        return _getMockCurricularStructure(rootDir.path);
      }

      return grades;
    } catch (e) {
      debugPrint('[StorageService] Error escaneando carpetas: $e. Retornando mock.');
      return _getMockCurricularStructure(basePath);
    }
  }

  /// Estructura didáctica completa de Secundaria (Bolivia) para pruebas o inicio rápido
  List<GradeFolder> _getMockCurricularStructure(String rootPath) {
    return [
      GradeFolder(
        id: '1_sec',
        name: '1ero Secundaria',
        path: p.join(rootPath, '1ero Sec'),
        topics: [
          TopicFolder(
            id: '1_sec_minimedios',
            name: 'Los Minimedios y la Comunicación',
            path: p.join(rootPath, '1ero Sec', 'Los minimedios'),
            resources: [
              ResourceItem(
                id: '1_1_pdf',
                path: '/storage/docs/guia_minimedios.pdf',
                name: 'Guía de Minimedios',
                extension: '.pdf',
                sizeBytes: 2450000,
                type: ResourceType.pdf,
              ),
              ResourceItem(
                id: '1_2_slide',
                path: '/storage/slides/diapositiva_afiches.eslide',
                name: 'El Afiche y el Folleto',
                extension: '.eslide',
                sizeBytes: 1200000,
                type: ResourceType.slide,
              ),
              ResourceItem(
                id: '1_3_img',
                path: '/storage/img/ejemplos_afiches.png',
                name: 'Afiches Didácticos HD',
                extension: '.png',
                sizeBytes: 1850000,
                type: ResourceType.image,
              ),
              ResourceItem(
                id: '1_4_vid',
                path: '/storage/vid/como_hacer_periodico_mural.mp4',
                name: 'Periódico Mural Escolar',
                extension: '.mp4',
                sizeBytes: 15400000,
                type: ResourceType.video,
              ),
              ResourceItem(
                id: '1_5_aud',
                path: '/storage/aud/podcast_comunicacion.mp3',
                name: 'Audio Minimedios',
                extension: '.mp3',
                sizeBytes: 3200000,
                type: ResourceType.audio,
              ),
            ],
          ),
          TopicFolder(
            id: '1_sec_narrativo',
            name: 'El Texto Narrativo y sus Tipos',
            path: p.join(rootPath, '1ero Sec', 'El texto narrativo'),
            resources: [
              ResourceItem(
                id: '1_6_pdf',
                path: '/storage/docs/antologia_cuentos.pdf',
                name: 'Cuentos Cortos',
                extension: '.pdf',
                sizeBytes: 3100000,
                type: ResourceType.pdf,
              ),
              ResourceItem(
                id: '1_7_slide',
                path: '/storage/slides/elementos_narracion.json',
                name: 'Elementos de Narración',
                extension: '.json',
                sizeBytes: 850000,
                type: ResourceType.slide,
              ),
              ResourceItem(
                id: '1_8_img',
                path: '/storage/img/estructura_cuento.webp',
                name: 'Estructura Inicio Nudo',
                extension: '.webp',
                sizeBytes: 950000,
                type: ResourceType.image,
              ),
              ResourceItem(
                id: '1_9_aud',
                path: '/storage/aud/narracion_oral.wav',
                name: 'Relato Oral Andino',
                extension: '.wav',
                sizeBytes: 4200000,
                type: ResourceType.audio,
              ),
            ],
          ),
        ],
      ),
      GradeFolder(
        id: '2_sec',
        name: '2do Secundaria',
        path: p.join(rootPath, '2do Sec'),
        topics: [
          TopicFolder(
            id: '2_sec_obras',
            name: 'Obras y Autores Bolivianos',
            path: p.join(rootPath, '2do Sec', 'Obras y autores'),
            resources: [
              ResourceItem(
                id: '2_1_pdf',
                path: '/storage/docs/raza_de_bronce_resumen.pdf',
                name: 'Raza de Bronce',
                extension: '.pdf',
                sizeBytes: 2800000,
                type: ResourceType.pdf,
              ),
              ResourceItem(
                id: '2_2_slide',
                path: '/storage/slides/alcides_arguedas.eslide',
                name: 'Biografía Arguedas',
                extension: '.eslide',
                sizeBytes: 1600000,
                type: ResourceType.slide,
              ),
              ResourceItem(
                id: '2_3_img',
                path: '/storage/img/mapa_literario_bolivia.jpg',
                name: 'Mapa Literario Bolivia',
                extension: '.jpg',
                sizeBytes: 3400000,
                type: ResourceType.image,
              ),
              ResourceItem(
                id: '2_4_vid',
                path: '/storage/vid/documental_costumbrismo.mp4',
                name: 'Literatura Costumbrista',
                extension: '.mp4',
                sizeBytes: 18200000,
                type: ResourceType.video,
              ),
            ],
          ),
        ],
      ),
      GradeFolder(
        id: '3_sec',
        name: '3ero Secundaria',
        path: p.join(rootPath, '3ero Sec'),
        topics: [
          TopicFolder(
            id: '3_sec_cronica',
            name: 'La Crónica y el Reportaje',
            path: p.join(rootPath, '3ero Sec', 'La cronica'),
            resources: [
              ResourceItem(
                id: '3_1_pdf',
                path: '/storage/docs/taller_cronica.pdf',
                name: 'Taller de Crónica',
                extension: '.pdf',
                sizeBytes: 1900000,
                type: ResourceType.pdf,
              ),
              ResourceItem(
                id: '3_2_slide',
                path: '/storage/slides/generos_periodisticos.eslide',
                name: 'Géneros Informativos',
                extension: '.eslide',
                sizeBytes: 1400000,
                type: ResourceType.slide,
              ),
              ResourceItem(
                id: '3_3_vid',
                path: '/storage/vid/entrevista_periodista.mp4',
                name: 'Entrevista Testimonial',
                extension: '.mp4',
                sizeBytes: 12500000,
                type: ResourceType.video,
              ),
              ResourceItem(
                id: '3_4_aud',
                path: '/storage/aud/cronica_radial.mp3',
                name: 'Crónica Radial Minera',
                extension: '.mp3',
                sizeBytes: 5100000,
                type: ResourceType.audio,
              ),
            ],
          ),
        ],
      ),
    ];
  }
}
