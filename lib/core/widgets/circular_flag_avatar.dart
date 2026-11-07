import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Clean circular flag avatar widget reproducing the circular flags in the reference.
class CircularFlagAvatar extends StatelessWidget {
  final String languageCode;
  final double size;

  const CircularFlagAvatar({
    super.key,
    required this.languageCode,
    this.size = 28.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.borderLight, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: ClipOval(
        child: CustomPaint(
          size: Size(size, size),
          painter: _FlagPainter(languageCode),
        ),
      ),
    );
  }
}

class _FlagPainter extends CustomPainter {
  final String code;
  _FlagPainter(this.code);

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    if (code == 'en') {
      // UK Flag representation (Union Jack motif)
      final Paint blue = Paint()..color = const Color(0xFF012169);
      final Paint white = Paint()..color = Colors.white;
      final Paint red = Paint()..color = const Color(0xFFC8102E);

      canvas.drawRect(Rect.fromLTWH(0, 0, w, h), blue);

      // Diagonal cross
      final Paint whiteDiag = Paint()
        ..color = Colors.white
        ..strokeWidth = w * 0.22;
      canvas.drawLine(Offset(0, 0), Offset(w, h), whiteDiag);
      canvas.drawLine(Offset(w, 0), Offset(0, h), whiteDiag);

      final Paint redDiag = Paint()
        ..color = const Color(0xFFC8102E)
        ..strokeWidth = w * 0.12;
      canvas.drawLine(Offset(0, 0), Offset(w, h), redDiag);
      canvas.drawLine(Offset(w, 0), Offset(0, h), redDiag);

      // Straight cross
      final Paint whiteCross = Paint()
        ..color = Colors.white
        ..strokeWidth = w * 0.32;
      canvas.drawLine(Offset(w / 2, 0), Offset(w / 2, h), whiteCross);
      canvas.drawLine(Offset(0, h / 2), Offset(w, h / 2), whiteCross);

      final Paint redCross = Paint()
        ..color = const Color(0xFFC8102E)
        ..strokeWidth = w * 0.20;
      canvas.drawLine(Offset(w / 2, 0), Offset(w / 2, h), redCross);
      canvas.drawLine(Offset(0, h / 2), Offset(w, h / 2), redCross);
    } else {
      // Indian Tricolor (Telugu, Hindi, Tamil, Kannada, Malayalam, Bengali)
      final Paint saffron = Paint()..color = const Color(0xFFFF9933);
      final Paint white = Paint()..color = Colors.white;
      final Paint green = Paint()..color = const Color(0xFF138808);
      final Paint navy = Paint()..color = const Color(0xFF000080);

      final double bandH = h / 3;
      canvas.drawRect(Rect.fromLTWH(0, 0, w, bandH), saffron);
      canvas.drawRect(Rect.fromLTWH(0, bandH, w, bandH), white);
      canvas.drawRect(Rect.fromLTWH(0, bandH * 2, w, bandH), green);

      // Ashoka Chakra center circle
      canvas.drawCircle(Offset(w / 2, h / 2), bandH * 0.38, navy..style = PaintingStyle.stroke..strokeWidth = 1.0);
      canvas.drawCircle(Offset(w / 2, h / 2), 1.5, navy..style = PaintingStyle.fill);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
