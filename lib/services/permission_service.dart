import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Richiede tutti i permessi necessari all'avvio dell'app.
  static Future<void> requestAll() async {
    final toRequest = <Permission>[
      Permission.storage,
      Permission.photos,
      Permission.manageExternalStorage,
    ];
    for (final p in toRequest) {
      try {
        final status = await p.status;
        if (!status.isGranted) {
          await p.request();
        }
      } catch (_) {}
    }
  }

  /// Compatibilita': richiede solo lo storage.
  static Future<void> requestStorage() async {
    try {
      final s = await Permission.storage.status;
      if (!s.isGranted) await Permission.storage.request();
    } catch (_) {}
  }
}
