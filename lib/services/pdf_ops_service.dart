import 'dart:io';
import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Operazioni di manipolazione strutturale dei PDF.
///
/// NOTA TECNICA: In syncfusion_flutter_pdf per Flutter NON esiste
/// importPageRange (disponibile solo nella versione .NET).
/// L'API corretta per copiare pagine tra documenti e':
///   PdfTemplate t = srcDoc.pages[i].createTemplate();
///   destPage.graphics.drawPdfTemplate(t, Offset.zero, destPage.size);
/// Questo preserva contenuto vettoriale, testo, immagini e annotazioni
/// della pagina sorgente disegnandola sul canvas della pagina di destinazione.
class PdfOpsService {

  // ------------------------------------------------------------------
  // Helper interno: copia le pagine [indices] (0-based) da [src] in [out].
  // Preserva le dimensioni originali di ogni pagina.
  // ------------------------------------------------------------------
  static void _copyPages(PdfDocument src, PdfDocument out,
      List<int> indices) {
    for (final i in indices) {
      if (i < 0 || i >= src.pages.count) continue;
      final srcPage = src.pages[i];
      final template = srcPage.createTemplate();
      // Usa sezioni per rispettare le dimensioni originali della pagina.
      final section = out.sections!.add();
      section.pageSettings.size = srcPage.size;
      section.pageSettings.margins.all = 0;
      final destPage = section.pages.add();
      destPage.graphics
          .drawPdfTemplate(template, Offset.zero, destPage.size);
    }
  }

  // ------------------------------------------------------------------
  // MERGE: unisce piu' PDF in ordine.
  // ------------------------------------------------------------------
  static Future<Uint8List> mergePdfs(
    List<String> filePaths, {
    Map<String, String>? passwords,
  }) async {
    if (filePaths.isEmpty) throw ArgumentError('Nessun file da unire');

    final out = PdfDocument();
    final sources = <PdfDocument>[];
    try {
      for (final path in filePaths) {
        final bytes = await File(path).readAsBytes();
        final pwd = passwords?[path];
        PdfDocument src;
        try {
          src = pwd != null
              ? PdfDocument(inputBytes: bytes, password: pwd)
              : PdfDocument(inputBytes: bytes);
        } catch (e) {
          throw Exception(
              'Impossibile aprire "${_name(path)}": $e');
        }
        sources.add(src);
        _copyPages(src, out,
            List.generate(src.pages.count, (i) => i));
      }
      return Uint8List.fromList(await out.save());
    } finally {
      for (final s in sources) s.dispose();
      out.dispose();
    }
  }

  // ------------------------------------------------------------------
  // EXTRACT RANGE: estrae pagine da startPage a endPage (1-based).
  // ------------------------------------------------------------------
  static Future<Uint8List> extractRange(
    String filePath,
    int startPage,
    int endPage, {
    String? password,
  }) async {
    final bytes = await File(filePath).readAsBytes();
    final src = password != null
        ? PdfDocument(inputBytes: bytes, password: password)
        : PdfDocument(inputBytes: bytes);
    final total = src.pages.count;
    final lo = startPage.clamp(1, total) - 1;
    final hi = endPage.clamp(1, total) - 1;
    final indices = List.generate(
        (lo <= hi ? hi : lo) - (lo <= hi ? lo : hi) + 1,
        (i) => (lo <= hi ? lo : hi) + i);

    final out = PdfDocument();
    try {
      _copyPages(src, out, indices);
      return Uint8List.fromList(await out.save());
    } finally {
      src.dispose();
      out.dispose();
    }
  }

  // ------------------------------------------------------------------
  // SPLIT PER PAGE: divide in N file da 1 pagina.
  // ------------------------------------------------------------------
  static Future<List<({int page, Uint8List bytes})>> splitPerPage(
    String filePath, {
    String? password,
  }) async {
    final bytes = await File(filePath).readAsBytes();
    final src = password != null
        ? PdfDocument(inputBytes: bytes, password: password)
        : PdfDocument(inputBytes: bytes);
    final total = src.pages.count;
    final result = <({int page, Uint8List bytes})>[];
    try {
      for (int i = 0; i < total; i++) {
        final out = PdfDocument();
        _copyPages(src, out, [i]);
        result.add(
            (page: i + 1, bytes: Uint8List.fromList(await out.save())));
        out.dispose();
      }
      return result;
    } finally {
      src.dispose();
    }
  }

  // ------------------------------------------------------------------
  // REORDER: riordina le pagine secondo [newOrder] (1-based).
  // ------------------------------------------------------------------
  static Future<Uint8List> reorderPages(
    String filePath,
    List<int> newOrder, {
    String? password,
  }) async {
    final bytes = await File(filePath).readAsBytes();
    final src = password != null
        ? PdfDocument(inputBytes: bytes, password: password)
        : PdfDocument(inputBytes: bytes);
    final total = src.pages.count;
    final indices = newOrder
        .where((p) => p >= 1 && p <= total)
        .map((p) => p - 1)
        .toList();
    // Fallback: se l'ordine e' vuoto usa quello originale.
    if (indices.isEmpty) {
      indices.addAll(List.generate(total, (i) => i));
    }
    final out = PdfDocument();
    try {
      _copyPages(src, out, indices);
      return Uint8List.fromList(await out.save());
    } finally {
      src.dispose();
      out.dispose();
    }
  }

  // ------------------------------------------------------------------
  // EXTRACT PAGES: estrae le pagine indicate (1-based, in ordine).
  // ------------------------------------------------------------------
  static Future<Uint8List> extractPages(
    String filePath,
    List<int> pages, {
    String? password,
  }) async {
    final bytes = await File(filePath).readAsBytes();
    final src = password != null
        ? PdfDocument(inputBytes: bytes, password: password)
        : PdfDocument(inputBytes: bytes);
    final total = src.pages.count;
    final indices = pages
        .where((p) => p >= 1 && p <= total)
        .map((p) => p - 1)
        .toList();
    if (indices.isEmpty) {
      indices.addAll(List.generate(total, (i) => i));
    }
    final out = PdfDocument();
    try {
      _copyPages(src, out, indices);
      return Uint8List.fromList(await out.save());
    } finally {
      src.dispose();
      out.dispose();
    }
  }

  // ------------------------------------------------------------------
  // PAGE COUNT
  // ------------------------------------------------------------------
  static Future<int> pageCount(String filePath,
      {String? password}) async {
    final bytes = await File(filePath).readAsBytes();
    final doc = password != null
        ? PdfDocument(inputBytes: bytes, password: password)
        : PdfDocument(inputBytes: bytes);
    final n = doc.pages.count;
    doc.dispose();
    return n;
  }

  // ------------------------------------------------------------------
  // PARSE PAGE RANGES: "1-3, 5, 8-10" -> [1,2,3,5,8,9,10]
  // ------------------------------------------------------------------
  static List<int> parsePageRanges(String input, int maxPage) {
    final pages = <int>{};
    final cleaned = input.replaceAll(' ', '');
    if (cleaned.isEmpty) throw const FormatException('Intervallo vuoto');
    for (final token in cleaned.split(',')) {
      if (token.isEmpty) continue;
      if (token.contains('-')) {
        final parts = token.split('-');
        if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty) {
          throw FormatException('Intervallo non valido: "$token"');
        }
        final a = int.tryParse(parts[0]);
        final b = int.tryParse(parts[1]);
        if (a == null || b == null) {
          throw FormatException('Intervallo non valido: "$token"');
        }
        final lo = a <= b ? a : b;
        final hi = a <= b ? b : a;
        for (int i = lo; i <= hi; i++) {
          if (i >= 1 && i <= maxPage) pages.add(i);
        }
      } else {
        final n = int.tryParse(token);
        if (n == null) throw FormatException('Numero non valido: "$token"');
        if (n >= 1 && n <= maxPage) pages.add(n);
      }
    }
    if (pages.isEmpty) {
      throw FormatException(
          'Nessuna pagina valida (max $maxPage)');
    }
    return pages.toList()..sort();
  }

  static String _name(String path) =>
      path.split(Platform.pathSeparator).last;
}
