import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:xml/xml.dart';

/// Servicio de Conversión y Gestión de Caché para Documentos Ofimáticos en EduSlide.
/// Soporta Word (.docx, .doc), Excel (.xlsx, .xls) y PowerPoint (.pptx, .ppt).
///
/// REGLAS:
/// - Lectura estrictamente de solo lectura (Read-Only). Jamás modifica el archivo original.
/// - CERO etiquetas, marcas de agua o cabeceras artificiales inyectadas sobre el documento.
/// - Preservación fiel del orden de elementos: textos, tablas con columnas reales e imágenes en línea.
/// - Los PDFs generados residen exclusivamente en el directorio temporal (caché).
/// - Si el PDF ya está en caché y el archivo no cambió, la apertura es inmediata (0 ms).
class DocumentConverterService {
  static final DocumentConverterService _instance = DocumentConverterService._internal();
  factory DocumentConverterService() => _instance;
  DocumentConverterService._internal();

  /// Directorio de caché temporal para PDFs generados
  Future<Directory> _getCacheDirectory() async {
    final tempDir = await getTemporaryDirectory();
    final cacheDir = Directory(p.join(tempDir.path, 'eduslide_docs_cache'));
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// Genera una clave de caché determinista basada en la ruta, tamaño y fecha de modificación
  String _generateCacheKey(File file) {
    try {
      final stat = file.statSync();
      final rawKey = '${file.path}_${stat.size}_${stat.modified.millisecondsSinceEpoch}';
      var hash = 0;
      for (var i = 0; i < rawKey.length; i++) {
        hash = (31 * hash + rawKey.codeUnitAt(i)) & 0x7FFFFFFF;
      }
      final safeName = p.basenameWithoutExtension(file.path).replaceAll(RegExp(r'[^\w\-]'), '_');
      return '${safeName}_$hash.pdf';
    } catch (_) {
      final safeName = p.basenameWithoutExtension(file.path).replaceAll(RegExp(r'[^\w\-]'), '_');
      return '${safeName}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    }
  }

  /// Retorna la ruta al PDF en caché si ya existe, de lo contrario convierte el documento fielmente y lo guarda.
  Future<String> getOrConvertDocumentToPdf(String filePath) async {
    final sourceFile = File(filePath);
    if (!await sourceFile.exists()) {
      throw Exception('El archivo original no existe en la ruta: $filePath');
    }

    final cacheDir = await _getCacheDirectory();
    final cacheKey = _generateCacheKey(sourceFile);
    final cachedPdfFile = File(p.join(cacheDir.path, cacheKey));

    // Si ya existe en caché con tamaño válido, devolver inmediatamente (0 ms)
    if (await cachedPdfFile.exists() && (await cachedPdfFile.length()) > 0) {
      debugPrint('[DocumentConverter] Cache hit: ${cachedPdfFile.path}');
      return cachedPdfFile.path;
    }

    debugPrint('[DocumentConverter] Convirtiendo archivo a PDF limpio: $filePath');
    final ext = p.extension(filePath).toLowerCase();

    // Lectura de bytes en modo sólo lectura (Read-Only)
    final bytes = await sourceFile.readAsBytes();
    final pdf = pw.Document();

    final fileName = p.basename(filePath);

    if (ext == '.docx') {
      _convertDocxToPdf(pdf, bytes);
    } else if (ext == '.xlsx') {
      _convertXlsxToPdf(pdf, bytes);
    } else if (ext == '.pptx') {
      _convertPptxToPdf(pdf, bytes);
    } else if (ext == '.doc' || ext == '.xls' || ext == '.ppt') {
      _convertLegacyOfficeToPdf(pdf, bytes);
    } else {
      _convertGenericTextToPdf(pdf, bytes, fileName);
    }

    final pdfBytes = await pdf.save();
    await cachedPdfFile.writeAsBytes(pdfBytes, flush: true);
    debugPrint('[DocumentConverter] PDF limpio guardado en caché: ${cachedPdfFile.path}');

    return cachedPdfFile.path;
  }

  // ===========================================================================
  // 1. CONVERSIÓN DE WORD (.DOCX) A PDF CON ALTA FIDELIDAD Y LIMPIO
  // ===========================================================================
  void _convertDocxToPdf(pw.Document pdf, List<int> bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final documentXmlFile = archive.findFile('word/document.xml');

      if (documentXmlFile == null) {
        _convertGenericTextToPdf(pdf, bytes, 'Documento');
        return;
      }

      final xmlContent = utf8.decode(documentXmlFile.content as List<int>, allowMalformed: true);
      final documentXml = XmlDocument.parse(xmlContent);

      // 1. Mapear relaciones de imágenes desde word/_rels/document.xml.rels
      final relsFile = archive.findFile('word/_rels/document.xml.rels');
      final imageRelMap = <String, String>{}; // rId -> path dentro del zip

      if (relsFile != null) {
        try {
          final relsXml = utf8.decode(relsFile.content as List<int>, allowMalformed: true);
          final relsDoc = XmlDocument.parse(relsXml);
          for (final rel in relsDoc.findAllElements('Relationship')) {
            final id = rel.getAttribute('Id');
            final target = rel.getAttribute('Target');
            final type = rel.getAttribute('Type') ?? '';
            if (id != null && target != null && type.contains('image')) {
              var targetPath = target;
              if (!targetPath.startsWith('word/')) {
                targetPath = 'word/$targetPath';
              }
              imageRelMap[id] = targetPath;
            }
          }
        } catch (e) {
          debugPrint('[DocumentConverter] Error leyendo rels: $e');
        }
      }

      // 2. Extraer bytes de imágenes del ZIP
      final imagesData = <String, Uint8List>{};
      for (final file in archive.files) {
        if (file.isFile && file.name.startsWith('word/media/')) {
          imagesData[file.name] = Uint8List.fromList(file.content as List<int>);
        }
      }

      final body = documentXml.findAllElements('w:body').firstOrNull;
      if (body == null) {
        _convertGenericTextToPdf(pdf, bytes, 'Documento');
        return;
      }

      final widgets = <pw.Widget>[];

      // Iterar sobre los hijos directos del cuerpo en orden secuencial estricto
      for (final child in body.children) {
        if (child is! XmlElement) continue;

        if (child.name.local == 'p') {
          final pWidget = _parseDocxParagraph(child, imageRelMap, imagesData);
          if (pWidget != null) widgets.add(pWidget);
        } else if (child.name.local == 'tbl') {
          final tblWidget = _parseDocxTable(child, imageRelMap, imagesData);
          if (tblWidget != null) widgets.add(tblWidget);
        }
      }

      if (widgets.isEmpty) {
        widgets.add(pw.Text('Documento vacío', style: const pw.TextStyle(color: PdfColors.grey)));
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 36),
          build: (context) => widgets,
        ),
      );
    } catch (e) {
      debugPrint('[DocumentConverter] Error convirtiendo DOCX: $e');
      _convertGenericTextToPdf(pdf, bytes, 'Documento');
    }
  }

  pw.Widget? _parseDocxParagraph(
    XmlElement pElement,
    Map<String, String> imageRelMap,
    Map<String, Uint8List> imagesData,
  ) {
    // 1. Alineación del párrafo
    pw.TextAlign align = pw.TextAlign.left;
    final jc = pElement.findAllElements('w:jc').firstOrNull;
    if (jc != null) {
      final val = jc.getAttribute('w:val');
      if (val == 'center') align = pw.TextAlign.center;
      if (val == 'right') align = pw.TextAlign.right;
      if (val == 'both') align = pw.TextAlign.justify;
    }

    // 2. Detección de encabezado
    bool isHeading = false;
    double baseFontSize = 10.5;
    final pStyle = pElement.findAllElements('w:pStyle').firstOrNull;
    if (pStyle != null) {
      final styleVal = pStyle.getAttribute('w:val')?.toLowerCase() ?? '';
      if (styleVal.contains('heading') || styleVal.contains('título') || styleVal.contains('titulo')) {
        isHeading = true;
        baseFontSize = styleVal.contains('1') ? 16.0 : (styleVal.contains('2') ? 13.5 : 12.0);
      }
    }

    // 3. Revisar si el párrafo contiene una imagen en línea
    final drawings = pElement.findAllElements('a:blip');
    final inlineImages = <pw.Widget>[];

    for (final blip in drawings) {
      final rId = blip.getAttribute('r:embed');
      if (rId != null && imageRelMap.containsKey(rId)) {
        final imgPath = imageRelMap[rId]!;
        final imgBytes = imagesData[imgPath];
        if (imgBytes != null && imgBytes.isNotEmpty) {
          try {
            final memImage = pw.MemoryImage(imgBytes);
            inlineImages.add(
              pw.Container(
                margin: const pw.EdgeInsets.symmetric(vertical: 6),
                alignment: align == pw.TextAlign.center
                    ? pw.Alignment.center
                    : (align == pw.TextAlign.right ? pw.Alignment.centerRight : pw.Alignment.centerLeft),
                child: pw.ConstrainedBox(
                  constraints: const pw.BoxConstraints(maxHeight: 260, maxWidth: 480),
                  child: pw.Image(memImage, fit: pw.BoxFit.contain),
                ),
              ),
            );
          } catch (_) {}
        }
      }
    }

    // 4. Procesar runs de texto
    final runs = pElement.findAllElements('w:r');
    final spans = <pw.InlineSpan>[];

    for (final r in runs) {
      final t = r.findElements('w:t').map((e) => e.innerText).join();
      if (t.isEmpty) continue;

      final isBold = r.findAllElements('w:b').isNotEmpty || isHeading;
      final isItalic = r.findAllElements('w:i').isNotEmpty;

      // Color del texto
      PdfColor color = isHeading ? PdfColors.black : PdfColors.black;
      final colorEl = r.findAllElements('w:color').firstOrNull;
      if (colorEl != null) {
        final val = colorEl.getAttribute('w:val');
        if (val != null && val.length == 6 && val != 'auto') {
          try {
            color = PdfColor.fromHex(val);
          } catch (_) {}
        }
      }

      // Tamaño de fuente personalizado en medios puntos (ej. 24 = 12pt)
      double fontSize = isHeading ? baseFontSize : 10.5;
      final szEl = r.findAllElements('w:sz').firstOrNull;
      if (szEl != null) {
        final szVal = double.tryParse(szEl.getAttribute('w:val') ?? '');
        if (szVal != null && szVal > 0) {
          fontSize = (szVal / 2).clamp(7.0, 32.0);
        }
      }

      spans.add(
        pw.TextSpan(
          text: t,
          style: pw.TextStyle(
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            fontStyle: isItalic ? pw.FontStyle.italic : pw.FontStyle.normal,
            fontSize: fontSize,
            color: color,
          ),
        ),
      );
    }

    if (spans.isEmpty && inlineImages.isEmpty) {
      return pw.SizedBox(height: 5);
    }

    if (inlineImages.isNotEmpty && spans.isEmpty) {
      return pw.Column(children: inlineImages);
    }

    final textWidget = pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: isHeading ? 4.0 : 1.5),
      child: pw.RichText(
        textAlign: align,
        text: pw.TextSpan(children: spans),
      ),
    );

    if (inlineImages.isNotEmpty) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          textWidget,
          ...inlineImages,
        ],
      );
    }

    return textWidget;
  }

  pw.Widget? _parseDocxTable(
    XmlElement tblElement,
    Map<String, String> imageRelMap,
    Map<String, Uint8List> imagesData,
  ) {
    // 1. Extraer anchos de columna definidos en <w:tblGrid>
    final gridCols = tblElement.findAllElements('w:gridCol').toList();
    final columnWidths = <int, pw.TableColumnWidth>{};
    if (gridCols.isNotEmpty) {
      for (var i = 0; i < gridCols.length; i++) {
        final w = double.tryParse(gridCols[i].getAttribute('w:w') ?? '1000') ?? 1000;
        columnWidths[i] = pw.FlexColumnWidth(w > 0 ? w : 1000);
      }
    }

    // 2. Extraer filas
    final trElements = tblElement.findElements('w:tr').toList();
    if (trElements.isEmpty) return null;

    final tableRows = <pw.TableRow>[];

    for (final tr in trElements) {
      final tcElements = tr.findElements('w:tc').toList();
      if (tcElements.isEmpty) continue;

      final cellWidgets = <pw.Widget>[];

      for (final tc in tcElements) {
        // Color de fondo de celda <w:shd w:fill="...">
        PdfColor? cellBg;
        final shd = tc.findAllElements('w:shd').firstOrNull;
        if (shd != null) {
          final fill = shd.getAttribute('w:fill');
          if (fill != null && fill.length == 6 && fill != 'auto' && fill != 'none') {
            try {
              cellBg = PdfColor.fromHex(fill);
            } catch (_) {}
          }
        }

        // Párrafos contenidos dentro de la celda
        final pElements = tc.findElements('w:p');
        final cellChildren = <pw.Widget>[];

        for (final pEl in pElements) {
          final pWidget = _parseDocxParagraph(pEl, imageRelMap, imagesData);
          if (pWidget != null) cellChildren.add(pWidget);
        }

        if (cellChildren.isEmpty) {
          cellChildren.add(pw.Text(' ', style: const pw.TextStyle(fontSize: 9)));
        }

        cellWidgets.add(
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            color: cellBg,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: cellChildren,
            ),
          ),
        );
      }

      if (cellWidgets.isNotEmpty) {
        tableRows.add(pw.TableRow(children: cellWidgets));
      }
    }

    if (tableRows.isEmpty) return null;

    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 8),
      child: pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.6),
        columnWidths: columnWidths.isNotEmpty ? columnWidths : null,
        children: tableRows,
      ),
    );
  }

  // ===========================================================================
  // 2. CONVERSIÓN DE EXCEL (.XLSX) A PDF CON CUADRÍCULA LIMPIA (SIN CABECERAS EXTRA)
  // ===========================================================================
  void _convertXlsxToPdf(pw.Document pdf, List<int> bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);

      // 1. Leer sharedStrings.xml
      final sharedStrings = <String>[];
      final sharedStringsFile = archive.findFile('xl/sharedStrings.xml');
      if (sharedStringsFile != null) {
        final xml = utf8.decode(sharedStringsFile.content as List<int>, allowMalformed: true);
        final doc = XmlDocument.parse(xml);
        for (final si in doc.findAllElements('si')) {
          final t = si.findAllElements('t').map((e) => e.innerText).join();
          sharedStrings.add(t);
        }
      }

      // 2. Leer la primera hoja de cálculo disponible (sheet1.xml)
      final sheetFile = archive.findFile('xl/worksheets/sheet1.xml') ??
          archive.files.firstWhere(
            (f) => f.name.startsWith('xl/worksheets/sheet') && f.name.endsWith('.xml'),
            orElse: () => ArchiveFile('', 0, []),
          );

      if (sheetFile.size == 0) {
        _convertGenericTextToPdf(pdf, bytes, 'Hoja de Cálculo');
        return;
      }

      final sheetXml = utf8.decode(sheetFile.content as List<int>, allowMalformed: true);
      final sheetDoc = XmlDocument.parse(sheetXml);

      final rowElements = sheetDoc.findAllElements('row');
      final gridData = <List<String>>[];
      var maxColumns = 0;

      for (final r in rowElements.take(100)) {
        final rowCells = <String>[];
        for (final c in r.findElements('c')) {
          final tAttr = c.getAttribute('t');
          final vElement = c.findElements('v').firstOrNull;
          String cellValue = '';

          if (vElement != null) {
            final val = vElement.innerText.trim();
            if (tAttr == 's') {
              final idx = int.tryParse(val);
              if (idx != null && idx >= 0 && idx < sharedStrings.length) {
                cellValue = sharedStrings[idx];
              } else {
                cellValue = val;
              }
            } else {
              cellValue = val;
            }
          } else {
            final isElement = c.findElements('is').firstOrNull;
            if (isElement != null) {
              cellValue = isElement.findAllElements('t').map((e) => e.innerText).join();
            }
          }
          rowCells.add(cellValue);
        }

        if (rowCells.length > maxColumns) {
          maxColumns = rowCells.length;
        }
        gridData.add(rowCells);
      }

      final normalizedRows = <pw.TableRow>[];

      // Cabecera de letras de columnas (A, B, C...) limpia
      final colHeaderWidgets = <pw.Widget>[
        pw.Container(
          width: 22,
          padding: const pw.EdgeInsets.all(3.5),
          color: PdfColor.fromHex('107C41'),
          alignment: pw.Alignment.center,
          child: pw.Text('#', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 7.5)),
        ),
      ];

      for (var c = 0; c < maxColumns && c < 12; c++) {
        final colLetter = String.fromCharCode(65 + c);
        colHeaderWidgets.add(
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(3.5),
              color: PdfColor.fromHex('107C41'),
              alignment: pw.Alignment.center,
              child: pw.Text(
                colLetter,
                style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 7.5),
              ),
            ),
          ),
        );
      }
      normalizedRows.add(pw.TableRow(children: colHeaderWidgets));

      for (var rIdx = 0; rIdx < gridData.length; rIdx++) {
        final row = gridData[rIdx];
        final rowWidgets = <pw.Widget>[
          pw.Container(
            width: 22,
            padding: const pw.EdgeInsets.all(3.0),
            color: PdfColors.grey200,
            alignment: pw.Alignment.center,
            child: pw.Text('${rIdx + 1}', style: const pw.TextStyle(fontSize: 7.0, color: PdfColors.grey700)),
          ),
        ];

        for (var c = 0; c < maxColumns && c < 12; c++) {
          final cellText = c < row.length ? row[c] : '';
          final isNumber = double.tryParse(cellText) != null;

          rowWidgets.add(
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.0),
                color: rIdx.isEven ? PdfColors.white : PdfColor.fromHex('F7FAF8'),
                alignment: isNumber ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
                child: pw.Text(
                  cellText,
                  maxLines: 2,
                  overflow: pw.TextOverflow.clip,
                  style: pw.TextStyle(
                    fontSize: 7.5,
                    fontWeight: rIdx == 0 ? pw.FontWeight.bold : pw.FontWeight.normal,
                    color: PdfColors.black,
                  ),
                ),
              ),
            ),
          );
        }

        normalizedRows.add(pw.TableRow(children: rowWidgets));
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(20),
          build: (context) => [
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              children: normalizedRows,
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('[DocumentConverter] Error convirtiendo XLSX: $e');
      _convertGenericTextToPdf(pdf, bytes, 'Hoja de Cálculo');
    }
  }

  // ===========================================================================
  // 3. CONVERSIÓN DE POWERPOINT (.PPTX) A PDF LIMPIO EN 16:9
  // ===========================================================================
  void _convertPptxToPdf(pw.Document pdf, List<int> bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);

      // Encontrar todas las diapositivas ppt/slides/slideX.xml ordenadas
      final slideFiles = archive.files.where((f) {
        return f.name.startsWith('ppt/slides/slide') && f.name.endsWith('.xml');
      }).toList();

      slideFiles.sort((a, b) {
        final numA = int.tryParse(RegExp(r'\d+').firstMatch(p.basename(a.name))?.group(0) ?? '0') ?? 0;
        final numB = int.tryParse(RegExp(r'\d+').firstMatch(p.basename(b.name))?.group(0) ?? '0') ?? 0;
        return numA.compareTo(numB);
      });

      if (slideFiles.isEmpty) {
        _convertGenericTextToPdf(pdf, bytes, 'Presentación');
        return;
      }

      // Extraer imágenes de diapositivas en ppt/media/
      final mediaImages = <String, Uint8List>{};
      for (final file in archive.files) {
        if (file.isFile && file.name.startsWith('ppt/media/')) {
          mediaImages[p.basename(file.name)] = Uint8List.fromList(file.content as List<int>);
        }
      }

      var slideIndex = 1;

      for (final slideFile in slideFiles) {
        final slideXml = utf8.decode(slideFile.content as List<int>, allowMalformed: true);
        final doc = XmlDocument.parse(slideXml);

        final shapes = doc.findAllElements('p:sp');
        String slideTitle = '';
        final bulletPoints = <String>[];

        for (final sp in shapes) {
          final txBody = sp.findElements('p:txBody').firstOrNull;
          if (txBody == null) continue;

          final paragraphs = txBody.findElements('a:p');
          for (final pEl in paragraphs) {
            final pText = pEl.findAllElements('a:t').map((e) => e.innerText).join().trim();
            if (pText.isEmpty) continue;

            if (slideTitle.isEmpty) {
              slideTitle = pText;
            } else {
              bulletPoints.add(pText);
            }
          }
        }

        if (slideTitle.isEmpty && bulletPoints.isNotEmpty) {
          slideTitle = bulletPoints.removeAt(0);
        }
        if (slideTitle.isEmpty) {
          slideTitle = 'Diapositiva $slideIndex';
        }

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.all(28),
            build: (context) {
              return pw.Container(
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColors.grey300, width: 1.0),
                ),
                padding: const pw.EdgeInsets.all(24),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    // Título de la diapositiva
                    pw.Text(
                      slideTitle,
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('1E293B'),
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Divider(color: PdfColor.fromHex('CBD5E1'), thickness: 1.0),
                    pw.SizedBox(height: 14),

                    // Contenido y viñetas
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          for (final point in bulletPoints.take(8)) ...[
                            pw.Row(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Container(
                                  margin: const pw.EdgeInsets.only(top: 5, right: 8),
                                  width: 5,
                                  height: 5,
                                  decoration: const pw.BoxDecoration(
                                    color: PdfColors.blueGrey700,
                                    shape: pw.BoxShape.circle,
                                  ),
                                ),
                                pw.Expanded(
                                  child: pw.Text(
                                    point,
                                    style: const pw.TextStyle(fontSize: 13, height: 1.35, color: PdfColors.black),
                                  ),
                                ),
                              ],
                            ),
                            pw.SizedBox(height: 10),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );

        slideIndex++;
      }
    } catch (e) {
      debugPrint('[DocumentConverter] Error convirtiendo PPTX: $e');
      _convertGenericTextToPdf(pdf, bytes, 'Presentación');
    }
  }

  // ===========================================================================
  // 4. SOPORTE DE ARCHIVOS LEGACY (.DOC, .XLS, .PPT) Y TEXTO PLANO
  // ===========================================================================
  void _convertLegacyOfficeToPdf(pw.Document pdf, List<int> bytes) {
    final buffer = StringBuffer();
    var currentWord = StringBuffer();

    for (var b in bytes) {
      if ((b >= 32 && b <= 126) || b == 10 || b == 13 || b == 9 || (b >= 160 && b <= 255)) {
        currentWord.writeCharCode(b);
      } else {
        if (currentWord.length >= 4) {
          buffer.writeln(currentWord.toString());
        }
        currentWord.clear();
      }
    }
    if (currentWord.length >= 4) {
      buffer.writeln(currentWord.toString());
    }

    final rawLines = buffer.toString().split('\n').where((l) => l.trim().length > 3).take(150).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          for (final line in rawLines) ...[
            pw.Text(line, style: const pw.TextStyle(fontSize: 10.5, height: 1.3)),
            pw.SizedBox(height: 3),
          ],
        ],
      ),
    );
  }

  void _convertGenericTextToPdf(pw.Document pdf, List<int> bytes, String title) {
    String text;
    try {
      text = utf8.decode(bytes);
    } catch (_) {
      text = String.fromCharCodes(bytes.where((b) => b >= 32 && b <= 126));
    }

    final lines = text.split('\n').take(200).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          for (final line in lines) ...[
            pw.Text(line, style: const pw.TextStyle(fontSize: 10.5, height: 1.25)),
            pw.SizedBox(height: 2),
          ],
        ],
      ),
    );
  }
}
