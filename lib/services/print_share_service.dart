import 'dart:typed_data';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

/// Stampa e condivisione documenti.
///
/// NOTA SUL RILEVAMENTO STAMPANTI (Android):
/// Su Android il discovery delle stampanti e' gestito dal FRAMEWORK DI
/// STAMPA NATIVO del sistema operativo. Quando si chiama
/// Printing.layoutPdf(), Android apre il proprio dialog di stampa che
/// rileva e mostra automaticamente tutte le stampanti disponibili:
/// - stampanti WiFi / di rete
/// - stampanti cloud configurate
/// - stampanti USB compatibili
/// - servizi di stampa installati (es. plugin produttore HP/Epson/Canon)
/// - l'opzione "Salva come PDF"
///
/// Per questo NON usiamo Printing.listPrinters() (che su Android lancia
/// MissingPluginException: l'enumerazione manuale non e' supportata, ed
/// e' una scelta di design di Android per motivi di sicurezza/driver).
class PrintShareService {
  /// Apre il dialog di stampa nativo Android con i bytes PDF forniti.
  /// L'utente sceglie la stampante (rilevate automaticamente dal sistema),
  /// numero di copie, orientamento, pagine, ecc.
  /// Ritorna true se l'utente ha confermato la stampa.
  static Future<bool> printPdf(
    Uint8List bytes, {
    String name = 'documento',
  }) async {
    return Printing.layoutPdf(
      onLayout: (format) async => bytes,
      name: name,
    );
  }

  /// Condivide il PDF con altre app (email, messaggistica, cloud, ecc.)
  /// tramite il foglio di condivisione nativo Android.
  static Future<void> sharePdfBytes(
    Uint8List bytes, {
    String filename = 'documento.pdf',
  }) async {
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }

  /// Condivide un file gia' su disco (qualsiasi tipo: pdf, docx, ...)
  /// usando share_plus, con testo opzionale di accompagnamento.
  static Future<void> shareFile(
    String filePath, {
    String? text,
  }) async {
    await Share.shareXFiles(
      [XFile(filePath)],
      text: text,
    );
  }
}
