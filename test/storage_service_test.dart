import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:eduslide/features/explorer/data/storage_service.dart';
import 'package:eduslide/features/explorer/domain/models/grade_folder.dart';
import 'package:eduslide/features/explorer/domain/models/resource_item.dart';
import 'package:eduslide/features/explorer/domain/models/topic_folder.dart';

void main() {
  group('Modelos del Explorador de Recursos', () {
    test('ResourceItem clasifica correctamente extensiones y paneles', () {
      final pdfItem = ResourceItem(
        id: '1',
        path: '/storage/docs/tema1.pdf',
        name: 'Tema 1',
        extension: '.pdf',
        sizeBytes: 1048576,
        type: ResourceItem.typeFromExtension('.pdf'),
      );

      final slideItem = ResourceItem(
        id: '2',
        path: '/storage/slides/tema1.eslide',
        name: 'Slide 1',
        extension: '.eslide',
        sizeBytes: 2097152,
        type: ResourceItem.typeFromExtension('.eslide'),
      );

      final imgItem = ResourceItem(
        id: '3',
        path: '/storage/img/foto.png',
        name: 'Foto 1',
        extension: '.png',
        sizeBytes: 524288,
        type: ResourceItem.typeFromExtension('.png'),
      );

      final vidItem = ResourceItem(
        id: '4',
        path: '/storage/vid/video.mp4',
        name: 'Video 1',
        extension: '.mp4',
        sizeBytes: 15728640,
        type: ResourceItem.typeFromExtension('.mp4'),
      );

      final audItem = ResourceItem(
        id: '5',
        path: '/storage/aud/audio.mp3',
        name: 'Audio 1',
        extension: '.mp3',
        sizeBytes: 3145728,
        type: ResourceItem.typeFromExtension('.mp3'),
      );

      final docxItem = ResourceItem(
        id: '6',
        path: '/storage/docs/plan.docx',
        name: 'Plan',
        extension: '.docx',
        sizeBytes: 1048576,
        type: ResourceItem.typeFromExtension('.docx'),
      );

      final xlsxItem = ResourceItem(
        id: '7',
        path: '/storage/docs/notas.xlsx',
        name: 'Notas',
        extension: '.xlsx',
        sizeBytes: 1048576,
        type: ResourceItem.typeFromExtension('.xlsx'),
      );

      final pptxItem = ResourceItem(
        id: '8',
        path: '/storage/docs/tema.pptx',
        name: 'Tema',
        extension: '.pptx',
        sizeBytes: 1048576,
        type: ResourceItem.typeFromExtension('.pptx'),
      );

      // Verificación de tipos
      expect(pdfItem.type, ResourceType.pdf);
      expect(slideItem.type, ResourceType.slide);
      expect(imgItem.type, ResourceType.image);
      expect(vidItem.type, ResourceType.video);
      expect(audItem.type, ResourceType.audio);
      expect(docxItem.type, ResourceType.docx);
      expect(xlsxItem.type, ResourceType.xlsx);
      expect(pptxItem.type, ResourceType.pptx);

      // Verificación de badges y ofimática
      expect(docxItem.badgeLabel, 'DOCX');
      expect(xlsxItem.badgeLabel, 'XLSX');
      expect(pptxItem.badgeLabel, 'PPTX');
      expect(docxItem.isOfficeDocument, isTrue);
      expect(xlsxItem.isOfficeDocument, isTrue);
      expect(pptxItem.isOfficeDocument, isTrue);

      // Verificación de asignación a paneles laterales
      expect(pdfItem.isLeftPanelResource, isTrue);
      expect(slideItem.isLeftPanelResource, isTrue);
      expect(docxItem.isLeftPanelResource, isTrue);
      expect(xlsxItem.isLeftPanelResource, isTrue);
      expect(pptxItem.isLeftPanelResource, isTrue);
      expect(imgItem.isLeftPanelResource, isFalse);

      expect(imgItem.isRightPanelResource, isTrue);
      expect(vidItem.isRightPanelResource, isTrue);
      expect(audItem.isRightPanelResource, isTrue);
      expect(pdfItem.isRightPanelResource, isFalse);
      expect(docxItem.isRightPanelResource, isFalse);

      // Formato legible de tamaño
      expect(pdfItem.formattedSize, '1.0 MB');
      expect(slideItem.formattedSize, '2.0 MB');
      expect(imgItem.formattedSize, '512.0 KB');
    });

    test('TopicFolder divide reactivamente los recursos para cada carrusel lateral', () {
      final topic = TopicFolder(
        id: 'topic_minimedios',
        name: 'Los Minimedios',
        path: '/storage/1ero Sec/Los minimedios',
        resources: [
          const ResourceItem(
            id: 'doc1',
            path: '/path/doc.pdf',
            name: 'Guía',
            extension: '.pdf',
            sizeBytes: 1000,
            type: ResourceType.pdf,
          ),
          const ResourceItem(
            id: 'slide1',
            path: '/path/slide.json',
            name: 'Diapositiva',
            extension: '.json',
            sizeBytes: 2000,
            type: ResourceType.slide,
          ),
          const ResourceItem(
            id: 'img1',
            path: '/path/img.jpg',
            name: 'Afiche',
            extension: '.jpg',
            sizeBytes: 3000,
            type: ResourceType.image,
          ),
          const ResourceItem(
            id: 'vid1',
            path: '/path/vid.mp4',
            name: 'Explicación',
            extension: '.mp4',
            sizeBytes: 4000,
            type: ResourceType.video,
          ),
        ],
      );

      expect(topic.leftPanelResources.length, 2);
      expect(topic.leftPanelResources.map((r) => r.type), containsAll([ResourceType.pdf, ResourceType.slide]));

      expect(topic.rightPanelResources.length, 2);
      expect(topic.rightPanelResources.map((r) => r.type), containsAll([ResourceType.image, ResourceType.video]));
    });

    test('GradeFolder aloja la jerarquía de temas curriculares', () {
      final grade = GradeFolder(
        id: '1_sec',
        name: '1ero Secundaria',
        path: '/storage/1ero Sec',
        topics: [
          const TopicFolder(
            id: 't1',
            name: 'Los Minimedios',
            path: '/storage/1ero Sec/Los minimedios',
            resources: [],
          ),
        ],
      );

      expect(grade.name, '1ero Secundaria');
      expect(grade.topics.length, 1);
      expect(grade.topics.first.name, 'Los Minimedios');
    });
  });

  group('StorageService', () {
    final storageService = StorageService();

    test('Solicita permisos sin fallas en entorno de ejecución', () async {
      final granted = await storageService.requestPermissions();
      expect(granted, isTrue);
    });

    test('Detecta unidades de almacenamiento disponibles', () async {
      final units = await storageService.detectStorageUnits();
      expect(units, isNotEmpty);
      expect(units.first.type, StorageType.internal);
    });

    test('Escanea estructura curricular ligera respetando los 2 niveles', () async {
      final units = await storageService.detectStorageUnits();
      final grades = await storageService.scanCurricularStructure(units.first.path);

      expect(grades, isNotEmpty);
      final firstGrade = grades.first;
      expect(firstGrade.topics, isNotEmpty);

      final firstTopic = firstGrade.topics.first;
      expect(firstTopic.resources, isNotEmpty);
      expect(firstTopic.leftPanelResources, isNotEmpty);
      expect(firstTopic.rightPanelResources, isNotEmpty);
    });

    test('listSubdirectories y loadResourcesFromDirectory exploran y clasifican archivos reales de una carpeta', () async {
      // Crear carpeta de prueba temporal
      final tempDir = Directory.systemTemp.createTempSync('eduslide_test_folder_');
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      // Crear subcarpetas
      final subDirA = Directory('${tempDir.path}/Unidad 1')..createSync();
      final subDirB = Directory('${tempDir.path}/Unidad 2')..createSync();

      // Crear archivos educativos simulados
      File('${subDirA.path}/guia_didactica.pdf').writeAsStringSync('dummy pdf content');
      File('${subDirA.path}/presentacion.eslide').writeAsStringSync('dummy slide content');
      File('${subDirB.path}/mapa.png').writeAsStringSync('dummy image content');
      File('${subDirB.path}/explicacion.mp4').writeAsStringSync('dummy video content');

      // 1. Probar listSubdirectories
      final subdirs = await storageService.listSubdirectories(tempDir.path);
      expect(subdirs.length, 2);

      // 2. Probar loadResourcesFromDirectory recursivo
      final allResources = await storageService.loadResourcesFromDirectory(
        tempDir.path,
        includeSubdirectories: true,
      );
      expect(allResources.length, 4);

      // 3. Probar createTopicFromDirectory
      final topic = await storageService.createTopicFromDirectory(tempDir.path, customName: 'Mi Carpeta de Aula');
      expect(topic.name, 'Mi Carpeta de Aula');
      expect(topic.leftPanelResources.length, 2); // pdf y eslide
      expect(topic.rightPanelResources.length, 2); // png y mp4
    });
  });
}
