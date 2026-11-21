import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../logic.dart';
import 'widgets.dart';

/// عنوان «صدقة جارية» بخط الرقعة (صورة مضمّنة)
final Uint8List dedTitlePng = base64Decode('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');

/// نقش النجمة الثمانية (يُرسم بالكود)
class StarPatternPainter extends CustomPainter {
  final Color color;
  final double cell;
  const StarPatternPainter({required this.color, this.cell = 60});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (double y = 0; y < size.height + cell; y += cell) {
      for (double x = 0; x < size.width + cell; x += cell) {
        final cx = x + cell / 2, cy = y + cell / 2, r = cell * 0.37;
        final path = Path();
        for (var k = 0; k < 16; k++) {
          final a = math.pi / 8 * k - math.pi / 2;
          final rr = k.isEven ? r : r * 0.62;
          final pt = Offset(cx + rr * math.cos(a), cy + rr * math.sin(a));
          k == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
        }
        path.close();
        canvas.drawPath(path, p);
        final d = cell * 0.2;
        canvas.drawLine(Offset(x, y), Offset(x + d, y + d), p);
        canvas.drawLine(Offset(x + cell, y), Offset(x + cell - d, y + d), p);
        canvas.drawLine(Offset(x, y + cell), Offset(x + d, y + cell - d), p);
        canvas.drawLine(Offset(x + cell, y + cell), Offset(x + cell - d, y + cell - d), p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant StarPatternPainter old) => old.color != color;
}

/// رسمة مسجد بخطوط ذهبية (شاشة الدخول)
class MosquePainter extends CustomPainter {
  const MosquePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 300, sy = size.height / 150;
    canvas.save();
    canvas.scale(sx, sy);
    final p = Paint()
      ..color = const Color(0x99E3B21B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 / ((sx + sy) / 2)
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(40, 150)
      ..lineTo(40, 95)
      ..lineTo(260, 95)
      ..lineTo(260, 150)
      ..moveTo(95, 95)
      ..quadraticBezierTo(95, 40, 150, 30)
      ..quadraticBezierTo(205, 40, 205, 95)
      ..moveTo(150, 30)
      ..lineTo(150, 16)
      // المئذنتان
      ..moveTo(18, 150)
      ..lineTo(18, 55)
      ..moveTo(28, 150)
      ..lineTo(28, 55)
      ..moveTo(12, 47)
      ..lineTo(34, 47)
      ..lineTo(23, 58)
      ..close()
      ..moveTo(272, 150)
      ..lineTo(272, 55)
      ..moveTo(282, 150)
      ..lineTo(282, 55)
      ..moveTo(266, 47)
      ..lineTo(288, 47)
      ..lineTo(277, 58)
      ..close();
    // الأبواب
    void arch(double x, double w, double top) {
      path
        ..moveTo(x, 150)
        ..lineTo(x, top + w / 2)
        ..arcToPoint(Offset(x + w, top + w / 2), radius: Radius.circular(w / 2))
        ..lineTo(x + w, 150);
    }

    arch(120, 30, 104);
    arch(150, 30, 104);
    arch(60, 20, 110);
    arch(220, 20, 110);
    canvas.drawPath(path, p);
    canvas.drawCircle(const Offset(150, 12), 3, Paint()..color = const Color(0x99E3B21B));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// قوس المحراب خلف نموذج الدخول
class MihrabPainter extends CustomPainter {
  const MihrabPainter();

  Path _arch(Size s, double inset) {
    final w = s.width, h = s.height, m = inset, top = inset * 1.6, sh = 74.0 + inset * 0.4;
    return Path()
      ..moveTo(m, h)
      ..lineTo(m, sh)
      ..cubicTo(m, sh - 34, w * 0.22, sh - 40, w * 0.38, sh - 54)
      ..cubicTo(w * 0.46, sh - 60, w / 2 - 4, top + 14, w / 2, top)
      ..cubicTo(w / 2 + 4, top + 14, w * 0.54, sh - 60, w * 0.62, sh - 54)
      ..cubicTo(w * 0.78, sh - 40, w - m, sh - 34, w - m, sh)
      ..lineTo(w - m, h);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final outer = _arch(size, 0);
    canvas.drawPath(Path.from(outer)..close(), Paint()..color = const Color(0xFFFFFDF7));
    canvas.drawPath(
        outer,
        Paint()
          ..color = brandGold
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8);
    canvas.drawPath(
        _arch(size, 9),
        Paint()
          ..color = brandGold.withOpacity(0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
    canvas.drawCircle(Offset(size.width / 2, -5), 4.5, Paint()..color = brandGold);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// صفحة «صدقة جارية»
class DedicationScreen extends StatelessWidget {
  const DedicationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE9C46A);
    return Scaffold(
      backgroundColor: const Color(0xFF082A43),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.7, -1.0),
            radius: 1.5,
            colors: [Color(0xFF1C6E9E), Color(0xFF0B3F63), Color(0xFF082A43)],
            stops: [0, 0.45, 1],
          ),
        ),
        child: CustomPaint(
          painter: const StarPatternPainter(color: Color(0x1AE9C46A)),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 46, 22, 26),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: brandGold, width: 1.5),
                          ),
                          child: ClipOval(child: Image.asset('assets/logo.png', width: 46, height: 46)),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('إهداء',
                                style: TextStyle(color: gold, fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.w600)),
                            Text(centerName,
                                style: TextStyle(color: Color(0xFFD5E6F1), fontSize: 13.5, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      ]),
                      const SizedBox(height: 22),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Image.memory(dedTitlePng, height: 62, gaplessPlayback: true),
                      ),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Container(
                          width: 56,
                          height: 3,
                          margin: const EdgeInsets.only(top: 8, bottom: 12),
                          decoration: BoxDecoration(color: brandGold, borderRadius: BorderRadius.circular(3)),
                        ),
                      ),
                      const Text(dedicationIntro,
                          style: TextStyle(color: Color(0xFFD5E6F1), fontSize: 14.5, height: 1.9)),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.14)),
                        ),
                        child: Column(children: [
                          for (var i = 0; i < dedicationNames.length; i++) _nameRow(dedicationNames[i], i == dedicationNames.length - 1),
                        ]),
                      ),
                      const SizedBox(height: 18),
                      const Text(dedicationOutro,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFFC6DAE8), fontSize: 13.5, height: 1.85)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _nameRow(String full, bool last) {
    final i = full.indexOf(' (');
    final name = i > 0 ? full.substring(0, i) : full;
    final kunya = i > 0 ? full.substring(i + 2).replaceAll(')', '') : '';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: Row(children: [
        Expanded(
          child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.bold)),
        ),
        if (kunya.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
            decoration: BoxDecoration(color: const Color(0x24C9A24A), borderRadius: BorderRadius.circular(10)),
            child: Text(kunya,
                style: const TextStyle(color: Color(0xFFE9C46A), fontSize: 12, fontWeight: FontWeight.w600)),
          ),
      ]),
    );
  }
}
