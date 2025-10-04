import 'package:flutter/material.dart';
import '../services/audio_api_service.dart';

class WaveformWidget extends StatelessWidget {
  final WaveformData waveformData;
  final Color waveColor;
  final Color backgroundColor;
  final double height;

  const WaveformWidget({
    Key? key,
    required this.waveformData,
    this.waveColor = const Color(0xFF667EEA),
    this.backgroundColor = Colors.transparent,
    this.height = 80,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: CustomPaint(
        size: Size(double.infinity, height),
        painter: WaveformPainter(waveformData: waveformData, color: waveColor),
      ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  final WaveformData waveformData;
  final Color color;

  WaveformPainter({required this.waveformData, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (waveformData.waveform.isEmpty) return;

    // 1. Najpierw rysuj waveform
    _drawWaveform(canvas, size);

    // 2. Następnie rysuj markery czasowe (żółte kropki/kreski)
    _drawTimeMarkers(canvas, size);
  }

  void _drawWaveform(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.fill;

    final middle = size.height / 2;
    final step = size.width / waveformData.waveform.length;

    // Rysuj symetryczną falę (góra i dół)
    for (var i = 0; i < waveformData.waveform.length; i++) {
      final x = i * step;
      final amplitude =
          (waveformData.waveform[i] / 255.0) * (size.height * 0.45);

      // Linia od środka w górę
      canvas.drawLine(Offset(x, middle), Offset(x, middle - amplitude), paint);

      // Linia od środka w dół (symetria)
      canvas.drawLine(Offset(x, middle), Offset(x, middle + amplitude), paint);
    }
  }

  void _drawTimeMarkers(Canvas canvas, Size size) {
    for (var marker in waveformData.markers) {
      // Oblicz pozycję X na podstawie czasu
      final xPosition =
          (marker.timeInSeconds / waveformData.duration) * size.width;

      // Rysuj pionową kreskę (żółtą lub w kolorze markera)
      final linePaint = Paint()
        ..color = marker.color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;

      canvas.drawLine(
        Offset(xPosition, 0),
        Offset(xPosition, size.height),
        linePaint,
      );

      // Rysuj kropkę na górze
      final dotPaint = Paint()
        ..color = marker.color
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(xPosition, 0), 5, dotPaint);

      // Rysuj kropkę na dole
      canvas.drawCircle(Offset(xPosition, size.height), 5, dotPaint);

      // Rysuj label czasu (opcjonalnie)
      if (marker.label.isNotEmpty) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: marker.label,
            style: TextStyle(
              color: marker.color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.5),
                  offset: Offset(1, 1),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
          textDirection: TextDirection.ltr,
        );

        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(xPosition - textPainter.width / 2, -18),
        );
      }
    }
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return oldDelegate.waveformData != waveformData ||
        oldDelegate.color != color;
  }
}
