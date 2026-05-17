import 'package:flutter/material.dart';

/// Tutte le coordinate (Offset) sono NORMALIZZATE 0.0-1.0 rispetto alla pagina.
/// 0,0 = alto-sinistra; 1,1 = basso-destra. Indipendenti da zoom/pan.

enum AnnotationTool {
  select,
  pen,
  highlight,
  eraser,
  text,
  checkmark,
  signature,
  rect,
  circle,
  line,
  arrow,
  image;

  String get label {
    switch (this) {
      case AnnotationTool.select: return 'Sposta';
      case AnnotationTool.pen: return 'Penna';
      case AnnotationTool.highlight: return 'Evidenzia';
      case AnnotationTool.eraser: return 'Gomma';
      case AnnotationTool.text: return 'Testo';
      case AnnotationTool.checkmark: return 'Spunta';
      case AnnotationTool.signature: return 'Firma';
      case AnnotationTool.rect: return 'Rettangolo';
      case AnnotationTool.circle: return 'Cerchio';
      case AnnotationTool.line: return 'Linea';
      case AnnotationTool.arrow: return 'Freccia';
      case AnnotationTool.image: return 'Immagine';
    }
  }

  IconData get icon {
    switch (this) {
      case AnnotationTool.select: return Icons.pan_tool_alt_outlined;
      case AnnotationTool.pen: return Icons.edit;
      case AnnotationTool.highlight: return Icons.brush;
      case AnnotationTool.eraser: return Icons.cleaning_services_outlined;
      case AnnotationTool.text: return Icons.text_fields;
      case AnnotationTool.checkmark: return Icons.check;
      case AnnotationTool.signature: return Icons.draw;
      case AnnotationTool.rect: return Icons.crop_square;
      case AnnotationTool.circle: return Icons.circle_outlined;
      case AnnotationTool.line: return Icons.remove;
      case AnnotationTool.arrow: return Icons.north_east;
      case AnnotationTool.image: return Icons.image_outlined;
    }
  }
}

abstract class Annotation {
  final String id;
  final String type;
  final int page;
  final Color color;
  final double opacity;
  final double strokeWidth;
  bool locked;

  Annotation({
    required this.id,
    required this.type,
    required this.page,
    required this.color,
    required this.opacity,
    required this.strokeWidth,
    this.locked = false,
  });

  Annotation moveBy(double dnx, double dny);
  Offset get anchor;
}

class StrokeAnnotation extends Annotation {
  final List<Offset> points;
  final bool isHighlight;

  StrokeAnnotation({
    required super.id,
    required super.page,
    required this.points,
    required super.color,
    required super.opacity,
    required super.strokeWidth,
    this.isHighlight = false,
    super.locked = false,
  }) : super(type: isHighlight ? 'highlight' : 'pen');

  @override
  Offset get anchor {
    if (points.isEmpty) return Offset.zero;
    double sx = 0, sy = 0;
    for (final p in points) { sx += p.dx; sy += p.dy; }
    return Offset(sx / points.length, sy / points.length);
  }

  @override
  StrokeAnnotation moveBy(double dnx, double dny) => StrokeAnnotation(
        id: id, page: page,
        points: points.map((p) => Offset(p.dx + dnx, p.dy + dny)).toList(),
        color: color, opacity: opacity, strokeWidth: strokeWidth,
        isHighlight: isHighlight, locked: locked);
}

class ShapeAnnotation extends Annotation {
  final Offset start;
  final Offset end;
  final String shape;

  ShapeAnnotation({
    required super.id,
    required super.page,
    required this.start,
    required this.end,
    required this.shape,
    required super.color,
    required super.opacity,
    required super.strokeWidth,
    super.locked = false,
  }) : super(type: shape);

  @override
  Offset get anchor => Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);

  @override
  ShapeAnnotation moveBy(double dnx, double dny) => ShapeAnnotation(
        id: id, page: page,
        start: Offset(start.dx + dnx, start.dy + dny),
        end: Offset(end.dx + dnx, end.dy + dny),
        shape: shape, color: color, opacity: opacity,
        strokeWidth: strokeWidth, locked: locked);
}

class TextAnnotation extends Annotation {
  final Offset position;
  String text;
  final double fontSizeFrac;

  TextAnnotation({
    required super.id,
    required super.page,
    required this.position,
    required this.text,
    required this.fontSizeFrac,
    required super.color,
    required super.opacity,
    super.locked = false,
  }) : super(type: 'text', strokeWidth: 1);

  @override
  Offset get anchor => position;

  @override
  TextAnnotation moveBy(double dnx, double dny) => TextAnnotation(
        id: id, page: page,
        position: Offset(position.dx + dnx, position.dy + dny),
        text: text, fontSizeFrac: fontSizeFrac,
        color: color, opacity: opacity, locked: locked);
}

class CheckmarkAnnotation extends Annotation {
  final Offset position;
  final double sizeFrac;

  CheckmarkAnnotation({
    required super.id,
    required super.page,
    required this.position,
    this.sizeFrac = 0.03,
    required super.color,
    required super.opacity,
    super.locked = false,
  }) : super(type: 'checkmark', strokeWidth: 3);

  @override
  Offset get anchor => position;

  @override
  CheckmarkAnnotation moveBy(double dnx, double dny) => CheckmarkAnnotation(
        id: id, page: page,
        position: Offset(position.dx + dnx, position.dy + dny),
        sizeFrac: sizeFrac, color: color, opacity: opacity, locked: locked);
}

class ImageAnnotation extends Annotation {
  final Offset position;
  final double widthFrac;
  final double heightFrac;
  final String imagePath;

  ImageAnnotation({
    required super.id,
    required super.page,
    required this.position,
    required this.widthFrac,
    required this.heightFrac,
    required this.imagePath,
    super.locked = false,
  }) : super(type: 'image', color: Colors.transparent, opacity: 1, strokeWidth: 0);

  @override
  Offset get anchor => Offset(position.dx + widthFrac / 2, position.dy + heightFrac / 2);

  @override
  ImageAnnotation moveBy(double dnx, double dny) => ImageAnnotation(
        id: id, page: page,
        position: Offset(position.dx + dnx, position.dy + dny),
        widthFrac: widthFrac, heightFrac: heightFrac,
        imagePath: imagePath, locked: locked);
}
