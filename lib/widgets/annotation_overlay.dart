import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/annotation_models.dart';

/// Cache statica dei bitmap immagine. Il decode di un'immagine e' costoso:
/// lo facciamo una sola volta per path e lo riusiamo ad ogni repaint
/// (es. durante lo zoom continuo), evitando lag.
class AnnotationImageCache {
  static final Map<String, ui.Image> _cache = {};
  static final Set<String> _loading = {};

  static ui.Image? get(String path) => _cache[path];

  static Future<void> ensure(String path, VoidCallback onLoaded) async {
    if (_cache.containsKey(path) || _loading.contains(path)) return;
    _loading.add(path);
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      _cache[path] = frame.image;
      onLoaded();
    } catch (_) {
      // immagine non leggibile: resta il placeholder
    } finally {
      _loading.remove(path);
    }
  }
}

/// Overlay disegnato SOPRA una singola pagina PDF.
/// Riceve il Rect della pagina (gia' trasformato da zoom/pan dal viewer)
/// e converte le coordinate normalizzate 0-1 in pixel schermo: cosi' le
/// annotazioni restano ancorate al foglio a qualsiasi zoom/pan.
class AnnotationOverlay extends StatefulWidget {
  final int pageNumber;
  final Rect pageRect;
  final List<Annotation> annotations;
  final AnnotationTool tool;
  final Color color;
  final double strokeWidth;
  final double opacity;
  final bool readOnly;
  final ValueChanged<Annotation> onAdd;
  final void Function(String id, double dnx, double dny) onMove;
  final ValueChanged<Annotation> onSelect;

  /// Cancellazione immediata (usata dalla gomma).
  final ValueChanged<String> onErase;

  /// Richiesta di inserimento immagine: l'editor apre l'image picker e
  /// crea l'ImageAnnotation alla posizione normalizzata indicata.
  final void Function(int page, Offset norm) onImageRequest;

  final String? selectedId;

  const AnnotationOverlay({
    super.key,
    required this.pageNumber,
    required this.pageRect,
    required this.annotations,
    required this.tool,
    required this.color,
    required this.strokeWidth,
    required this.opacity,
    required this.onAdd,
    required this.onMove,
    required this.onSelect,
    required this.onErase,
    required this.onImageRequest,
    this.selectedId,
    this.readOnly = false,
  });

  @override
  State<AnnotationOverlay> createState() => _AnnotationOverlayState();
}

class _AnnotationOverlayState extends State<AnnotationOverlay> {
  List<Offset>? _stroke; // coordinate normalizzate
  Offset? _shapeStart;
  Offset? _shapeEnd;
  String? _draggingId;
  Offset? _lastDragNorm;

  @override
  void initState() {
    super.initState();
    _preloadImages();
  }

  @override
  void didUpdateWidget(covariant AnnotationOverlay old) {
    super.didUpdateWidget(old);
    _preloadImages();
  }

  void _preloadImages() {
    for (final a in widget.annotations) {
      if (a is ImageAnnotation) {
        AnnotationImageCache.ensure(a.imagePath, () {
          if (mounted) setState(() {});
        });
      }
    }
  }

  Offset _toNorm(Offset local) {
    final r = widget.pageRect;
    return Offset(
      ((local.dx - r.left) / r.width).clamp(0.0, 1.0),
      ((local.dy - r.top) / r.height).clamp(0.0, 1.0),
    );
  }

  bool _insidePage(Offset local) => widget.pageRect.contains(local);

  Annotation? _hitTest(Offset norm) {
    for (final a in widget.annotations.reversed) {
      if (a.page != widget.pageNumber) continue;
      final d = (a.anchor - norm).distance;
      if (d < 0.06) return a;
    }
    return null;
  }

  void _onPanStart(DragStartDetails d) {
    if (widget.readOnly) return;
    if (!_insidePage(d.localPosition)) return;
    final norm = _toNorm(d.localPosition);

    if (widget.tool == AnnotationTool.select) {
      final hit = _hitTest(norm);
      if (hit != null && !hit.locked) {
        _draggingId = hit.id;
        _lastDragNorm = norm;
        widget.onSelect(hit);
      } else if (hit != null) {
        widget.onSelect(hit);
      }
      return;
    }

    if (widget.tool == AnnotationTool.pen ||
        widget.tool == AnnotationTool.highlight ||
        widget.tool == AnnotationTool.signature ||
        widget.tool == AnnotationTool.eraser) {
      setState(() => _stroke = [norm]);
    } else if (widget.tool == AnnotationTool.rect ||
        widget.tool == AnnotationTool.circle ||
        widget.tool == AnnotationTool.line ||
        widget.tool == AnnotationTool.arrow) {
      setState(() {
        _shapeStart = norm;
        _shapeEnd = norm;
      });
    }
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (widget.readOnly) return;
    final norm = _toNorm(d.localPosition);
    if (_draggingId != null && _lastDragNorm != null) {
      final dnx = norm.dx - _lastDragNorm!.dx;
      final dny = norm.dy - _lastDragNorm!.dy;
      widget.onMove(_draggingId!, dnx, dny);
      _lastDragNorm = norm;
      return;
    }
    if (_stroke != null) {
      setState(() => _stroke!.add(norm));
    } else if (_shapeStart != null) {
      setState(() => _shapeEnd = norm);
    }
  }

  void _onPanEnd(DragEndDetails d) {
    if (widget.readOnly) return;
    if (_draggingId != null) {
      _draggingId = null;
      _lastDragNorm = null;
      return;
    }
    // Gomma: rimuove le annotazioni vicine al tratto.
    if (widget.tool == AnnotationTool.eraser && _stroke != null) {
      _eraseAlong(_stroke!);
      setState(() {
        _stroke = null;
        _shapeStart = null;
        _shapeEnd = null;
      });
      return;
    }
    if (_stroke != null && _stroke!.length > 1) {
      final isHl = widget.tool == AnnotationTool.highlight;
      widget.onAdd(StrokeAnnotation(
        id: UniqueKey().toString(),
        page: widget.pageNumber,
        points: List.from(_stroke!),
        color: widget.color,
        opacity: isHl ? 0.35 : widget.opacity,
        strokeWidth: isHl ? widget.strokeWidth * 3 : widget.strokeWidth,
        isHighlight: isHl,
      ));
    } else if (_shapeStart != null && _shapeEnd != null) {
      final shape = switch (widget.tool) {
        AnnotationTool.rect => 'rect',
        AnnotationTool.circle => 'circle',
        AnnotationTool.line => 'line',
        AnnotationTool.arrow => 'arrow',
        _ => 'rect',
      };
      widget.onAdd(ShapeAnnotation(
        id: UniqueKey().toString(),
        page: widget.pageNumber,
        start: _shapeStart!,
        end: _shapeEnd!,
        shape: shape,
        color: widget.color,
        opacity: widget.opacity,
        strokeWidth: widget.strokeWidth,
      ));
    }
    setState(() {
      _stroke = null;
      _shapeStart = null;
      _shapeEnd = null;
    });
  }

  /// Cancella le annotazioni il cui anchor passa entro una soglia dal tratto.
  void _eraseAlong(List<Offset> path) {
    const threshold = 0.04;
    final toErase = <String>{};
    for (final pt in path) {
      for (final a in widget.annotations) {
        if (a.page != widget.pageNumber || a.locked) continue;
        if ((a.anchor - pt).distance < threshold) {
          toErase.add(a.id);
        }
      }
    }
    for (final id in toErase) {
      widget.onErase(id);
    }
  }

  Future<void> _onTapDown(TapDownDetails d) async {
    if (widget.readOnly) return;
    if (!_insidePage(d.localPosition)) return;
    final norm = _toNorm(d.localPosition);

    if (widget.tool == AnnotationTool.select) {
      final hit = _hitTest(norm);
      if (hit != null) widget.onSelect(hit);
      return;
    }
    if (widget.tool == AnnotationTool.checkmark) {
      widget.onAdd(CheckmarkAnnotation(
        id: UniqueKey().toString(),
        page: widget.pageNumber,
        position: norm,
        color: widget.color,
        opacity: widget.opacity,
      ));
    } else if (widget.tool == AnnotationTool.text) {
      final text = await _promptText(context);
      if (text != null && text.isNotEmpty) {
        widget.onAdd(TextAnnotation(
          id: UniqueKey().toString(),
          page: widget.pageNumber,
          position: norm,
          text: text,
          fontSizeFrac: 0.022,
          color: widget.color,
          opacity: widget.opacity,
        ));
      }
    } else if (widget.tool == AnnotationTool.image) {
      // Delego all'editor: apre image picker e crea l'ImageAnnotation.
      widget.onImageRequest(widget.pageNumber, norm);
    }
  }

  Future<String?> _promptText(BuildContext context) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF161A22),
        title: const Text('Inserisci testo',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 5,
          minLines: 1,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'Scrivi qui...'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, ctrl.text),
              child: const Text('Inserisci')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final painter = _AnnotPainter(
      pageNumber: widget.pageNumber,
      pageRect: widget.pageRect,
      annotations: widget.annotations,
      previewStroke: widget.readOnly ? null : _stroke,
      previewShapeStart: widget.readOnly ? null : _shapeStart,
      previewShapeEnd: widget.readOnly ? null : _shapeEnd,
      tool: widget.tool,
      color: widget.color,
      strokeWidth: widget.strokeWidth,
      opacity: widget.opacity,
      selectedId: widget.readOnly ? null : widget.selectedId,
    );

    if (widget.readOnly) {
      // In sola lettura non intercettiamo gesti: il viewer gestisce
      // zoom/pan liberamente; disegniamo solo le annotazioni esistenti.
      return IgnorePointer(
        child: CustomPaint(size: Size.infinite, painter: painter),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      onTapDown: _onTapDown,
      child: CustomPaint(size: Size.infinite, painter: painter),
    );
  }
}

class _AnnotPainter extends CustomPainter {
  final int pageNumber;
  final Rect pageRect;
  final List<Annotation> annotations;
  final List<Offset>? previewStroke;
  final Offset? previewShapeStart;
  final Offset? previewShapeEnd;
  final AnnotationTool tool;
  final Color color;
  final double strokeWidth;
  final double opacity;
  final String? selectedId;

  _AnnotPainter({
    required this.pageNumber,
    required this.pageRect,
    required this.annotations,
    this.previewStroke,
    this.previewShapeStart,
    this.previewShapeEnd,
    required this.tool,
    required this.color,
    required this.strokeWidth,
    required this.opacity,
    this.selectedId,
  });

  Offset _px(Offset norm) => Offset(
        pageRect.left + norm.dx * pageRect.width,
        pageRect.top + norm.dy * pageRect.height,
      );

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(pageRect);

    for (final a in annotations) {
      if (a.page != pageNumber) continue;
      _drawAnnotation(canvas, a);
      if (a.id == selectedId) _drawSelection(canvas, a);
    }

    if (previewStroke != null && previewStroke!.length > 1) {
      final isHl = tool == AnnotationTool.highlight;
      final isEraser = tool == AnnotationTool.eraser;
      final p = Paint()
        ..color = isEraser
            ? Colors.red.withOpacity(0.4)
            : color.withOpacity(isHl ? 0.35 : opacity)
        ..strokeWidth =
            (isHl ? strokeWidth * 3 : strokeWidth) * pageRect.width / 1000
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final path = Path()
        ..moveTo(_px(previewStroke![0]).dx, _px(previewStroke![0]).dy);
      for (int i = 1; i < previewStroke!.length; i++) {
        path.lineTo(_px(previewStroke![i]).dx, _px(previewStroke![i]).dy);
      }
      canvas.drawPath(path, p);
    }
    if (previewShapeStart != null && previewShapeEnd != null) {
      final p = Paint()
        ..color = color.withOpacity(opacity)
        ..strokeWidth = strokeWidth * pageRect.width / 1000
        ..style = PaintingStyle.stroke;
      _drawShapePx(canvas, tool, _px(previewShapeStart!),
          _px(previewShapeEnd!), p);
    }
    canvas.restore();
  }

  void _drawAnnotation(Canvas canvas, Annotation a) {
    final scale = pageRect.width / 1000;
    final paint = Paint()
      ..color = a.color.withOpacity(a.opacity)
      ..strokeWidth = a.strokeWidth * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (a is StrokeAnnotation) {
      if (a.points.length < 2) {
        canvas.drawCircle(_px(a.points[0]), a.strokeWidth * scale / 2,
            Paint()..color = a.color.withOpacity(a.opacity));
        return;
      }
      final path = Path()..moveTo(_px(a.points[0]).dx, _px(a.points[0]).dy);
      for (int i = 1; i < a.points.length; i++) {
        path.lineTo(_px(a.points[i]).dx, _px(a.points[i]).dy);
      }
      canvas.drawPath(path, paint);
    } else if (a is ShapeAnnotation) {
      _drawShapePx(canvas, _strToTool(a.shape), _px(a.start), _px(a.end),
          paint);
    } else if (a is TextAnnotation) {
      final fontPx = a.fontSizeFrac * pageRect.height;
      final tp = TextPainter(
        text: TextSpan(
          text: a.text,
          style: TextStyle(
              color: a.color.withOpacity(a.opacity), fontSize: fontPx),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: pageRect.width);
      tp.paint(canvas, _px(a.position));
    } else if (a is CheckmarkAnnotation) {
      final sz = a.sizeFrac * pageRect.height;
      final c = _px(a.position);
      final cp = Paint()
        ..color = a.color.withOpacity(a.opacity)
        ..strokeWidth = 3 * scale
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final path = Path()
        ..moveTo(c.dx - sz * 0.4, c.dy)
        ..lineTo(c.dx - sz * 0.1, c.dy + sz * 0.35)
        ..lineTo(c.dx + sz * 0.45, c.dy - sz * 0.4);
      canvas.drawPath(path, cp);
    } else if (a is ImageAnnotation) {
      final rect = Rect.fromLTWH(
        _px(a.position).dx,
        _px(a.position).dy,
        a.widthFrac * pageRect.width,
        a.heightFrac * pageRect.height,
      );
      final img = AnnotationImageCache.get(a.imagePath);
      if (img != null) {
        final src = Rect.fromLTWH(
            0, 0, img.width.toDouble(), img.height.toDouble());
        canvas.drawImageRect(img, src, rect, Paint());
      } else {
        final ph = Paint()
          ..color = Colors.grey.withOpacity(0.25)
          ..style = PaintingStyle.fill;
        canvas.drawRect(rect, ph);
        final bp = Paint()
          ..color = Colors.grey
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
        canvas.drawRect(rect, bp);
        final tp = TextPainter(
          text: const TextSpan(
              text: '🖼️', style: TextStyle(fontSize: 24)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas,
            rect.center - Offset(tp.width / 2, tp.height / 2));
      }
    }
  }

  void _drawSelection(Canvas canvas, Annotation a) {
    final sp = Paint()
      ..color = a.locked ? Colors.orange : Colors.blueAccent
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    if (a is ImageAnnotation) {
      final rect = Rect.fromLTWH(
        _px(a.position).dx,
        _px(a.position).dy,
        a.widthFrac * pageRect.width,
        a.heightFrac * pageRect.height,
      );
      canvas.drawRect(rect.inflate(2), sp);
      return;
    }
    final c = _px(a.anchor);
    canvas.drawCircle(c, 18, sp);
    if (a.locked) {
      final lp = TextPainter(
        text: const TextSpan(
            text: '🔒', style: TextStyle(fontSize: 14)),
        textDirection: TextDirection.ltr,
      )..layout();
      lp.paint(canvas, c + const Offset(-7, -7));
    }
  }

  void _drawShapePx(
      Canvas canvas, AnnotationTool t, Offset s, Offset e, Paint paint) {
    switch (t) {
      case AnnotationTool.rect:
        canvas.drawRect(Rect.fromPoints(s, e), paint);
        break;
      case AnnotationTool.circle:
        canvas.drawOval(Rect.fromPoints(s, e), paint);
        break;
      case AnnotationTool.line:
        canvas.drawLine(s, e, paint);
        break;
      case AnnotationTool.arrow:
        canvas.drawLine(s, e, paint);
        final angle = (e - s).direction;
        const head = 16.0;
        final p1 = e - Offset.fromDirection(angle - 0.5, head);
        final p2 = e - Offset.fromDirection(angle + 0.5, head);
        final fill = Paint()
          ..color = paint.color
          ..style = PaintingStyle.fill;
        canvas.drawPath(
          Path()
            ..moveTo(e.dx, e.dy)
            ..lineTo(p1.dx, p1.dy)
            ..lineTo(p2.dx, p2.dy)
            ..close(),
          fill,
        );
        break;
      default:
        break;
    }
  }

  AnnotationTool _strToTool(String s) {
    switch (s) {
      case 'rect': return AnnotationTool.rect;
      case 'circle': return AnnotationTool.circle;
      case 'line': return AnnotationTool.line;
      case 'arrow': return AnnotationTool.arrow;
      default: return AnnotationTool.rect;
    }
  }

  @override
  bool shouldRepaint(_AnnotPainter old) => true;
}
