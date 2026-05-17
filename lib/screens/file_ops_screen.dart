import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/conversion_service.dart';
import '../services/pdf_ops_service.dart';
import '../services/print_share_service.dart';
import '../services/save_service.dart';

/// Schermata strumenti file: unione/divisione PDF e conversioni Word<->PDF.
/// Separata dall'editor per non appesantire l'interfaccia di annotazione.
class FileOpsScreen extends StatefulWidget {
  final String? initialPdfPath;
  const FileOpsScreen({super.key, this.initialPdfPath});

  @override
  State<FileOpsScreen> createState() => _FileOpsScreenState();
}

class _FileOpsScreenState extends State<FileOpsScreen> {
  bool _busy = false;
  String _status = '';

  void _setBusy(bool b, [String s = '']) {
    if (!mounted) return;
    setState(() {
      _busy = b;
      _status = s;
    });
  }

  Future<void> _snack(String msg) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // --------------------- UNIONE PDF ---------------------

  Future<void> _mergePdfs() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );
    if (result == null || result.files.length < 2) {
      await _snack('Seleziona almeno 2 PDF da unire');
      return;
    }
    final paths =
        result.files.where((f) => f.path != null).map((f) => f.path!).toList();

    // Riordino manuale opzionale
    final ordered = await _reorderDialog(paths);
    if (ordered == null) return;

    _setBusy(true, 'Unione di ${ordered.length} PDF in corso...');
    try {
      final bytes = await PdfOpsService.mergePdfs(ordered);
      _setBusy(false);
      final saved = await SaveService.saveWithDialog(
          bytes, 'unione_${DateTime.now().millisecondsSinceEpoch}.pdf');
      if (saved != null) await _snack('PDF unito salvato: $saved');
    } catch (e) {
      _setBusy(false);
      await _snack('Errore unione: $e');
    }
  }

  Future<List<String>?> _reorderDialog(List<String> paths) async {
    final items = List<String>.from(paths);
    return showDialog<List<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: const Color(0xFF161A22),
          title: Text('Ordine di unione',
              style: GoogleFonts.jetBrainsMono(
                  color: Colors.white, fontSize: 16)),
          content: SizedBox(
            width: double.maxFinite,
            child: ReorderableListView(
              shrinkWrap: true,
              onReorder: (oldI, newI) {
                setLocal(() {
                  if (newI > oldI) newI--;
                  final it = items.removeAt(oldI);
                  items.insert(newI, it);
                });
              },
              children: [
                for (int i = 0; i < items.length; i++)
                  ListTile(
                    key: ValueKey(items[i]),
                    dense: true,
                    leading: Text('${i + 1}',
                        style: const TextStyle(
                            color: Color(0xFFFF5A3C),
                            fontWeight: FontWeight.bold)),
                    title: Text(
                      items[i].split(Platform.pathSeparator).last,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.drag_handle,
                        color: Color(0xFF5D6580)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annulla')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, items),
                child: const Text('Unisci')),
          ],
        ),
      ),
    );
  }

  // --------------------- DIVISIONE PDF ---------------------

  Future<void> _splitPdf() async {
    String? path = widget.initialPdfPath;
    if (path == null) {
      final r = await FilePicker.platform.pickFiles(
          type: FileType.custom, allowedExtensions: ['pdf']);
      if (r == null || r.files.single.path == null) return;
      path = r.files.single.path!;
    }

    int total;
    try {
      total = await PdfOpsService.pageCount(path);
    } catch (e) {
      await _snack('Impossibile leggere il PDF: $e');
      return;
    }

    final mode = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: const Color(0xFF161A22),
        title: Text('Dividi PDF ($total pagine)',
            style: GoogleFonts.jetBrainsMono(
                color: Colors.white, fontSize: 15)),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'range'),
            child: const Text('Estrai un intervallo di pagine',
                style: TextStyle(color: Colors.white)),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'each'),
            child: const Text('Dividi in file da 1 pagina ciascuno',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (mode == null) return;

    if (mode == 'range') {
      final range = await _rangeDialog(total);
      if (range == null) return;
      _setBusy(true, 'Estrazione pagine ${range.$1}-${range.$2}...');
      try {
        final bytes = await PdfOpsService.extractRange(
            path, range.$1, range.$2);
        _setBusy(false);
        final saved = await SaveService.saveWithDialog(bytes,
            'pagine_${range.$1}-${range.$2}.pdf');
        if (saved != null) await _snack('Salvato: $saved');
      } catch (e) {
        _setBusy(false);
        await _snack('Errore: $e');
      }
    } else {
      _setBusy(true, 'Divisione in $total file...');
      try {
        final parts = await PdfOpsService.splitPerPage(path);
        final dir = Directory(
            '${(await SaveService.appDir()).path}/split_${DateTime.now().millisecondsSinceEpoch}');
        await dir.create(recursive: true);
        for (final p in parts) {
          await File('${dir.path}/pagina_${p.page}.pdf')
              .writeAsBytes(p.bytes);
        }
        _setBusy(false);
        await _snack(
            '${parts.length} file creati in: ${dir.path}');
      } catch (e) {
        _setBusy(false);
        await _snack('Errore divisione: $e');
      }
    }
  }

  Future<(int, int)?> _rangeDialog(int total) async {
    final fromCtrl = TextEditingController(text: '1');
    final toCtrl = TextEditingController(text: '$total');
    return showDialog<(int, int)>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161A22),
        title: const Text('Intervallo pagine',
            style: TextStyle(color: Colors.white)),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: fromCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Da'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: toCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'A'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annulla')),
          ElevatedButton(
            onPressed: () {
              final f = int.tryParse(fromCtrl.text) ?? 1;
              final t = int.tryParse(toCtrl.text) ?? total;
              Navigator.pop(ctx, (f, t));
            },
            child: const Text('Estrai'),
          ),
        ],
      ),
    );
  }

  // --------------------- RIORDINO PAGINE ---------------------

  Future<void> _reorderPages() async {
    String? path = widget.initialPdfPath;
    if (path == null) {
      final r = await FilePicker.platform.pickFiles(
          type: FileType.custom, allowedExtensions: ['pdf']);
      if (r == null || r.files.single.path == null) return;
      path = r.files.single.path!;
    }

    int total;
    try {
      total = await PdfOpsService.pageCount(path);
    } catch (e) {
      await _snack('Impossibile leggere il PDF: $e');
      return;
    }
    if (total < 2) {
      await _snack('Il PDF ha una sola pagina: niente da riordinare');
      return;
    }

    // Ordine iniziale 1..total
    final order = List<int>.generate(total, (i) => i + 1);
    final result = await showDialog<List<int>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: const Color(0xFF161A22),
          title: Text('Riordina le $total pagine',
              style: GoogleFonts.jetBrainsMono(
                  color: Colors.white, fontSize: 15)),
          content: SizedBox(
            width: double.maxFinite,
            height: 380,
            child: ReorderableListView(
              onReorder: (oldI, newI) {
                setLocal(() {
                  if (newI > oldI) newI--;
                  final it = order.removeAt(oldI);
                  order.insert(newI, it);
                });
              },
              children: [
                for (int i = 0; i < order.length; i++)
                  ListTile(
                    key: ValueKey('pg_${order[i]}'),
                    dense: true,
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: const Color(0x26FF5A3C),
                      child: Text('${i + 1}',
                          style: const TextStyle(
                              color: Color(0xFFFF5A3C),
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ),
                    title: Text('Pagina originale ${order[i]}',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13)),
                    trailing: const Icon(Icons.drag_handle,
                        color: Color(0xFF5D6580)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annulla')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, order),
                child: const Text('Salva ordine')),
          ],
        ),
      ),
    );
    if (result == null) return;

    _setBusy(true, 'Applicazione nuovo ordine pagine...');
    try {
      final bytes = await PdfOpsService.reorderPages(path, result);
      _setBusy(false);
      final saved = await SaveService.saveWithDialog(
          bytes, 'riordinato_${DateTime.now().millisecondsSinceEpoch}.pdf');
      if (saved != null) await _snack('PDF riordinato salvato: $saved');
    } catch (e) {
      _setBusy(false);
      await _snack('Errore riordino: $e');
    }
  }

  // --------------------- STAMPA (selettiva) ---------------------

  Future<void> _printPages() async {
    String? path = widget.initialPdfPath;
    if (path == null) {
      final r = await FilePicker.platform.pickFiles(
          type: FileType.custom, allowedExtensions: ['pdf']);
      if (r == null || r.files.single.path == null) return;
      path = r.files.single.path!;
    }

    int total;
    try {
      total = await PdfOpsService.pageCount(path);
    } catch (e) {
      await _snack('Impossibile leggere il PDF: $e');
      return;
    }

    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: const Color(0xFF161A22),
        title: Text('Stampa ($total pagine)',
            style: GoogleFonts.jetBrainsMono(
                color: Colors.white, fontSize: 15)),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'all'),
            child: const Text('Stampa tutte le pagine',
                style: TextStyle(color: Colors.white)),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'range'),
            child: const Text(
                'Stampa pagine selezionate (es. 1-3, 5, 8-10)',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (choice == null) return;

    List<int>? pages;
    if (choice == 'range') {
      final input = await _pageRangeInputDialog(total);
      if (input == null) return;
      try {
        pages = PdfOpsService.parsePageRanges(input, total);
      } on FormatException catch (e) {
        await _snack('Intervallo non valido: ${e.message}');
        return;
      }
    }

    _setBusy(true, 'Preparazione stampa...');
    try {
      final Uint8List bytes;
      if (pages == null) {
        // tutte le pagine: stampiamo il file cosi' com'e'
        bytes = await File(path).readAsBytes();
      } else {
        bytes = await PdfOpsService.extractPages(path, pages);
      }
      _setBusy(false);
      await PrintShareService.printPdf(
        bytes,
        name: path.split(Platform.pathSeparator).last.replaceAll('.pdf', ''),
      );
    } catch (e) {
      _setBusy(false);
      await _snack('Errore stampa: $e');
    }
  }

  Future<String?> _pageRangeInputDialog(int total) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161A22),
        title: const Text('Pagine da stampare',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Documento di $total pagine.\nEsempi: "1-3, 5, 8-10" oppure "2" oppure "1-$total".',
              style: GoogleFonts.inter(
                  color: const Color(0xFF8B94A8),
                  fontSize: 12,
                  height: 1.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                  hintText: 'es. 1-3, 5, 8-10'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annulla')),
          ElevatedButton(
              onPressed: () =>
                  Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Stampa')),
        ],
      ),
    );
  }

  // --------------------- CONVERSIONI ---------------------

  Future<void> _wordToPdf() async {
    final r = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['docx']);
    if (r == null || r.files.single.path == null) return;
    final path = r.files.single.path!;

    final ok = await _conversionWarning(
        'Word → PDF',
        'La conversione e\' offline e approssimata: vengono mantenuti '
            'testo, paragrafi e formattazione di base. Layout complessi, '
            'caselle di testo, colonne e grafica avanzata potrebbero non '
            'essere riprodotti fedelmente.');
    if (!ok) return;

    _setBusy(true, 'Conversione Word → PDF...');
    try {
      final bytes = await ConversionService.wordToPdf(path);
      _setBusy(false);
      final name = path
              .split(Platform.pathSeparator)
              .last
              .replaceAll('.docx', '') +
          '.pdf';
      final saved = await SaveService.saveWithDialog(bytes, name);
      if (saved != null) await _snack('PDF creato: $saved');
    } catch (e) {
      _setBusy(false);
      await _snack('Errore conversione: $e');
    }
  }

  Future<void> _pdfToWord() async {
    String? path = widget.initialPdfPath;
    if (path == null) {
      final r = await FilePicker.platform.pickFiles(
          type: FileType.custom, allowedExtensions: ['pdf']);
      if (r == null || r.files.single.path == null) return;
      path = r.files.single.path!;
    }

    final ok = await _conversionWarning(
        'PDF → Word',
        'Viene estratto il TESTO del PDF in un documento .docx '
            'modificabile. Non vengono ricostruiti layout esatto, '
            'tabelle, immagini e font originali. Utile per riutilizzare '
            'il contenuto testuale.');
    if (!ok) return;

    _setBusy(true, 'Estrazione testo PDF → Word...');
    try {
      final bytes = await ConversionService.pdfToWord(path);
      _setBusy(false);
      final name = path
              .split(Platform.pathSeparator)
              .last
              .replaceAll('.pdf', '') +
          '.docx';
      final saved = await SaveService.saveWithDialog(
          bytes, name,
          extension: 'docx');
      if (saved != null) await _snack('Word creato: $saved');
    } catch (e) {
      _setBusy(false);
      await _snack('Errore conversione: $e');
    }
  }

  Future<bool> _conversionWarning(String title, String body) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161A22),
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: Color(0xFFEAB308)),
            const SizedBox(width: 8),
            Text(title,
                style: GoogleFonts.jetBrainsMono(
                    color: Colors.white, fontSize: 15)),
          ],
        ),
        content: Text(body,
            style: GoogleFonts.inter(
                color: const Color(0xFFC7CEDB),
                fontSize: 13,
                height: 1.5)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Procedi')),
        ],
      ),
    );
    return r ?? false;
  }

  // --------------------- UI ---------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1014),
      appBar: AppBar(title: const Text('Strumenti file')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _section('UNIONE & DIVISIONE'),
              _opCard(
                icon: Icons.merge_type,
                title: 'Unisci PDF',
                subtitle:
                    'Combina piu\' PDF in un unico documento, nell\'ordine scelto',
                onTap: _busy ? null : _mergePdfs,
              ),
              _opCard(
                icon: Icons.call_split,
                title: 'Dividi PDF',
                subtitle:
                    'Estrai un intervallo di pagine o separa pagina per pagina',
                onTap: _busy ? null : _splitPdf,
              ),
              _opCard(
                icon: Icons.swap_vert,
                title: 'Riordina pagine',
                subtitle:
                    'Cambia l\'ordine delle pagine trascinandole, poi salva',
                onTap: _busy ? null : _reorderPages,
              ),
              const SizedBox(height: 20),
              _section('STAMPA'),
              _opCard(
                icon: Icons.print,
                title: 'Stampa documento',
                subtitle:
                    'Stampa tutto o pagine scelte (es. 1-3, 5, 8-10) su stampante rilevata',
                onTap: _busy ? null : _printPages,
              ),
              const SizedBox(height: 20),
              _section('CONVERSIONE DOCUMENTI'),
              _opCard(
                icon: Icons.picture_as_pdf,
                title: 'Word → PDF',
                subtitle: 'Converti un documento .docx in PDF (offline)',
                onTap: _busy ? null : _wordToPdf,
              ),
              _opCard(
                icon: Icons.description_outlined,
                title: 'PDF → Word',
                subtitle:
                    'Estrai il testo del PDF in un documento .docx modificabile',
                onTap: _busy ? null : _pdfToWord,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF161A22),
                  border: Border.all(color: const Color(0xFF2A3142)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined,
                        size: 18, color: Color(0xFF5D6580)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tutte le operazioni avvengono in locale sul dispositivo. Nessun file viene inviato online.',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF8B94A8),
                            height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_busy)
            Container(
              color: Colors.black.withOpacity(0.6),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                        color: Color(0xFFFF5A3C)),
                    const SizedBox(height: 16),
                    Text(_status,
                        style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 4),
        child: Text(t,
            style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: const Color(0xFF5D6580),
                letterSpacing: 1.8)),
      );

  Widget _opCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return Card(
      color: const Color(0xFF161A22),
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFF2A3142)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0x26FF5A3C),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFFFF5A3C)),
        ),
        title: Text(title,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle,
            style: GoogleFonts.inter(
                color: const Color(0xFF8B94A8), fontSize: 12)),
        trailing:
            const Icon(Icons.chevron_right, color: Color(0xFF5D6580)),
      ),
    );
  }
}
