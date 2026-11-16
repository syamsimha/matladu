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

      canvas.drawRect(Rect.fromLTWH(0, 0, w, h), blue);

      // Diagonal cross
      final Paint whiteDiag = Paint()
        ..color = Colors.white
        ..strokeWidth = w * 0.22;
      canvas.drawLine(const Offset(0, 0), Offset(w, h), whiteDiag);
      canvas.drawLine(Offset(w, 0), Offset(0, h), whiteDiag);

      final Paint redDiag = Paint()
        ..color = const Color(0xFFC8102E)
        ..strokeWidth = w * 0.12;
      canvas.drawLine(const Offset(0, 0), Offset(w, h), redDiag);
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
    } else if (code == 'kn') {
      // Karnataka / Kannada Flag (Yellow top, Red bottom)
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h / 2), Paint()..color = const Color(0xFFFFD700));
      canvas.drawRect(Rect.fromLTWH(0, h / 2, w, h / 2), Paint()..color = const Color(0xFFDC2626));
    } else if (code == 'bn') {
      // Bengali Flag (Green background with Red circular sun)
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xFF006A4E));
      canvas.drawCircle(Offset(w * 0.45, h * 0.5), w * 0.28, Paint()..color = const Color(0xFFF42A41));
    } else if (code == 'ta') {
      // Tamil Flag representation in reference (Green, Yellow, Red horizontal stripes)
      final double bandH = h / 3;
      canvas.drawRect(Rect.fromLTWH(0, 0, w, bandH), Paint()..color = const Color(0xFF15803D));
      canvas.drawRect(Rect.fromLTWH(0, bandH, w, bandH), Paint()..color = const Color(0xFFFBBF24));
      canvas.drawRect(Rect.fromLTWH(0, bandH * 2, w, bandH), Paint()..color = const Color(0xFFDC2626));
    } else if (code == 'ml') {
      // Malayalam Flag representation in reference (Cyan, White, Green)
      final double bandH = h / 3;
      canvas.drawRect(Rect.fromLTWH(0, 0, w, bandH), Paint()..color = const Color(0xFF0284C7));
      canvas.drawRect(Rect.fromLTWH(0, bandH, w, bandH), Paint()..color = Colors.white);
      canvas.drawRect(Rect.fromLTWH(0, bandH * 2, w, bandH), Paint()..color = const Color(0xFF16A34A));
    } else if (code == 'es') {
      // Spanish Flag (Red, Yellow double-width, Red)
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h * 0.25), Paint()..color = const Color(0xFFAA151B));
      canvas.drawRect(Rect.fromLTWH(0, h * 0.25, w, h * 0.50), Paint()..color = const Color(0xFFF1BF00));
      canvas.drawRect(Rect.fromLTWH(0, h * 0.75, w, h * 0.25), Paint()..color = const Color(0xFFAA151B));
    } else if (code == 'fr') {
      // French Tricolor (Blue, White, Red vertical bands)
      final double bandW = w / 3;
      canvas.drawRect(Rect.fromLTWH(0, 0, bandW, h), Paint()..color = const Color(0xFF0055A4));
      canvas.drawRect(Rect.fromLTWH(bandW, 0, bandW, h), Paint()..color = Colors.white);
      canvas.drawRect(Rect.fromLTWH(bandW * 2, 0, bandW, h), Paint()..color = const Color(0xFFEF4135));
    } else if (code == 'de') {
      // German Flag (Black, Red, Gold horizontal stripes)
      final double bandH = h / 3;
      canvas.drawRect(Rect.fromLTWH(0, 0, w, bandH), Paint()..color = const Color(0xFF000000));
      canvas.drawRect(Rect.fromLTWH(0, bandH, w, bandH), Paint()..color = const Color(0xFFFF0000));
      canvas.drawRect(Rect.fromLTWH(0, bandH * 2, w, bandH), Paint()..color = const Color(0xFFFFCC00));
    } else {
      // Indian Tricolor (Telugu, Hindi, default)
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
  bool shouldRepaint(covariant _FlagPainter oldDelegate) => oldDelegate.code != code;
}

