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
      // Generar un hash numérico positivo simple y seguro para nombre de archivo
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

  /// Retorna la ruta al PDF en caché si ya existe, de lo contrario convierte el documento y lo guarda.
  Future<String> getOrConvertDocumentToPdf(String filePath) async {
    final sourceFile = File(filePath);
    if (!await sourceFile.exists()) {
      throw Exception('El archivo original no existe en la ruta: $filePath');
    }

    final cacheDir = await _getCacheDirectory();
    final cacheKey = _generateCacheKey(sourceFile);
    final cachedPdfFile = File(p.join(cacheDir.path, cacheKey));

    // Si ya existe en caché con tamaño válido, devolver inmediatamente
    if (await cachedPdfFile.exists() && (await cachedPdfFile.length()) > 0) {
      debugPrint('[DocumentConverter] Cache hit: ${cachedPdfFile.path}');
      return cachedPdfFile.path;
    }

    debugPrint('[DocumentConverter] Convirtiendo archivo a PDF: $filePath');
    final ext = p.extension(filePath).toLowerCase();

    // Lectura de bytes en modo sólo lectura (Read-Only)
    final bytes = await sourceFile.readAsBytes();
    final pdf = pw.Document();

    final fileName = p.basename(filePath);

    if (ext == '.docx') {
      _convertDocxToPdf(pdf, bytes, fileName);
    } else if (ext == '.xlsx') {
      _convertXlsxToPdf(pdf, bytes, fileName);
    } else if (ext == '.pptx') {
      _convertPptxToPdf(pdf, bytes, fileName);
    } else if (ext == '.doc' || ext == '.xls' || ext == '.ppt') {
      _convertLegacyOfficeToPdf(pdf, bytes, fileName, ext);
    } else {
      _convertGenericTextToPdf(pdf, bytes, fileName);
    }

    final pdfBytes = await pdf.save();
    await cachedPdfFile.writeAsBytes(pdfBytes, flush: true);
    debugPrint('[DocumentConverter] PDF guardado en caché: ${cachedPdfFile.path}');

    return cachedPdfFile.path;
  }

  // ===========================================================================
  // 1. CONVERSIÓN DE WORD (.DOCX) A PDF CON FORMATO Y TABLAS
  // ===========================================================================
  void _convertDocxToPdf(pw.Document pdf, Uint8List bytes, String fileName) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final documentXmlFile = archive.findFile('word/document.xml');

      if (documentXmlFile == null) {
        _convertGenericTextToPdf(pdf, bytes, fileName);
        return;
      }

      final xmlContent = utf8.decode(documentXmlFile.content as List<int>, allowMalformed: true);
      final documentXml = XmlDocument.parse(xmlContent);

      // Extraer imágenes incrustadas en word/media/
      final imagesMap = <String, Uint8List>{};
      for (final file in archive.files) {
        if (file.isFile && file.name.startsWith('word/media/')) {
          final imgName = p.basename(file.name);
          imagesMap[imgName] = Uint8List.fromList(file.content as List<int>);
        }
      }

      final body = documentXml.findAllElements('w:body').firstOrNull;
      if (body == null) {
        _convertGenericTextToPdf(pdf, bytes, fileName);
        return;
      }

      final widgets = <pw.Widget>[];

      // Cabecera institucional del documento Word
      widgets.add(
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          margin: const pw.EdgeInsets.only(bottom: 16),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('EAF0F9'),
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: PdfColor.fromHex('185ABD'), width: 1.5),
          ),
          child: pw.Row(
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('185ABD'),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  'DOCX',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      fileName,
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 14,
                        color: PdfColor.fromHex('185ABD'),
                      ),
                    ),
                    pw.Text(
                      'Documento de Microsoft Word - EduSlide Proyección Didáctica',
                      style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

      // Iterar sobre los hijos directos del cuerpo (párrafos <w:p> y tablas <w:tbl>)
      for (final child in body.children) {
        if (child is! XmlElement) continue;

        if (child.name.local == 'p') {
          // Párrafo
          final pWidget = _parseDocxParagraph(child);
          if (pWidget != null) widgets.add(pWidget);
        } else if (child.name.local == 'tbl') {
          // Tabla
          final tblWidget = _parseDocxTable(child);
          if (tblWidget != null) widgets.add(tblWidget);
        }
      }

      // Si hay imágenes en el documento que no se hayan vinculado en línea, agregarlas como galería
      if (imagesMap.isNotEmpty) {
        widgets.add(pw.SizedBox(height: 12));
        widgets.add(
          pw.Text(
            'Imágenes y Gráficos del Documento:',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColor.fromHex('185ABD')),
          ),
        );
        widgets.add(pw.SizedBox(height: 8));

        for (final entry in imagesMap.entries) {
          try {
            final image = pw.MemoryImage(entry.value);
            widgets.add(
              pw.Container(
                margin: const pw.EdgeInsets.symmetric(vertical: 6),
                alignment: pw.Alignment.center,
                child: pw.ConstrainedBox(
                  constraints: const pw.BoxConstraints(maxHeight: 280),
                  child: pw.Image(image, fit: pw.BoxFit.contain),
                ),
              ),
            );
          } catch (_) {}
        }
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          footer: (context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Text(
              'Página ${context.pageNumber} de ${context.pagesCount} - EduProjects BO',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ),
          build: (context) => widgets,
        ),
      );
    } catch (e) {
      debugPrint('[DocumentConverter] Error convirtiendo DOCX: $e');
      _convertGenericTextToPdf(pdf, bytes, fileName);
    }
  }

  pw.Widget? _parseDocxParagraph(XmlElement pElement) {
    final runs = pElement.findAllElements('w:r');
    final spans = <pw.InlineSpan>[];

    // Detectar alineación del párrafo
    pw.TextAlign align = pw.TextAlign.left;
    final jc = pElement.findAllElements('w:jc').firstOrNull;
    if (jc != null) {
      final val = jc.getAttribute('w:val');
      if (val == 'center') align = pw.TextAlign.center;
      if (val == 'right') align = pw.TextAlign.right;
      if (val == 'both') align = pw.TextAlign.justify;
    }

    // Detectar estilo de encabezado
    bool isHeading = false;
    double fontSize = 10.5;
    final pStyle = pElement.findAllElements('w:pStyle').firstOrNull;
    if (pStyle != null) {
      final styleVal = pStyle.getAttribute('w:val')?.toLowerCase() ?? '';
      if (styleVal.contains('heading') || styleVal.contains('título') || styleVal.contains('titulo')) {
        isHeading = true;
        fontSize = styleVal.contains('1') ? 16 : (styleVal.contains('2') ? 13.5 : 12);
      }
    }

    for (final r in runs) {
      final t = r.findElements('w:t').map((e) => e.innerText).join();
      if (t.isEmpty) continue;

      final isBold = r.findAllElements('w:b').isNotEmpty || isHeading;
      final isItalic = r.findAllElements('w:i').isNotEmpty;

      // Color del texto
      PdfColor color = PdfColors.black;
      final colorEl = r.findAllElements('w:color').firstOrNull;
      if (colorEl != null) {
        final val = colorEl.getAttribute('w:val');
        if (val != null && val.length == 6) {
          try {
            color = PdfColor.fromHex(val);
          } catch (_) {}
        }
      }

      spans.add(
        pw.TextSpan(
          text: t,
          style: pw.TextStyle(
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            fontStyle: isItalic ? pw.FontStyle.italic : pw.FontStyle.normal,
            fontSize: isHeading ? fontSize : 10.5,
            color: isHeading ? PdfColor.fromHex('185ABD') : color,
          ),
        ),
      );
    }

    if (spans.isEmpty) {
      return pw.SizedBox(height: 6);
    }

    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: isHeading ? 6.0 : 2.5),
      child: pw.RichText(
        textAlign: align,
        text: pw.TextSpan(children: spans),
      ),
    );
  }

  pw.Widget? _parseDocxTable(XmlElement tblElement) {
    final rows = tblElement.findElements('w:tr');
    if (rows.isEmpty) return null;

    final tableRows = <pw.TableRow>[];
    var isHeader = true;

    for (final tr in rows) {
      final cells = tr.findElements('w:tc');
      final rowWidgets = <pw.Widget>[];

      for (final tc in cells) {
        final cellText = tc.findAllElements('w:t').map((e) => e.innerText).join(' ').trim();
        rowWidgets.add(
          pw.Container(
            padding: const pw.EdgeInsets.all(6),
            color: isHeader ? PdfColor.fromHex('E8EEF7') : null,
            child: pw.Text(
              cellText,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: isHeader ? PdfColor.fromHex('185ABD') : PdfColors.black,
              ),
            ),
          ),
        );
      }

      if (rowWidgets.isNotEmpty) {
        tableRows.add(pw.TableRow(children: rowWidgets));
        isHeader = false;
      }
    }

    if (tableRows.isEmpty) return null;

    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 10),
      child: pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.8),
        children: tableRows,
      ),
    );
  }

  // ===========================================================================
  // 2. CONVERSIÓN DE EXCEL (.XLSX) A PDF CON CUADRÍCULA Y FORMATO TABULAR
  // ===========================================================================
  void _convertXlsxToPdf(pw.Document pdf, Uint8List bytes, String fileName) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);

      // 1. Leer sharedStrings.xml si existe
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
        _convertGenericTextToPdf(pdf, bytes, fileName);
        return;
      }

      final sheetXml = utf8.decode(sheetFile.content as List<int>, allowMalformed: true);
      final sheetDoc = XmlDocument.parse(sheetXml);

      final rowElements = sheetDoc.findAllElements('row');
      final gridData = <List<String>>[];

      var maxColumns = 0;

      for (final r in rowElements.take(80)) {
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

      // Normalizar columnas para la tabla
      final normalizedRows = <pw.TableRow>[];

      // Cabecera de letras de columnas (A, B, C...)
      final colHeaderWidgets = <pw.Widget>[
        pw.Container(
          width: 24,
          padding: const pw.EdgeInsets.all(4),
          color: PdfColor.fromHex('107C41'),
          alignment: pw.Alignment.center,
          child: pw.Text('#', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8)),
        ),
      ];

      for (var c = 0; c < maxColumns && c < 12; c++) {
        final colLetter = String.fromCharCode(65 + c);
        colHeaderWidgets.add(
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(4),
              color: PdfColor.fromHex('107C41'),
              alignment: pw.Alignment.center,
              child: pw.Text(
                colLetter,
                style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8),
              ),
            ),
          ),
        );
      }
      normalizedRows.add(pw.TableRow(children: colHeaderWidgets));

      for (var rIdx = 0; rIdx < gridData.length; rIdx++) {
        final row = gridData[rIdx];
        final rowWidgets = <pw.Widget>[
          // Número de fila
          pw.Container(
            width: 24,
            padding: const pw.EdgeInsets.all(3.5),
            color: PdfColors.grey200,
            alignment: pw.Alignment.center,
            child: pw.Text('${rIdx + 1}', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
          ),
        ];

        for (var c = 0; c < maxColumns && c < 12; c++) {
          final cellText = c < row.length ? row[c] : '';
          final isNumber = double.tryParse(cellText) != null;

          rowWidgets.add(
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                color: rIdx.isEven ? PdfColors.white : PdfColor.fromHex('F7FAF8'),
                alignment: isNumber ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
                child: pw.Text(
                  cellText,
                  maxLines: 2,
                  overflow: pw.TextOverflow.clip,
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: rIdx == 0 ? pw.FontWeight.bold : pw.FontWeight.normal,
                    color: rIdx == 0 ? PdfColor.fromHex('107C41') : PdfColors.black,
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
          margin: const pw.EdgeInsets.all(28),
          header: (context) => pw.Container(
            padding: const pw.EdgeInsets.all(10),
            margin: const pw.EdgeInsets.only(bottom: 12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('E8F5E9'),
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: PdfColor.fromHex('107C41'), width: 1.2),
            ),
            child: pw.Row(
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('107C41'),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text('XLSX', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                ),
                pw.SizedBox(width: 8),
                pw.Text(
                  fileName,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColor.fromHex('107C41')),
                ),
                pw.Spacer(),
                pw.Text('Hoja 1 - Cuadrícula de Datos', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
              ],
            ),
          ),
          footer: (context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 8),
            child: pw.Text('Página ${context.pageNumber} de ${context.pagesCount} - EduSlide Excel Viewer', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          ),
          build: (context) => [
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.6),
              children: normalizedRows,
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('[DocumentConverter] Error convirtiendo XLSX: $e');
      _convertGenericTextToPdf(pdf, bytes, fileName);
    }
  }

  // ===========================================================================
  // 3. CONVERSIÓN DE POWERPOINT (.PPTX) A PDF EN FORMATO SLIDE LANDSCAPE
  // ===========================================================================
  void _convertPptxToPdf(pw.Document pdf, Uint8List bytes, String fileName) {
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
        _convertGenericTextToPdf(pdf, bytes, fileName);
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
      final totalSlides = slideFiles.length;

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
            margin: const pw.EdgeInsets.all(32),
            build: (context) {
              return pw.Container(
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('FFF8F6'),
                  borderRadius: pw.BorderRadius.circular(12),
                  border: pw.Border.all(color: PdfColor.fromHex('D24726'), width: 2),
                ),
                padding: const pw.EdgeInsets.all(24),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    // Barra superior de la diapositiva
                    pw.Row(
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: pw.BoxDecoration(
                            color: PdfColor.fromHex('D24726'),
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Text(
                            'PPTX - Diapositiva $slideIndex de $totalSlides',
                            style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10),
                          ),
                        ),
                        pw.Spacer(),
                        pw.Text(
                          fileName,
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 16),

                    // Título de la diapositiva
                    pw.Text(
                      slideTitle,
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('D24726'),
                      ),
                    ),
                    pw.Divider(color: PdfColor.fromHex('D24726'), thickness: 1.5),
                    pw.SizedBox(height: 12),

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
                                  margin: const pw.EdgeInsets.only(top: 4, right: 8),
                                  width: 6,
                                  height: 6,
                                  decoration: pw.BoxDecoration(
                                    color: PdfColor.fromHex('D24726'),
                                    shape: pw.BoxShape.circle,
                                  ),
                                ),
                                pw.Expanded(
                                  child: pw.Text(
                                    point,
                                    style: const pw.TextStyle(fontSize: 12.5, height: 1.35),
                                  ),
                                ),
                              ],
                            ),
                            pw.SizedBox(height: 8),
                          ],
                        ],
                      ),
                    ),

                    // Pie de diapositiva
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'EduSlide - Proyección en Aula Didáctica',
                          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                        ),
                        pw.Text(
                          'EduProjects BO',
                          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('D24726')),
                        ),
                      ],
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
      _convertGenericTextToPdf(pdf, bytes, fileName);
    }
  }

  // ===========================================================================
  // 4. SOPORTE DE ARCHIVOS LEGACY (.DOC, .XLS, .PPT) Y TEXTO PLANO
  // ===========================================================================
  void _convertLegacyOfficeToPdf(pw.Document pdf, Uint8List bytes, String fileName, String ext) {
    // Para archivos binarios anteriores a OpenXML, extraer las cadenas legibles en UTF-8 / ASCII
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

    PdfColor themeColor = PdfColor.fromHex('185ABD');
    String tag = 'DOC';
    if (ext == '.xls') {
      themeColor = PdfColor.fromHex('107C41');
      tag = 'XLS';
    } else if (ext == '.ppt') {
      themeColor = PdfColor.fromHex('D24726');
      tag = 'PPT';
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            margin: const pw.EdgeInsets.only(bottom: 16),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('F5F5F5'),
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: themeColor, width: 1.2),
            ),
            child: pw.Row(
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: pw.BoxDecoration(color: themeColor, borderRadius: pw.BorderRadius.circular(4)),
                  child: pw.Text(tag, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Text(
                    fileName,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13, color: themeColor),
                  ),
                ),
              ],
            ),
          ),
          for (final line in rawLines) ...[
            pw.Text(line, style: const pw.TextStyle(fontSize: 10, height: 1.3)),
            pw.SizedBox(height: 3),
          ],
        ],
      ),
    );
  }

  void _convertGenericTextToPdf(pw.Document pdf, Uint8List bytes, String fileName) {
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
          pw.Text(fileName, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.Divider(),
          for (final line in lines) ...[
            pw.Text(line, style: const pw.TextStyle(fontSize: 10, height: 1.25)),
            pw.SizedBox(height: 2),
          ],
        ],
      ),
    );
  }
}
