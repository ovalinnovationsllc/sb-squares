import 'dart:math' as math;
import 'package:flutter/material.dart';

class LogoWidget extends StatelessWidget {
  const LogoWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(350, 175),
      painter: LogoPainter(),
    );
  }
}

class LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    
    // Scale to fit the size
    canvas.scale(size.width / 400, size.height / 200);
    
    // Background
    paint.color = const Color(0xFF1a472a);
    final bgRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, 400, 200),
      const Radius.circular(10),
    );
    canvas.drawRRect(bgRect, paint);
    
    // Football field
    final fieldGradient = paint..shader = const LinearGradient(
      colors: [Color(0xFF228B22), Color(0xFF006400)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(const Rect.fromLTWH(20, 20, 360, 160));
    
    final fieldRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(20, 20, 360, 160),
      const Radius.circular(8),
    );
    canvas.drawRRect(fieldRect, fieldGradient);
    
    // Field border
    paint
      ..shader = null
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(fieldRect, paint);
    
    // Yard lines
    paint
      ..color = Colors.white.withOpacity(0.6)
      ..strokeWidth = 1;
    for (var x in [50, 80, 110, 140, 170, 230, 260, 290, 320, 350]) {
      canvas.drawLine(
        Offset(x.toDouble(), 25),
        Offset(x.toDouble(), 175),
        paint,
      );
    }
    
    // 50 yard line (center)
    paint
      ..color = Colors.white
      ..strokeWidth = 3;
    canvas.drawLine(
      const Offset(200, 25),
      const Offset(200, 175),
      paint,
    );
    
    // Grid overlay
    paint
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawRect(const Rect.fromLTWH(60, 50, 280, 100), paint);
    
    // Grid lines
    paint.strokeWidth = 0.5;
    for (var x in [88, 116, 144, 172, 228, 256, 284, 312]) {
      canvas.drawLine(
        Offset(x.toDouble(), 50),
        Offset(x.toDouble(), 150),
        paint,
      );
    }
    for (var y in [70, 90, 110, 130]) {
      canvas.drawLine(
        Offset(60, y.toDouble()),
        Offset(340, y.toDouble()),
        paint,
      );
    }
    
    // Football shadow
    paint
      ..style = PaintingStyle.fill
      ..color = Colors.black.withOpacity(0.3);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(202, 102), width: 50, height: 30),
      paint,
    );
    
    // Football
    paint.color = const Color(0xFF8B4513);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(200, 100), width: 50, height: 30),
      paint,
    );
    
    paint.color = const Color(0xFFA0522D);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(200, 100), width: 46, height: 26),
      paint,
    );
    
    // Football laces
    paint
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(200, 88), const Offset(200, 112), paint);
    
    for (var y in [92, 96, 100, 104, 108]) {
      canvas.drawLine(
        Offset(196, y.toDouble()),
        Offset(204, y.toDouble()),
        paint,
      );
    }
    
    // Title Text
    const titleStyle = TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      fontFamily: 'Arial',
      color: Colors.amber,
    );
    final titlePainter = TextPainter(
      text: const TextSpan(text: 'SUPER BOWL SQUARES', style: titleStyle),
      textDirection: TextDirection.ltr,
    );
    titlePainter.layout();
    titlePainter.paint(
      canvas,
      Offset((400 - titlePainter.width) / 2, 35),
    );
    
    // 13 Years badge
    paint
      ..style = PaintingStyle.fill
      ..color = Colors.amber;
    canvas.drawCircle(const Offset(350, 40), 18, paint);
    
    paint
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    const badgeStyle = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.bold,
      color: Colors.black,
    );
    final yearsPainter = TextPainter(
      text: const TextSpan(text: '13', style: badgeStyle),
      textDirection: TextDirection.ltr,
    );
    yearsPainter.layout();
    yearsPainter.paint(
      canvas,
      Offset(350 - yearsPainter.width / 2, 30),
    );
    
    final yearsTextPainter = TextPainter(
      text: const TextSpan(
        text: 'YEARS',
        style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black),
      ),
      textDirection: TextDirection.ltr,
    );
    yearsTextPainter.layout();
    yearsTextPainter.paint(
      canvas,
      Offset(350 - yearsTextPainter.width / 2, 42),
    );
    
    // Host credit
    const hostStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    );
    final hostPainter = TextPainter(
      text: const TextSpan(text: 'Hosted by Rob Elson', style: hostStyle),
      textDirection: TextDirection.ltr,
    );
    hostPainter.layout();
    hostPainter.paint(
      canvas,
      Offset((400 - hostPainter.width) / 2, 160),
    );
    
    // Stars
    paint
      ..style = PaintingStyle.fill
      ..color = Colors.amber.withOpacity(0.8);
    
    // Left star
    _drawStar(canvas, const Offset(70, 43), 6, paint);
    // Right star
    _drawStar(canvas, const Offset(330, 43), 6, paint);
  }
  
  void _drawStar(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    for (int i = 0; i < 10; i++) {
      final angle = (i * 36 - 90) * math.pi / 180;
      final r = i.isEven ? radius : radius * 0.5;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}