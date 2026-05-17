import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/annotation_models.dart';

class EditorToolbar extends StatelessWidget {
  final AnnotationTool currentTool;
  final Color currentColor;
  final double strokeWidth;
  final double opacity;
  final ValueChanged<AnnotationTool> onToolChanged;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<double> onStrokeChanged;
  final ValueChanged<double> onOpacityChanged;

  const EditorToolbar({
    super.key,
    required this.currentTool,
    required this.currentColor,
    required this.strokeWidth,
    required this.opacity,
    required this.onToolChanged,
    required this.onColorChanged,
    required this.onStrokeChanged,
    required this.onOpacityChanged,
  });

  static const _palette = [
    Color(0xFFFF5A3C),
    Color(0xFF000000),
    Color(0xFFFFFFFF),
    Color(0xFFEAB308),
    Color(0xFF22C55E),
    Color(0xFF3B82F6),
    Color(0xFFA855F7),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: Color(0xFF161A22),
        border: Border(bottom: BorderSide(color: Color(0xFF2A3142))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            // Selezione / penna / evidenziatore / gomma
            _toolGroup([
              _toolBtn(AnnotationTool.select),
              _toolBtn(AnnotationTool.pen),
              _toolBtn(AnnotationTool.highlight),
              _toolBtn(AnnotationTool.eraser),
            ]),
            // Testo, checkbox, firma
            _toolGroup([
              _toolBtn(AnnotationTool.text),
              _toolBtn(AnnotationTool.checkmark),
              _toolBtn(AnnotationTool.signature),
            ]),
            // Forme
            _toolGroup([
              _toolBtn(AnnotationTool.rect),
              _toolBtn(AnnotationTool.circle),
              _toolBtn(AnnotationTool.line),
              _toolBtn(AnnotationTool.arrow),
              _toolBtn(AnnotationTool.image),
            ]),
            // Colori
            _toolGroup([
              ..._palette.map((c) => _colorSwatch(c)),
              _customColorBtn(context),
            ]),
            // Sliders
            _toolGroup([
              _slider('SPESS', strokeWidth, 1, 30, '${strokeWidth.toInt()}px', onStrokeChanged),
              _slider('OPAC', opacity * 100, 10, 100, '${(opacity * 100).toInt()}%', (v) => onOpacityChanged(v / 100)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _toolGroup(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: Color(0xFF2A3142))),
      ),
      child: Row(children: children),
    );
  }

  Widget _toolBtn(AnnotationTool tool) {
    final active = currentTool == tool;
    return Tooltip(
      message: tool.label,
      child: InkWell(
        onTap: () => onToolChanged(tool),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 36,
          height: 36,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: active ? const Color(0x26FF5A3C) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: active ? const Color(0xFFFF5A3C) : Colors.transparent,
            ),
          ),
          child: Icon(
            tool.icon,
            size: 18,
            color: active ? const Color(0xFFFF5A3C) : const Color(0xFF8B94A8),
          ),
        ),
      ),
    );
  }

  Widget _colorSwatch(Color color) {
    final active = currentColor.value == color.value;
    return GestureDetector(
      onTap: () => onColorChanged(color),
      child: Container(
        width: 24,
        height: 24,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: active ? Colors.white : const Color(0xFF3A4256),
            width: 2,
          ),
          boxShadow: active
              ? [
                  const BoxShadow(
                    color: Color(0xFFFF5A3C),
                    blurRadius: 0,
                    spreadRadius: 2,
                  )
                ]
              : null,
        ),
      ),
    );
  }

  Widget _customColorBtn(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        Color tmp = currentColor;
        final picked = await showDialog<Color>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF161A22),
            title: Text('Colore personalizzato', style: GoogleFonts.jetBrainsMono()),
            content: SingleChildScrollView(
              child: ColorPicker(
                pickerColor: currentColor,
                onColorChanged: (c) => tmp = c,
                enableAlpha: true,
                hexInputBar: true,
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
              TextButton(onPressed: () => Navigator.pop(context, tmp), child: const Text('OK')),
            ],
          ),
        );
        if (picked != null) onColorChanged(picked);
      },
      child: Container(
        width: 24,
        height: 24,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const SweepGradient(
            colors: [Colors.red, Colors.yellow, Colors.green, Colors.blue, Colors.purple, Colors.red],
          ),
          border: Border.all(color: const Color(0xFF3A4256), width: 2),
        ),
      ),
    );
  }

  Widget _slider(String label, double value, double min, double max, String text, ValueChanged<double> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              color: const Color(0xFF5D6580),
              letterSpacing: 1.5,
            ),
          ),
          SizedBox(
            width: 80,
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: const Color(0xFFFF5A3C),
                inactiveTrackColor: const Color(0xFF2A3142),
                thumbColor: const Color(0xFFFF5A3C),
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              text,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: const Color(0xFFE8ECF3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
