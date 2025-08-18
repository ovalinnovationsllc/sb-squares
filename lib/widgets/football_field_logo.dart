import 'package:flutter/material.dart';

class FootballFieldLogo extends StatelessWidget {
  const FootballFieldLogo({super.key});

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions
    final screenSize = MediaQuery.of(context).size;
    
    // Calculate responsive dimensions
    // Logo takes up 80% of screen width (max 600px) and maintains 2:1 aspect ratio
    final logoWidth = (screenSize.width * 0.8).clamp(200.0, 600.0);
    final logoHeight = logoWidth * 0.5; // Maintain 2:1 aspect ratio
    
    return Container(
      width: logoWidth,
      height: logoHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: CustomPaint(
          painter: FootballFieldPainter(),
          size: Size(logoWidth, logoHeight),
        ),
      ),
    );
  }
}

class FootballFieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Dark green background
    final backgroundPaint = Paint()
      ..color = const Color(0xFF1B5E20);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    // Field dimensions - make field fill more of the space
    final fieldTop = size.height * 0.05;
    final fieldBottom = size.height * 0.95;
    final fieldLeft = size.width * 0.05;
    final fieldRight = size.width * 0.95;
    final fieldWidth = fieldRight - fieldLeft;
    final fieldHeight = fieldBottom - fieldTop;
    
    // End zone width (10% of field on each side)
    final endZoneWidth = fieldWidth * 0.1;
    
    // Main field green with subtle gradient
    final fieldPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF2E7D32), // Dark green
          const Color(0xFF388E3C), // Medium green
          const Color(0xFF2E7D32), // Dark green
        ],
        stops: const [0.0, 0.5, 1.0],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTRB(fieldLeft, fieldTop, fieldRight, fieldBottom));

    // Draw main field
    canvas.drawRect(
      Rect.fromLTRB(fieldLeft, fieldTop, fieldRight, fieldBottom),
      fieldPaint,
    );
    
    // Draw alternating grass stripes for texture
    final stripePaint = Paint()
      ..color = const Color(0xFF388E3C).withOpacity(0.3)
      ..style = PaintingStyle.fill;
    
    for (int i = 0; i < 10; i += 2) {
      final stripeLeft = fieldLeft + endZoneWidth + (fieldWidth - 2 * endZoneWidth) / 10 * i;
      final stripeRight = fieldLeft + endZoneWidth + (fieldWidth - 2 * endZoneWidth) / 10 * (i + 1);
      canvas.drawRect(
        Rect.fromLTRB(stripeLeft, fieldTop, stripeRight, fieldBottom),
        stripePaint,
      );
    }

    // Scale font sizes based on field size
    final scaleFactor = size.width / 350; // Base size was 350
    
    // White line paint
    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2 * scaleFactor
      ..style = PaintingStyle.stroke;
    
    final thickLinePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3 * scaleFactor
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Draw field border
    canvas.drawRect(
      Rect.fromLTRB(fieldLeft, fieldTop, fieldRight, fieldBottom),
      thickLinePaint,
    );
    
    // Draw end zones
    final leftEndZone = fieldLeft + endZoneWidth;
    final rightEndZone = fieldRight - endZoneWidth;
    
    // End zone lines
    canvas.drawLine(
      Offset(leftEndZone, fieldTop),
      Offset(leftEndZone, fieldBottom),
      thickLinePaint,
    );
    canvas.drawLine(
      Offset(rightEndZone, fieldTop),
      Offset(rightEndZone, fieldBottom),
      thickLinePaint,
    );
    
    // Draw "END ZONE" text in end zones
    final endZonePainter = TextPainter(textDirection: TextDirection.ltr);
    
    // Left end zone
    endZonePainter.text = TextSpan(
      text: 'END ZONE',
      style: TextStyle(
        color: Colors.white,
        fontSize: 14 * scaleFactor,
        fontWeight: FontWeight.bold,
        letterSpacing: 2,
      ),
    );
    endZonePainter.layout();
    
    canvas.save();
    canvas.translate(fieldLeft + endZoneWidth / 2, fieldTop + fieldHeight / 2);
    canvas.rotate(-1.5708); // -90 degrees
    endZonePainter.paint(
      canvas,
      Offset(-endZonePainter.width / 2, -endZonePainter.height / 2),
    );
    canvas.restore();
    
    // Right end zone
    canvas.save();
    canvas.translate(fieldRight - endZoneWidth / 2, fieldTop + fieldHeight / 2);
    canvas.rotate(1.5708); // 90 degrees
    endZonePainter.paint(
      canvas,
      Offset(-endZonePainter.width / 2, -endZonePainter.height / 2),
    );
    canvas.restore();

    // Draw yard lines (every 10 yards) - only in main field area
    final mainFieldWidth = fieldWidth - 2 * endZoneWidth;
    
    for (int i = 1; i < 10; i++) {
      final x = leftEndZone + (mainFieldWidth / 10) * i;
      
      canvas.drawLine(
        Offset(x, fieldTop),
        Offset(x, fieldBottom),
        linePaint,
      );
    }

    // Draw 50-yard line (center) - thicker
    final centerX = fieldLeft + fieldWidth / 2;
    canvas.drawLine(
      Offset(centerX, fieldTop),
      Offset(centerX, fieldBottom),
      thickLinePaint,
    );

    // Draw yard numbers
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // Yard numbers (10, 20, 30, 40, 50, 40, 30, 20, 10)
    final yardNumbers = [10, 20, 30, 40, 50, 40, 30, 20, 10];
    
    for (int i = 0; i < 9; i++) {
      final x = leftEndZone + (mainFieldWidth / 10) * (i + 1);
      final number = yardNumbers[i];
      
      // Small numbers near top (rotated 180 degrees - upside down)
      textPainter.text = TextSpan(
        text: number.toString(),
        style: TextStyle(
          color: Colors.white,
          fontSize: 12 * scaleFactor,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();
      
      canvas.save();
      canvas.translate(x, fieldTop + 20 * scaleFactor + textPainter.height);
      canvas.rotate(3.14159); // 180 degrees
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, 0),
      );
      canvas.restore();
      
      // Small numbers near bottom (normal orientation)
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, fieldBottom - 20 * scaleFactor - textPainter.height),
      );
    }
    
    // Add hash marks
    final hashPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1 * scaleFactor;
    
    // Hash marks at 1/3 and 2/3 height
    final hashY1 = fieldTop + fieldHeight * 0.4;
    final hashY2 = fieldTop + fieldHeight * 0.6;
    final hashLength = 3.0 * scaleFactor;
    
    // Draw hash marks every 5 yards
    for (int i = 0; i <= 20; i++) {
      final x = leftEndZone + (mainFieldWidth / 20) * i;
      
      // Top hash marks
      canvas.drawLine(
        Offset(x, hashY1 - hashLength),
        Offset(x, hashY1 + hashLength),
        hashPaint,
      );
      
      // Bottom hash marks
      canvas.drawLine(
        Offset(x, hashY2 - hashLength),
        Offset(x, hashY2 + hashLength),
        hashPaint,
      );
    }
    
    // Draw realistic football at center of field
    _drawFootball(canvas, centerX, fieldTop + fieldHeight / 2, scaleFactor);
  }
  
  void _drawFootball(Canvas canvas, double centerX, double centerY, double scaleFactor) {
    // Football dimensions - scaled to field
    final footballWidth = 25.0 * scaleFactor;
    final footballHeight = 15.0 * scaleFactor;
    
    // Football body - brown leather color
    final footballPaint = Paint()
      ..color = const Color(0xFF8B4513) // Saddle brown
      ..style = PaintingStyle.fill;
    
    // Create football oval shape
    final footballRect = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: footballWidth,
      height: footballHeight,
    );
    
    // Draw football body (ellipse)
    canvas.drawOval(footballRect, footballPaint);
    
    // Add darker brown shading for 3D effect
    final shadowPaint = Paint()
      ..color = const Color(0xFF654321) // Dark brown
      ..style = PaintingStyle.fill;
    
    // Bottom shadow
    final shadowRect = Rect.fromCenter(
      center: Offset(centerX, centerY + footballHeight * 0.15),
      width: footballWidth * 0.9,
      height: footballHeight * 0.4,
    );
    canvas.drawOval(shadowRect, shadowPaint);
    
    // White stitching line down the middle
    final stitchPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5 * scaleFactor
      ..style = PaintingStyle.stroke;
    
    // Center line
    canvas.drawLine(
      Offset(centerX - footballWidth * 0.35, centerY),
      Offset(centerX + footballWidth * 0.35, centerY),
      stitchPaint,
    );
    
    // Cross stitches
    final stitchLength = 2.0 * scaleFactor;
    for (int i = -2; i <= 2; i++) {
      final x = centerX + (footballWidth * 0.15 * i);
      canvas.drawLine(
        Offset(x - stitchLength, centerY - stitchLength),
        Offset(x + stitchLength, centerY + stitchLength),
        stitchPaint,
      );
      canvas.drawLine(
        Offset(x - stitchLength, centerY + stitchLength),
        Offset(x + stitchLength, centerY - stitchLength),
        stitchPaint,
      );
    }
    
    // Add highlight for 3D effect
    final highlightPaint = Paint()
      ..color = const Color(0xFFD2B48C) // Tan color
      ..style = PaintingStyle.fill;
    
    final highlightRect = Rect.fromCenter(
      center: Offset(centerX - footballWidth * 0.1, centerY - footballHeight * 0.2),
      width: footballWidth * 0.3,
      height: footballHeight * 0.3,
    );
    canvas.drawOval(highlightRect, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}