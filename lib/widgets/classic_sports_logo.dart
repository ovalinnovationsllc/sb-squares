import 'package:flutter/material.dart';
import 'dart:math' as math;

class ClassicSportsLogo extends StatelessWidget {
  const ClassicSportsLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 350,
      height: 175,
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
        child: Stack(
          children: [
            // Classic sports background - deep red and white
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFB71C1C), // Deep red
                    Color(0xFFD32F2F), // Red
                    Color(0xFFE53935), // Lighter red
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            
            // Field pattern overlay
            CustomPaint(
              painter: ClassicFieldPainter(),
              size: const Size(350, 175),
            ),
            
            // White banner background
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              bottom: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: const Color(0xFFB71C1C), width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Corner flourishes
                    Positioned(
                      top: 8,
                      left: 8,
                      child: CustomPaint(
                        painter: CornerFlourishPainter(),
                        size: const Size(30, 30),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Transform.rotate(
                        angle: math.pi / 2,
                        child: CustomPaint(
                          painter: CornerFlourishPainter(),
                          size: const Size(30, 30),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Transform.rotate(
                        angle: -math.pi / 2,
                        child: CustomPaint(
                          painter: CornerFlourishPainter(),
                          size: const Size(30, 30),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Transform.rotate(
                        angle: math.pi,
                        child: CustomPaint(
                          painter: CornerFlourishPainter(),
                          size: const Size(30, 30),
                        ),
                      ),
                    ),
                    
                    // Main content
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // Title section
                          Expanded(
                            flex: 4,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // SUPER BOWL in classic style
                                const Text(
                                  'SUPER BOWL',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFFB71C1C),
                                    letterSpacing: 2,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black26,
                                        offset: Offset(2, 2),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                
                                // Decorative line
                                Container(
                                  width: 120,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        Color(0xFFB71C1C),
                                        Colors.transparent,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                
                                // SQUARES
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFB71C1C),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'SQUARES',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Football and grid section
                          Expanded(
                            flex: 3,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                // Football
                                Container(
                                  width: 50,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF8B4513),
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(color: Colors.white, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: CustomPaint(
                                    painter: FootballLacesPainter(),
                                  ),
                                ),
                                
                                // Grid representation
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: const Color(0xFFB71C1C), width: 2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: CustomPaint(
                                    painter: ClassicGridPainter(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Host and details section
                          Expanded(
                            flex: 4,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Host name
                                const Text(
                                  'HOSTED BY',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF666666),
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'ROB ELSON',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFB71C1C),
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                
                                // Info row
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildClassicBadge('13TH YEAR', '2026'),
                                    _buildClassicBadge('EST.', '2013'),
                                    _buildClassicBadge('FEB', '8'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassicBadge(String top, String bottom) {
    return Container(
      width: 60,
      height: 35,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFB71C1C), width: 1),
        borderRadius: BorderRadius.circular(6),
        color: Colors.white,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            top,
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w600,
              color: Color(0xFF666666),
              letterSpacing: 0.5,
            ),
          ),
          Text(
            bottom,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFFB71C1C),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class ClassicFieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 1;

    // Draw yard lines pattern
    for (int i = 0; i < 8; i++) {
      final x = (size.width / 8) * i;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CornerFlourishPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB71C1C)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(0, 15);
    path.quadraticBezierTo(0, 0, 15, 0);
    path.moveTo(5, 15);
    path.quadraticBezierTo(5, 5, 15, 5);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class FootballLacesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5;

    // Center line
    canvas.drawLine(
      Offset(size.width / 2, 6),
      Offset(size.width / 2, size.height - 6),
      paint,
    );

    // Laces
    for (int i = 0; i < 4; i++) {
      final y = 8.0 + (i * 4.0);
      canvas.drawLine(
        Offset(size.width / 2 - 6, y),
        Offset(size.width / 2 + 6, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ClassicGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB71C1C)
      ..strokeWidth = 1;

    // Draw 3x3 grid
    for (int i = 1; i < 3; i++) {
      final x = (size.width / 3) * i;
      canvas.drawLine(
        Offset(x, 4),
        Offset(x, size.height - 4),
        paint,
      );
    }
    
    for (int i = 1; i < 3; i++) {
      final y = (size.height / 3) * i;
      canvas.drawLine(
        Offset(4, y),
        Offset(size.width - 4, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}