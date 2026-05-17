import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart' show Color;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/annotation_models.dart';

class PdfService {
  /// Esporta il PDF con annotazioni embedded. Le coordinate normalizzate
  /// 0-1 vengono convertite nelle coordinate reali della pagina PDF.
  static Future<Uint8List> buildPdf(
    Uint8List originalBytes,
    Map<int, List<Annotation>> annotations,
    Map<String, String> metadata, {
    String? password,
    bool allowPrint = true,
    bool allowCopy = true,
    bool allowModify = false,
  }) async {
    final document = PdfDocument(inputBytes: originalBytes);

    document.documentInformation.title = metadata['title'] ?? '';
    document.documentInformation.author = metadata['author'] ?? '';
    document.documentInformation.subject = metadata['subject'] ?? '';
    document.documentInformation.keywords = metadata['keywords'] ?? '';
    document.documentInformation.creator =
        metadata['creator'] ?? 'PDF Studio';

    for (int i = 0; i < document.pages.count; i++) {
      final page = document.pages[i];
      final list = annotations[i + 1] ?? [];
      if (list.isEmpty) continue;
      final g = page.graphics;
      final w = page.size.width;
      final h = page.size.height;
      for (final a in list) {
        _draw(g, a, w, h);
      }
    }

    if (password != null && password.isNotEmpty) {
      document.security.userPassword = password;
      document.security.ownerPassword = password;
      document.security.algorithm = PdfEncryptionAlgorithm.aesx256Bit;
      final perms = <PdfPermissionsFlags>[];
      if (allowPrint) perms.add(PdfPermissionsFlags.print);
      if (allowCopy) perms.add(PdfPermissionsFlags.copyContent);
      if (allowModify) perms.add(PdfPermissionsFlags.editContent);
      if (perms.isNotEmpty) document.security.permissions.addAll(perms);
    }

    final bytes = Uint8List.fromList(await document.save());
    document.dispose();
    return bytes;
  }

  static void _draw(PdfGraphics g, Annotation a, double w, double h) {
    final col = PdfColor(a.color.red, a.color.green, a.color.blue);
    final brush = PdfSolidBrush(col);
    final pen = PdfPen(col, width: a.strokeWidth)
      ..lineCap = PdfLineCap.round
      ..lineJoin = PdfLineJoin.round;

    if (a is StrokeAnnotation) {
      if (a.points.length < 2) return;
      for (int i = 1; i < a.points.length; i++) {
        g.drawLine(
          pen,
          ui.Offset(a.points[i - 1].dx * w, a.points[i - 1].dy * h),
          ui.Offset(a.points[i].dx * w, a.points[i].dy * h),
        );
      }
    } else if (a is ShapeAnnotation) {
      final s = ui.Offset(a.start.dx * w, a.start.dy * h);
      final e = ui.Offset(a.end.dx * w, a.end.dy * h);
      final l = math.min(s.dx, e.dx);
      final t = math.min(s.dy, e.dy);
      final rw = (e.dx - s.dx).abs();
      final rh = (e.dy - s.dy).abs();
      switch (a.shape) {
        case 'rect':
          g.drawRectangle(pen: pen, bounds: ui.Rect.fromLTWH(l, t, rw, rh));
          break;
        case 'circle':
          g.drawEllipse(ui.Rect.fromLTWH(l, t, rw, rh), pen: pen);
          break;
        case 'line':
          g.drawLine(pen, s, e);
          break;
        case 'arrow':
          g.drawLine(pen, s, e);
          final ang = math.atan2(e.dy - s.dy, e.dx - s.dx);
          const hl = 14.0;
          g.drawLine(pen, e,
              ui.Offset(e.dx - hl * math.cos(ang - 0.5),
                  e.dy - hl * math.sin(ang - 0.5)));
          g.drawLine(pen, e,
              ui.Offset(e.dx - hl * math.cos(ang + 0.5),
                  e.dy - hl * math.sin(ang + 0.5)));
          break;
      }
    } else if (a is TextAnnotation) {
      final fontPx = (a.fontSizeFrac * h).clamp(6.0, 96.0);
      final font = PdfStandardFont(PdfFontFamily.helvetica, fontPx);
      g.drawString(a.text, font,
          brush: brush,
          bounds: ui.Rect.fromLTWH(
              a.position.dx * w, a.position.dy * h,
              w - a.position.dx * w, h - a.position.dy * h));
    } else if (a is CheckmarkAnnotation) {
      final sz = a.sizeFrac * h;
      final c = ui.Offset(a.position.dx * w, a.position.dy * h);
      final cp = PdfPen(col, width: 3)..lineCap = PdfLineCap.round;
      g.drawLine(cp, ui.Offset(c.dx - sz * 0.4, c.dy),
          ui.Offset(c.dx - sz * 0.1, c.dy + sz * 0.35));
      g.drawLine(cp, ui.Offset(c.dx - sz * 0.1, c.dy + sz * 0.35),
          ui.Offset(c.dx + sz * 0.45, c.dy - sz * 0.4));
    } else if (a is ImageAnnotation) {
      try {
        final bytes = File(a.imagePath).readAsBytesSync();
        final img = PdfBitmap(bytes);
        g.drawImage(
            img,
            ui.Rect.fromLTWH(a.position.dx * w, a.position.dy * h,
                a.widthFrac * w, a.heightFrac * h));
      } catch (_) {}
    }
  }
}
