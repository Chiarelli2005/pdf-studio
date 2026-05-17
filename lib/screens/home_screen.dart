import 'package:flutter/material.dart';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/permission_service.dart';
import 'editor_screen.dart';
import 'file_ops_screen.dart';
import 'about_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = false;
  StreamSubscription<List<SharedMediaFile>>? _intentSub;

  @override
  void initState() {
    super.initState();
    _initSharingListener();
  }

  @override
  void dispose() {
    _intentSub?.cancel();
    super.dispose();
  }

  void _openFromPath(String path, {bool readOnly = false}) {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) =>
              EditorScreen(filePath: path, readOnly: readOnly)),
    );
  }

  Future<void> _initSharingListener() async {
    // PDF ricevuto mentre l'app e' gia' aperta -> SOLA LETTURA:
    // l'utente ha scelto "Apri con PDF Studio" da un'altra app, quindi
    // si aspetta di visualizzare, non un editor pieno di strumenti.
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (files) {
        if (files.isNotEmpty) {
          _openFromPath(files.first.path, readOnly: true);
        }
      },
      onError: (_) {},
    );
    // PDF che ha avviato l'app (tap da WhatsApp con app chiusa) -> SOLA LETTURA
    try {
      final initial =
          await ReceiveSharingIntent.instance.getInitialMedia();
      if (initial.isNotEmpty) {
        _openFromPath(initial.first.path, readOnly: true);
        ReceiveSharingIntent.instance.reset();
      }
    } catch (_) {}
  }

  Future<void> _pickPdf() async {
    setState(() => _loading = true);
    try {
      await PermissionService.requestStorage();
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'enc'],
        withData: false,
      );
      if (result == null || result.files.single.path == null) {
        setState(() => _loading = false);
        return;
      }
      final path = result.files.single.path!;
      if (!mounted) return;
      setState(() => _loading = false);
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => EditorScreen(filePath: path)),
      );
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF5A3C).withOpacity(0.4),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  width: 28,
                  height: 28,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text('PDF STUDIO'),
            const SizedBox(width: 8),
            Text(
              '· editor & annotator',
              style: GoogleFonts.jetBrainsMono(
                color: const Color(0xFF5D6580),
                fontSize: 11,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Informazioni',
            icon: const Icon(Icons.info_outline),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.5, -0.5),
                radius: 1.4,
                colors: [Color(0x14FF5A3C), Color(0xFF0E1014)],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  // Empty state
                  Container(
                    width: 80,
                    height: 80,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF161A22),
                      border: Border.all(
                        color: const Color(0xFF3A4256),
                        width: 2,
                        style: BorderStyle.solid,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.picture_as_pdf_outlined,
                      size: 36,
                      color: Color(0xFF5D6580),
                    ),
                  ).withCenter(),
                  const SizedBox(height: 24),
                  Text(
                    'Carica un PDF per iniziare',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.jetBrainsMono(
                      color: const Color(0xFFE8ECF3),
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Apri, modifica e annota PDF.\nFirma digitale, checkbox, testo, forme e cifratura AES-256.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF8B94A8),
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton.icon(
                    onPressed: _loading ? null : _pickPdf,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.folder_open, size: 18),
                    label: Text(_loading ? 'Caricamento...' : 'APRI PDF'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _loading
                        ? null
                        : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const FileOpsScreen()),
                            ),
                    icon: const Icon(Icons.construction, size: 18),
                    label: const Text('STRUMENTI FILE'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE8ECF3),
                      side: const BorderSide(color: Color(0xFF2A3142)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _FeatureList(),
                  const Spacer(),
                  Center(
                    child: Text(
                      'v1.3.0  ·  privacy by design  ·  100% offline',
                      style: GoogleFonts.jetBrainsMono(
                        color: const Color(0xFF5D6580),
                        fontSize: 10,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final features = [
      ('✏️', 'Scrittura a mano libera, pennelli e colori'),
      ('📝', 'Inserimento testo e compilazione moduli'),
      ('☑️', 'Checkbox cliccabili e firma digitale'),
      ('🔒', 'Cifratura AES-256 standard PDF'),
      ('📊', 'Visualizzazione ed editing metadati'),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161A22),
        border: Border.all(color: const Color(0xFF2A3142)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: features
            .map((f) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Text(f.$1, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          f.$2,
                          style: GoogleFonts.inter(
                            color: const Color(0xFFE8ECF3),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}

extension WidgetCenter on Widget {
  Widget withCenter() => Center(child: this);
}
