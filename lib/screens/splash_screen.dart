import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'home_screen.dart';

/// Splash screen mostrato all'avvio. Include la firma d'autore
/// "Giovanni Chiarelli" con effetto vedo-non-vedo (dissolvenza in
/// entrata e in uscita). Dopo l'animazione passa alla HomeScreen.
///
/// La firma appare SOLO qui (e nella schermata Info), MAI sui PDF
/// esportati: i documenti dell'utente restano puliti.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logoCtrl;
  late final AnimationController _sigCtrl;
  late final Animation<double> _logoFade;
  late final Animation<double> _sigFade;

  @override
  void initState() {
    super.initState();

    // Logo: comparsa morbida.
    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoFade = CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut);

    // Firma: effetto "vedo-non-vedo" -> appare lentamente e poi svanisce.
    _sigCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    // 0.0 -> 0.35 : dissolvenza in entrata
    // 0.35 -> 0.65 : tenue, visibile appena
    // 0.65 -> 1.0 : dissolvenza in uscita
    _sigFade = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 0.55)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 35),
      TweenSequenceItem(tween: ConstantTween(0.55), weight: 30),
      TweenSequenceItem(
          tween: Tween(begin: 0.55, end: 0.0)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 35),
    ]).animate(_sigCtrl);

    _start();
  }

  Future<void> _start() async {
    // Se l'app e' stata aperta da un'altra app con un PDF ("Apri con..."),
    // saltiamo l'animazione lunga per non far attendere l'utente: la
    // HomeScreen rilevera' l'intent e aprira' subito il PDF in lettura.
    bool hasIncoming = false;
    try {
      final initial =
          await ReceiveSharingIntent.instance.getInitialMedia();
      hasIncoming = initial.isNotEmpty;
    } catch (_) {}

    if (hasIncoming) {
      await _logoCtrl.forward();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
      return;
    }

    await _logoCtrl.forward();
    await _sigCtrl.forward();
    if (!mounted) return;
    // Passaggio alla home con dissolvenza.
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _sigCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1014),
      body: Stack(
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.3, -0.4),
                radius: 1.4,
                colors: [Color(0x14FF5A3C), Color(0xFF0E1014)],
              ),
            ),
            child: SizedBox.expand(),
          ),
          Center(
            child: FadeTransition(
              opacity: _logoFade,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFFFF5A3C).withOpacity(0.45),
                          blurRadius: 40,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'assets/icon/app_icon.png',
                        width: 96,
                        height: 96,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'PDF STUDIO',
                    style: GoogleFonts.jetBrainsMono(
                      color: const Color(0xFFE8ECF3),
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'editor & annotator',
                    style: GoogleFonts.jetBrainsMono(
                      color: const Color(0xFF5D6580),
                      fontSize: 11,
                      letterSpacing: 3,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Firma d'autore con effetto vedo-non-vedo, in basso.
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 56),
              child: FadeTransition(
                opacity: _sigFade,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'un\'opera di',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF5D6580),
                        fontSize: 10,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Giovanni Chiarelli',
                      style: GoogleFonts.jetBrainsMono(
                        color: const Color(0xFFE8ECF3),
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
