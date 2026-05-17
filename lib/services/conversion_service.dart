import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:archive/archive.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:xml/xml.dart';

/// Conversione documentale OFFLINE e APPROSSIMATA.
///
/// LIMITI NOTI (dichiarati esplicitamente all'utente nella UI):
/// - Word -> PDF: estrae testo, paragrafi, grassetto/corsivo basilare,
///   tabelle semplici. NON replica: layout multi-colonna, header/footer,
///   caselle di testo, SmartArt, WordArt, posizionamento assoluto immagini,
///   stili avanzati, numerazione automatica complessa.
/// - PDF -> Word: estrae il testo pagina per pagina in un .docx con
///   paragrafi. NON ricostruisce: layout esatto, font originali,
///   tabelle, immagini, colonne. E' utile per riusare il TESTO, non per
///   ottenere una copia fedele impaginata.
///
/// Per fedelta' 1:1 servirebbe un motore tipo LibreOffice (non disponibile
/// offline su Android). Questa implementazione copre i casi d'uso comuni
/// (lettere, verbali, testi lineari) senza dipendere da internet.
class ConversionService {
  // ---------------------------------------------------------------------
  // WORD (.docx) -> PDF
  // ---------------------------------------------------------------------

  /// Estrae i paragrafi da un .docx. Un .docx e' uno ZIP che contiene
  /// word/document.xml con il flusso del testo.
  static List<_DocxParagraph> _parseDocx(Uint8List docxBytes) {
    final archive = ZipDecoder().decodeBytes(docxBytes);
    final docFile = archive.files.firstWhere(
      (f) => f.name == 'word/document.xml',
      orElse: () => throw Exception(
          'File .docx non valido: manca word/document.xml'),
    );
    final xmlStr = utf8.decode(
      docFile.content as List<int>,
      allowMalformed: true,
    );
    final doc = XmlDocument.parse(xmlStr);

    final paragraphs = <_DocxParagraph>[];
    // I paragrafi sono <w:p>, le run di testo <w:r><w:t>.
    for (final p in doc.findAllElements('w:p')) {
      final runs = <_DocxRun>[];
      for (final r in p.findElements('w:r')) {
        final rPr = r.getElement('w:rPr');
        final bold = rPr?.getElement('w:b') != null;
        final italic = rPr?.getElement('w:i') != null;
        final buffer = StringBuffer();
        for (final t in r.findElements('w:t')) {
          buffer.write(t.innerText);
        }
        // <w:tab/> e <w:br/> per spaziatura/ritorni a capo basilari.
        if (r.getElement('w:tab') != null) buffer.write('\t');
        if (r.getElement('w:br') != null) buffer.write('\n');
        final text = buffer.toString();
        if (text.isNotEmpty) {
          runs.add(_DocxRun(text: text, bold: bold, italic: italic));
        }
      }
      // Stile heading?
      final pStyle = p
          .getElement('w:pPr')
          ?.getElement('w:pStyle')
          ?.getAttribute('w:val');
      final isHeading = pStyle != null &&
          pStyle.toLowerCase().contains('heading');
      paragraphs.add(_DocxParagraph(runs: runs, isHeading: isHeading));
    }
    return paragraphs;
  }

  /// Converte un .docx in PDF (testo lineare). Ritorna i bytes del PDF.
  static Future<Uint8List> wordToPdf(String docxPath) async {
    final docxBytes = await File(docxPath).readAsBytes();
    final paragraphs = _parseDocx(docxBytes);

    final document = PdfDocument();
    document.pageSettings.size = PdfPageSize.a4;
    document.pageSettings.margins.all = 48;

    final bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 11);
    final boldFont = PdfStandardFont(PdfFontFamily.helvetica, 11,
        style: PdfFontStyle.bold);
    final headingFont = PdfStandardFont(PdfFontFamily.helvetica, 16,
        style: PdfFontStyle.bold);

    final page = document.pages.add();
    final pageWidth = page.getClientSize().width;

    // PdfLayoutFormat con paginazione automatica: il testo che eccede la
    // pagina viene continuato su nuove pagine senza calcoli manuali.
    final layoutFormat = PdfLayoutFormat(
      layoutType: PdfLayoutType.paginate,
      breakType: PdfLayoutBreakType.fitPage,
    );

    PdfLayoutResult? last;
    double currentY = 0;
    PdfPage currentPage = page;
    bool drewAnything = false;

    for (final para in paragraphs) {
      final text = para.runs
          .map((r) => r.text)
          .join()
          .replaceAll('\n', ' ')
          .trim();
      if (text.isEmpty) {
        currentY += 8; // spaziatura per paragrafi vuoti
        continue;
      }
      final font = para.isHeading
          ? headingFont
          : (para.runs.isNotEmpty && para.runs.first.bold
              ? boldFont
              : bodyFont);

      final element = PdfTextElement(text: text, font: font);
      last = element.draw(
        page: currentPage,
        bounds: Rect.fromLTWH(
            0, currentY, pageWidth, 0), // height 0 = auto-paginate
        format: layoutFormat,
      );
      if (last != null) {
        drewAnything = true;
        currentPage = last.page;
        currentY = last.bounds.bottom + (para.isHeading ? 12 : 6);
      }
    }

    if (!drewAnything) {
      page.graphics.drawString(
        '(Documento Word vuoto o non leggibile)',
        bodyFont,
        brush: PdfSolidBrush(PdfColor(120, 120, 120)),
        bounds: const Rect.fromLTWH(0, 0, 400, 20),
      );
    }

    final out = Uint8List.fromList(await document.save());
    document.dispose();
    return out;
  }

  // ---------------------------------------------------------------------
  // PDF -> WORD (.docx)
  // ---------------------------------------------------------------------

  /// Estrae il testo di tutte le pagine del PDF e costruisce un .docx
  /// minimale ma valido (apribile da Word/LibreOffice/Google Docs).
  static Future<Uint8List> pdfToWord(String pdfPath,
      {String? password}) async {
    final pdfBytes = await File(pdfPath).readAsBytes();
    final doc = password != null
        ? PdfDocument(inputBytes: pdfBytes, password: password)
        : PdfDocument(inputBytes: pdfBytes);

    final extractor = PdfTextExtractor(doc);
    final buffer = StringBuffer();
    for (int i = 0; i < doc.pages.count; i++) {
      final text = extractor.extractText(startPageIndex: i, endPageIndex: i);
      buffer.writeln(text);
      if (i < doc.pages.count - 1) {
        buffer.writeln(); // separatore di pagina logico
      }
    }
    doc.dispose();

    return _buildDocx(buffer.toString());
  }

  /// Costruisce uno ZIP .docx Office Open XML minimale a partire dal testo.
  /// Ogni riga del testo diventa un paragrafo <w:p>.
  static Uint8List _buildDocx(String text) {
    final paragraphs = text.split('\n');
    final body = StringBuffer();
    for (final line in paragraphs) {
      final escaped = _xmlEscape(line);
      if (escaped.trim().isEmpty) {
        body.write('<w:p/>');
      } else {
        body.write(
            '<w:p><w:r><w:t xml:space="preserve">$escaped</w:t></w:r></w:p>');
      }
    }

    final documentXml =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:body>${body.toString()}'
        '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/>'
        '<w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/>'
        '</w:sectPr></w:body></w:document>';

    const contentTypes =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
        '</Types>';

    const rels =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" '
        'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" '
        'Target="word/document.xml"/></Relationships>';

    final archive = Archive();
    void add(String name, String content) {
      final bytes = utf8.encode(content);
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    add('[Content_Types].xml', contentTypes);
    add('_rels/.rels', rels);
    add('word/document.xml', documentXml);

    final zipped = ZipEncoder().encode(archive);
    return Uint8List.fromList(zipped);
  }

  static String _xmlEscape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}

class _DocxRun {
  final String text;
  final bool bold;
  final bool italic;
  _DocxRun({required this.text, this.bold = false, this.italic = false});
}

class _DocxParagraph {
  final List<_DocxRun> runs;
  final bool isHeading;
  _DocxParagraph({required this.runs, this.isHeading = false});
}
