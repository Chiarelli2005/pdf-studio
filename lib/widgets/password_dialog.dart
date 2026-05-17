import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PasswordDialog extends StatefulWidget {
  final String reason;
  const PasswordDialog({super.key, this.reason = ''});

  @override
  State<PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<PasswordDialog> {
  final _ctrl = TextEditingController();
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF161A22),
      title: Row(
        children: [
          const Icon(Icons.lock, color: Color(0xFFFF5A3C)),
          const SizedBox(width: 8),
          Text('PDF protetto', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w700)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.reason.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(widget.reason, style: const TextStyle(fontSize: 13, color: Color(0xFF8B94A8))),
            ),
          TextField(
            controller: _ctrl,
            autofocus: true,
            obscureText: _obscured,
            onSubmitted: (v) => Navigator.pop(context, v),
            decoration: InputDecoration(
              labelText: 'Password',
              suffixIcon: IconButton(
                icon: Icon(_obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18),
                onPressed: () => setState(() => _obscured = !_obscured),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _ctrl.text),
          child: const Text('Sblocca'),
        ),
      ],
    );
  }
}

class ExportSecureDialog extends StatefulWidget {
  const ExportSecureDialog({super.key});

  @override
  State<ExportSecureDialog> createState() => _ExportSecureDialogState();
}

class _ExportSecureDialogState extends State<ExportSecureDialog> {
  final _pwd1 = TextEditingController();
  final _pwd2 = TextEditingController();
  bool _print = true, _copy = true, _modify = true;
  String? _error;
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF161A22),
      title: Row(
        children: [
          const Icon(Icons.lock_outline, color: Color(0xFFFF5A3C)),
          const SizedBox(width: 8),
          Text('Esporta PDF protetto', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w700)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0x26FF5A3C),
                border: Border.all(color: const Color(0xFFFF5A3C)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Cifratura AES-256 standard PDF.\nIl file sarà apribile con qualsiasi lettore (Acrobat, Preview, browser) richiedendo la password.',
                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFE8ECF3), height: 1.5),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pwd1,
              obscureText: _obscured,
              decoration: InputDecoration(
                labelText: 'Password apertura',
                suffixIcon: IconButton(
                  icon: Icon(_obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18),
                  onPressed: () => setState(() => _obscured = !_obscured),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _pwd2,
              obscureText: _obscured,
              decoration: const InputDecoration(labelText: 'Conferma password'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Color(0xFFF87171), fontSize: 12)),
            ],
            const SizedBox(height: 16),
            Text(
              'PERMESSI',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                color: const Color(0xFF5D6580),
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 6),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: _print,
              onChanged: (v) => setState(() => _print = v ?? true),
              activeColor: const Color(0xFFFF5A3C),
              title: const Text('Consenti stampa', style: TextStyle(fontSize: 13)),
            ),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: _copy,
              onChanged: (v) => setState(() => _copy = v ?? true),
              activeColor: const Color(0xFFFF5A3C),
              title: const Text('Consenti copia testo', style: TextStyle(fontSize: 13)),
            ),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: _modify,
              onChanged: (v) => setState(() => _modify = v ?? true),
              activeColor: const Color(0xFFFF5A3C),
              title: const Text('Consenti modifica', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
        ElevatedButton.icon(
          icon: const Icon(Icons.lock, size: 16),
          onPressed: () {
            if (_pwd1.text.isEmpty) {
              setState(() => _error = 'Inserisci una password');
              return;
            }
            if (_pwd1.text != _pwd2.text) {
              setState(() => _error = 'Le password non coincidono');
              return;
            }
            if (_pwd1.text.length < 4) {
              setState(() => _error = 'Password troppo corta (min 4 caratteri)');
              return;
            }
            Navigator.pop(context, {
              'password': _pwd1.text,
              'permissions': {
                'print': _print,
                'copy': _copy,
                'modify': _modify,
              },
            });
          },
          label: const Text('Esporta'),
        ),
      ],
    );
  }
}
