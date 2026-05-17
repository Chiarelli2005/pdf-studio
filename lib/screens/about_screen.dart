import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Schermata informazioni con la firma d'autore "Giovanni Chiarelli"
/// (effetto vedo-non-vedo: la firma pulsa lentamente di opacita').
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    // Effetto vedo-non-vedo: opacita' oscilla tra 0.25 e 1.0.
    _pulse = Tween<double>(begin: 0.25, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1014),
      appBar: AppBar(title: const Text('Informazioni')),
      body: Stack(
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.4, -0.5),
                radius: 1.4,
                colors: [Color(0x14FF5A3C), Color(0xFF0E1014)],
              ),
            ),
            child: SizedBox.expand(),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 28, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(),
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFFFF5A3C).withOpacity(0.4),
                          blurRadius: 30,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.asset(
                        'assets/icon/app_icon.png',
                        width: 84,
                        height: 84,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('PDF STUDIO',
                      style: GoogleFonts.jetBrainsMono(
                        color: const Color(0xFFE8ECF3),
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                        letterSpacing: 2,
                      )),
                  const SizedBox(height: 6),
                  Text('versione 1.3.0',
                      style: GoogleFonts.jetBrainsMono(
                        color: const Color(0xFF5D6580),
                        fontSize: 12,
                        letterSpacing: 1.5,
                      )),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161A22),
                      border:
                          Border.all(color: const Color(0xFF2A3142)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Editor, annotatore e compilatore PDF.\n'
                      '100% offline · privacy by design.\n'
                      'Nessun dato lascia il tuo dispositivo.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF8B94A8),
                        fontSize: 13,
                        height: 1.6,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Firma d'autore con effetto vedo-non-vedo (pulsazione).
                  FadeTransition(
                    opacity: _pulse,
                    child: Column(
                      children: [
                        Text('ideato e sviluppato da',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF5D6580),
                              fontSize: 10,
                              letterSpacing: 2,
                            )),
                        const SizedBox(height: 8),
                        Text('Giovanni Chiarelli',
                            style: GoogleFonts.jetBrainsMono(
                              color: const Color(0xFFE8ECF3),
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
