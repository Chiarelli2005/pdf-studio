import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

class SaveService {
  /// Cartella stabile dell'app (per output intermedi come lo split).
  static Future<Directory> appDir() => getApplicationDocumentsDirectory();

  /// Salva i bytes chiedendo all'utente nome e posizione.
  /// Ritorna il path salvato, o null se annullato.
  ///
  /// [extension] permette di salvare anche file non-PDF (es. 'docx').
  static Future<String?> saveWithDialog(
    Uint8List bytes,
    String suggestedName, {
    String extension = 'pdf',
  }) async {
    try {
      // Su Android file_picker saveFile spesso ritorna solo il path:
      // scriviamo noi i bytes per sicurezza.
      String? path = await FilePicker.platform.saveFile(
        dialogTitle: 'Salva file',
        fileName: suggestedName,
        type: FileType.custom,
        allowedExtensions: [extension],
        bytes: bytes,
      );

      if (path == null) return null;

      final f = File(path);
      if (!await f.exists() || (await f.length()) == 0) {
        await f.writeAsBytes(bytes);
      }
      return path;
    } catch (e) {
      // Fallback: salva nella cartella Documenti dell'app.
      final dir = await getApplicationDocumentsDirectory();
      final fallback = '${dir.path}/$suggestedName';
      await File(fallback).writeAsBytes(bytes);
      return fallback;
    }
  }
}
