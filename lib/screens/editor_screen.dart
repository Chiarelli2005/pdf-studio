import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import '../models/annotation_models.dart';
import '../services/pdf_service.dart';
import '../services/save_service.dart';
import '../services/print_share_service.dart';
import '../widgets/annotation_overlay.dart';
import '../widgets/tool_bar.dart';
import '../widgets/password_dialog.dart';
import 'file_ops_screen.dart';

class EditorScreen extends StatefulWidget {
  final String filePath;

  /// Quando true l'app parte in SOLA LETTURA (es. PDF aperto da un'altra
  /// app via "Apri con..."). L'utente puo' passare all'editor con un
  /// pulsante dedicato.
  final bool readOnly;

  const EditorScreen({
    super.key,
    required this.filePath,
    this.readOnly = false,
  });

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final _controller = PdfViewerController();

  late bool _readOnly;

  AnnotationTool _tool = AnnotationTool.select;
  Color _color = const Color(0xFFFF5A3C);
  double _stroke = 3.0;
  double _opacity = 1.0;

  final Map<int, List<Annotation>> _ann = {};
  final List<Map<int, List<Annotation>>> _history = [];
  int _hIndex = -1;

  String? _selectedId;
  String _fileName = '';
  Uint8List? _originalBytes;

  @override
  void initState() {
    super.initState();
    _readOnly = widget.readOnly;
    _fileName = widget.filePath.split(Platform.pathSeparator).last;
    _originalBytes = File(widget.filePath).readAsBytesSync();
  }

  // ----------------------- Undo / Redo -----------------------

  void _snapshot() {
    final snap = <int, List<Annotation>>{};
    _ann.forEach((k, v) => snap[k] = List.from(v));
    if (_hIndex < _history.length - 1) {
      _history.removeRange(_hIndex + 1, _history.length);
    }
    _history.add(snap);
    _hIndex = _history.length - 1;
  }

  void _restore(int idx) {
    _ann.clear();
    _history[idx].forEach((k, v) => _ann[k] = List.from(v));
  }

  void _undo() {
    if (_hIndex > 0) {
      setState(() {
        _hIndex--;
        _restore(_hIndex);
      });
    }
  }

  void _redo() {
    if (_hIndex < _history.length - 1) {
      setState(() {
        _hIndex++;
        _restore(_hIndex);
      });
    }
  }

  // ----------------------- Annotazioni -----------------------

  void _add(Annotation a) {
    _snapshot();
    setState(() => _ann.putIfAbsent(a.page, () => []).add(a));
  }

  void _move(String id, double dnx, double dny) {
    setState(() {
      for (final entry in _ann.entries) {
        final i = entry.value.indexWhere((e) => e.id == id);
        if (i != -1) {
          entry.value[i] = entry.value[i].moveBy(dnx, dny);
          break;
        }
      }
    });
  }

  void _eraseById(String id) {
    _snapshot();
    setState(() {
      for (final list in _ann.values) {
        list.removeWhere((a) => a.id == id);
      }
      if (_selectedId == id) _selectedId = null;
    });
  }

  Annotation? get _selected {
    for (final list in _ann.values) {
      for (final a in list) {
        if (a.id == _selectedId) return a;
      }
    }
    return null;
  }

  void _toggleLock() {
    final s = _selected;
    if (s != null) setState(() => s.locked = !s.locked);
  }

  void _deleteSelected() {
    if (_selectedId == null) return;
    _snapshot();
    setState(() {
      for (final list in _ann.values) {
        list.removeWhere((a) => a.id == _selectedId);
      }
      _selectedId = null;
    });
  }

  Future<void> _editSelectedText() async {
    final s = _selected;
    if (s is! TextAnnotation) return;
    final ctrl = TextEditingController(text: s.text);
    final r = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF161A22),
        title: const Text('Modifica testo',
            style: TextStyle(color: Colors.white)),
        content: TextField(
            controller: ctrl,
            autofocus: true,
            maxLines: 5,
            minLines: 1,
            style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, ctrl.text),
              child: const Text('Salva')),
        ],
      ),
    );
    if (r != null) setState(() => s.text = r);
  }

  // ----------------------- Inserimento immagine -----------------------

  Future<void> _onImageRequest(int page, Offset norm) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF161A22),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: Color(0xFFFF5A3C)),
              title: const Text('Galleria',
                  style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined,
                  color: Color(0xFFFF5A3C)),
              title: const Text('Fotocamera',
                  style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(
        source: source,
        maxWidth: 2000,
        imageQuality: 90,
      );
      if (xfile == null) return;

      // Ricodifichiamo l'immagine in PNG reale: image_picker su alcuni
      // device restituisce HEIC/WebP che Syncfusion non sa esportare nel
      // PDF. decodeImageFromList + toByteData(png) garantisce un PNG valido.
      final srcBytes = await File(xfile.path).readAsBytes();
      final decoded = await decodeImageFromList(srcBytes);
      final pngData =
          await decoded.toByteData(format: ui.ImageByteFormat.png);
      if (pngData == null) {
        throw Exception('Impossibile decodificare l\'immagine');
      }
      final dir = await getApplicationDocumentsDirectory();
      final dest =
          '${dir.path}/img_${DateTime.now().millisecondsSinceEpoch}.png';
      await File(dest)
          .writeAsBytes(pngData.buffer.asUint8List(), flush: true);

      final aspect = decoded.width / decoded.height;

      // Larghezza default 30% della pagina, altezza proporzionale.
      const wFrac = 0.30;
      // pagina A4 ~ rapporto 1:1.414; normalizziamo l'altezza in modo che
      // l'immagine non sia deformata sullo schermo.
      final hFrac = wFrac / aspect * 0.707; // 0.707 ~ w/h pagina A4

      _add(ImageAnnotation(
        id: UniqueKey().toString(),
        page: page,
        position: Offset(
          (norm.dx - wFrac / 2).clamp(0.0, 1.0 - wFrac),
          (norm.dy - hFrac / 2).clamp(0.0, 1.0 - hFrac),
        ),
        widthFrac: wFrac,
        heightFrac: hFrac,
        imagePath: dest,
      ));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Immagine aggiunta. Usa "Sposta" per riposizionarla.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore inserimento immagine: $e')),
        );
      }
    }
  }

  // ----------------------- Salvataggio -----------------------

  Future<void> _save({bool withPassword = false}) async {
    String? password;
    bool aPrint = true, aCopy = true, aModify = false;

    if (withPassword) {
      final res = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => const ExportSecureDialog(),
      );
      if (res == null) return;
      password = res['password'] as String;
      final perms = res['permissions'] as Map<String, dynamic>;
      aPrint = perms['print'] as bool;
      aCopy = perms['copy'] as bool;
      aModify = perms['modify'] as bool;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF5A3C))),
    );

    try {
      final bytes = await PdfService.buildPdf(
        _originalBytes!,
        _ann,
        {'creator': 'PDF Studio'},
        password: password,
        allowPrint: aPrint,
        allowCopy: aCopy,
        allowModify: aModify,
      );
      if (mounted) Navigator.pop(context);

      final suggested = _fileName.replaceAll('.pdf', '') +
          (withPassword ? '_protetto.pdf' : '_modificato.pdf');
      final path = await SaveService.saveWithDialog(bytes, suggested);

      if (mounted && path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Salvato: $path')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore salvataggio: $e')),
        );
      }
    }
  }

  /// Costruisce il PDF con le annotazioni correnti embedded (senza
  /// password). Riusato da stampa e condivisione.
  Future<Uint8List> _buildCurrentPdf() {
    return PdfService.buildPdf(
      _originalBytes!,
      _ann,
      {'creator': 'PDF Studio'},
    );
  }

  /// Stampa il documento (con annotazioni) tramite il dialog di stampa
  /// nativo Android: rileva automaticamente stampanti WiFi/cloud/USB e
  /// permette di scegliere quali pagine stampare, copie, ecc.
  Future<void> _printCurrent() async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF5A3C))),
    );
    try {
      final bytes = await _buildCurrentPdf();
      if (mounted) Navigator.pop(context);
      await PrintShareService.printPdf(
        bytes,
        name: _fileName.replaceAll('.pdf', ''),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore stampa: $e')),
        );
      }
    }
  }

  /// Condivide il documento (con annotazioni) tramite il foglio di
  /// condivisione nativo: email, messaggistica, cloud, ecc.
  Future<void> _shareCurrent() async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF5A3C))),
    );
    try {
      final bytes = await _buildCurrentPdf();
      if (mounted) Navigator.pop(context);
      final fname = _fileName.endsWith('.pdf')
          ? _fileName
          : '$_fileName.pdf';
      await PrintShareService.sharePdfBytes(bytes, filename: fname);
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore condivisione: $e')),
        );
      }
    }
  }

  // ----------------------- UI -----------------------

  @override
  Widget build(BuildContext context) {
    final sel = _selected;
    return Scaffold(
      backgroundColor: const Color(0xFF0E1014),
      appBar: AppBar(
        title: Row(
          children: [
            Flexible(
              child: Text(_fileName, overflow: TextOverflow.ellipsis),
            ),
            if (_readOnly) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0x332A9D8F),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF2A9D8F)),
                ),
                child: const Text('SOLA LETTURA',
                    style: TextStyle(
                        color: Color(0xFF2A9D8F),
                        fontSize: 10,
                        letterSpacing: 1.2)),
              ),
            ],
          ],
        ),
        actions: [
          if (_readOnly)
            // In sola lettura mostriamo solo: passa a editor + menu file.
            TextButton.icon(
              onPressed: () => setState(() => _readOnly = false),
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('Modifica'),
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFFF5A3C)),
            )
          else ...[
            IconButton(
                onPressed: _hIndex > 0 ? _undo : null,
                icon: const Icon(Icons.undo)),
            IconButton(
                onPressed: _hIndex < _history.length - 1 ? _redo : null,
                icon: const Icon(Icons.redo)),
            IconButton(
                onPressed: () => _save(),
                icon: const Icon(Icons.save_outlined),
                tooltip: 'Salva copia'),
            IconButton(
                onPressed: () => _save(withPassword: true),
                icon: const Icon(Icons.lock_outline),
                tooltip: 'Salva protetto'),
          ],
          // Condivisione e stampa: utili sia in lettura sia in modifica.
          IconButton(
            onPressed: _shareCurrent,
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Condividi copia',
          ),
          IconButton(
            onPressed: _printCurrent,
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Stampa',
          ),
          // Menu operazioni su file (unione/divisione/conversione/riordino):
          // disponibile sempre, anche in sola lettura, perche' non
          // modifica le annotazioni ma opera sul file.
          IconButton(
            tooltip: 'Strumenti file',
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    FileOpsScreen(initialPdfPath: widget.filePath),
              ));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // La toolbar di editing compare SOLO se non siamo in sola lettura.
          if (!_readOnly)
            EditorToolbar(
              currentTool: _tool,
              currentColor: _color,
              strokeWidth: _stroke,
              opacity: _opacity,
              onToolChanged: (t) => setState(() => _tool = t),
              onColorChanged: (c) => setState(() => _color = c),
              onStrokeChanged: (w) => setState(() => _stroke = w),
              onOpacityChanged: (o) => setState(() => _opacity = o),
            ),
          if (!_readOnly && sel != null)
            Container(
              color: const Color(0xFF161A22),
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Text(sel.type,
                      style: const TextStyle(
                          color: Color(0xFF8B94A8), fontSize: 12)),
                  const Spacer(),
                  IconButton(
                    icon: Icon(sel.locked ? Icons.lock : Icons.lock_open,
                        size: 20,
                        color: sel.locked ? Colors.orange : Colors.white),
                    onPressed: _toggleLock,
                    tooltip: sel.locked ? 'Sblocca' : 'Blocca',
                  ),
                  if (sel is TextAnnotation)
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: _editSelectedText,
                      tooltip: 'Modifica testo',
                    ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 20, color: Colors.redAccent),
                    onPressed: _deleteSelected,
                    tooltip: 'Elimina',
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => setState(() => _selectedId = null),
                  ),
                ],
              ),
            ),
          Expanded(
            child: PdfViewer.file(
              widget.filePath,
              controller: _controller,
              params: PdfViewerParams(
                enableTextSelection: _readOnly, // selezione testo in lettura
                pageOverlaysBuilder: (context, pageRect, page) {
                  return [
                    AnnotationOverlay(
                      pageNumber: page.pageNumber,
                      // FIX ZOOM: passiamo il pageRect REALE (gia'
                      // trasformato da zoom/pan). Prima era azzerato con
                      // `Offset.zero & pageRect.size`, causando il
                      // disallineamento delle annotazioni con lo zoom.
                      pageRect: pageRect,
                      annotations: _ann[page.pageNumber] ?? [],
                      tool: _readOnly ? AnnotationTool.select : _tool,
                      color: _color,
                      strokeWidth: _stroke,
                      opacity: _opacity,
                      readOnly: _readOnly,
                      selectedId: _readOnly ? null : _selectedId,
                      onAdd: _add,
                      onMove: _move,
                      onErase: _eraseById,
                      onImageRequest: _onImageRequest,
                      onSelect: (a) =>
                          setState(() => _selectedId = a.id),
                    ),
                  ];
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
