import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:eduslide/features/media_viewers/services/document_converter_service.dart';

class FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final Directory tempDir = Directory.systemTemp.createTempSync('eduslide_test_');

  @override
  Future<String?> getTemporaryPath() async {
    return tempDir.path;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakePathProviderPlatform fakePathProvider;

  setUp(() {
    fakePathProvider = FakePathProviderPlatform();
    PathProviderPlatform.instance = fakePathProvider;
  });

  tearDown(() {
    if (fakePathProvider.tempDir.existsSync()) {
      fakePathProvider.tempDir.deleteSync(recursive: true);
    }
  });

  group('DocumentConverterService', () {
    test('Convierte DOCX a PDF y gestiona la caché temporal de solo lectura', () async {
      final service = DocumentConverterService();

      // Crear archivo DOCX simulado (ZIP con word/document.xml)
      final archive = Archive();
      const documentXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p>
      <w:pPr><w:jc w:val="center"/></w:pPr>
      <w:r><w:rPr><w:b/></w:rPr><w:t>PLAN ANUAL DE CLASE</w:t></w:r>
    </w:p>
    <w:p>
      <w:r><w:t>Profesor: Luis Choque - EduProjects BO</w:t></w:r>
    </w:p>
    <w:tbl>
      <w:tr>
        <w:tc><w:p><w:r><w:t>Trimestre</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>Contenido</w:t></w:r></w:p></w:tc>
      </w:tr>
      <w:tr>
        <w:tc><w:p><w:r><w:t>1er Trimestre</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>Introducción a la tecnología educativa</w:t></w:r></w:p></w:tc>
      </w:tr>
    </w:tbl>
  </w:body>
</w:document>''';

      archive.addFile(ArchiveFile('word/document.xml', documentXml.length, utf8.encode(documentXml)));
      final zipBytes = ZipEncoder().encode(archive);

      final testDocxFile = File('${fakePathProvider.tempDir.path}/test_unit.docx');
      await testDocxFile.writeAsBytes(zipBytes);

      // Primera conversión (generación inicial)
      final pdfPath = await service.getOrConvertDocumentToPdf(testDocxFile.path);
      expect(pdfPath, isNotEmpty);
      final pdfFile = File(pdfPath);
      expect(pdfFile.existsSync(), isTrue);
      expect(pdfFile.lengthSync(), greaterThan(100));

      // Verificación de integridad: El archivo DOCX original no ha sido modificado
      expect(testDocxFile.existsSync(), isTrue);
      expect(testDocxFile.lengthSync(), zipBytes.length);

      // Segunda llamada (Cache Hit en 0 ms)
      final cachedPdfPath = await service.getOrConvertDocumentToPdf(testDocxFile.path);
      expect(cachedPdfPath, equals(pdfPath));
    });

    test('Convierte XLSX a PDF tabular correctamente', () async {
      final service = DocumentConverterService();

      final archive = Archive();
      const sharedStringsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <si><t>Estudiante</t></si>
  <si><t>Calificación</t></si>
  <si><t>Juan Perez</t></si>
</sst>''';

      const sheetXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <sheetData>
    <row r="1">
      <c r="A1" t="s"><v>0</v></c>
      <c r="B1" t="s"><v>1</v></c>
    </row>
    <row r="2">
      <c r="A2" t="s"><v>2</v></c>
      <c r="B2"><v>100</v></c>
    </row>
  </sheetData>
</worksheet>''';

      archive.addFile(ArchiveFile('xl/sharedStrings.xml', sharedStringsXml.length, utf8.encode(sharedStringsXml)));
      archive.addFile(ArchiveFile('xl/worksheets/sheet1.xml', sheetXml.length, utf8.encode(sheetXml)));
      final zipBytes = ZipEncoder().encode(archive);

      final testXlsxFile = File('${fakePathProvider.tempDir.path}/test_grid.xlsx');
      await testXlsxFile.writeAsBytes(zipBytes);

      final pdfPath = await service.getOrConvertDocumentToPdf(testXlsxFile.path);
      expect(pdfPath, isNotEmpty);
      expect(File(pdfPath).existsSync(), isTrue);
    });

    test('Convierte PPTX a diapositivas PDF apaisadas', () async {
      final service = DocumentConverterService();

      final archive = Archive();
      const slide1Xml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld>
    <p:spTree>
      <p:sp>
        <p:txBody>
          <a:p><a:r><a:t>Introducción a la Robótica</a:t></a:r></a:p>
        </p:txBody>
      </p:sp>
      <p:sp>
        <p:txBody>
          <a:p><a:r><a:t>Definición de sensores y actuadores</a:t></a:r></a:p>
          <a:p><a:r><a:t>Programación por bloques</a:t></a:r></a:p>
        </p:txBody>
      </p:sp>
    </p:spTree>
  </p:cSld>
</p:sld>''';

      archive.addFile(ArchiveFile('ppt/slides/slide1.xml', slide1Xml.length, utf8.encode(slide1Xml)));
      final zipBytes = ZipEncoder().encode(archive);

      final testPptxFile = File('${fakePathProvider.tempDir.path}/test_slide.pptx');
      await testPptxFile.writeAsBytes(zipBytes);

      final pdfPath = await service.getOrConvertDocumentToPdf(testPptxFile.path);
      expect(pdfPath, isNotEmpty);
      expect(File(pdfPath).existsSync(), isTrue);
    });
  });
}
