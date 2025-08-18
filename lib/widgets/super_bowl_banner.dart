import 'package:flutter/material.dart';

class SuperBowlBanner extends StatelessWidget {
  const SuperBowlBanner({super.key});

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsive sizing
    final screenSize = MediaQuery.of(context).size;
    final bannerWidth = (screenSize.width * 0.8).clamp(200.0, 600.0);
    
    return Container(
      width: bannerWidth,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 30),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1B5E20), // Dark green
            Color(0xFF2E7D32), // Medium green
            Color(0xFF1B5E20), // Dark green
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Main title
          Text(
            'SUPER BOWL SQUARES',
            style: TextStyle(
              fontSize: (bannerWidth * 0.06).clamp(20.0, 32.0),
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 2,
              shadows: const [
                Shadow(
                  color: Colors.black54,
                  offset: Offset(2, 2),
                  blurRadius: 4,
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          
          // Decorative line
          Container(
            width: bannerWidth * 0.4,
            height: 3,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.white,
                  Colors.transparent,
                ],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          
          // Host information
          Text(
            'HOSTED BY ROB ELSON',
            style: TextStyle(
              fontSize: (bannerWidth * 0.032).clamp(14.0, 18.0),
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          
          // Tradition details
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Text(
              '13TH YEAR • EST. 2013',
              style: TextStyle(
                fontSize: (bannerWidth * 0.025).clamp(12.0, 16.0),
                fontWeight: FontWeight.w600,
                color: Colors.amber.shade200,
                letterSpacing: 1,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}