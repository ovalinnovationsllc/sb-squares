import 'package:flutter/material.dart';
import 'widgets/football_field_logo.dart';
import 'widgets/super_bowl_banner.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Super Bowl Squares',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const LaunchPage(),
    );
  }
}

class LaunchPage extends StatefulWidget {
  const LaunchPage({super.key});

  @override
  State<LaunchPage> createState() => _LaunchPageState();
}

class _LaunchPageState extends State<LaunchPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));
    
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navigateToGame() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const SuperBowlSquaresPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1a472a),
              Color(0xFF228B22),
              Color(0xFF006400),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SuperBowlBanner(),
                        const SizedBox(height: 20),
                        const FootballFieldLogo(),
                        const SizedBox(height: 50),
                        ElevatedButton(
                          onPressed: _navigateToGame,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                            textStyle: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 10,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.sports_football, size: 28),
                              SizedBox(width: 10),
                              Text('ENTER THE GAME'),
                              SizedBox(width: 10),
                              Icon(Icons.arrow_forward, size: 28),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class SuperBowlSquaresPage extends StatefulWidget {
  const SuperBowlSquaresPage({super.key});

  @override
  State<SuperBowlSquaresPage> createState() => _SuperBowlSquaresPageState();
}

class _SuperBowlSquaresPageState extends State<SuperBowlSquaresPage> {
  final List<int> awayTeamNumbers = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
  final List<int> homeTeamNumbers = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
  
  final Map<String, String> selectedSquares = {};

  void _onSquareTapped(int row, int col) {
    final key = '$row-$col';
    setState(() {
      if (selectedSquares.containsKey(key)) {
        selectedSquares.remove(key);
      } else {
        selectedSquares[key] = 'Player ${selectedSquares.length + 1}';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Super Bowl Squares'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: AspectRatio(
            aspectRatio: 1.0,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double gridSize = constraints.maxWidth;
                final double cellSize = gridSize / 11;
                
                return Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: cellSize,
                      child: SizedBox(
                        width: cellSize * 10,
                        height: cellSize,
                        child: Row(
                          children: [
                            for (int i = 0; i < 10; i++)
                              Container(
                                width: cellSize,
                                height: cellSize,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade100,
                                  border: Border.all(color: Colors.black),
                                ),
                                child: Text(
                                  '${awayTeamNumbers[i]}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    
                    Positioned(
                      top: cellSize,
                      left: 0,
                      child: SizedBox(
                        width: cellSize,
                        height: cellSize * 10,
                        child: Column(
                          children: [
                            for (int i = 0; i < 10; i++)
                              Container(
                                width: cellSize,
                                height: cellSize,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.red.shade100,
                                  border: Border.all(color: Colors.black),
                                ),
                                child: Text(
                                  '${homeTeamNumbers[i]}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    
                    Positioned(
                      top: 0,
                      left: 0,
                      child: Container(
                        width: cellSize,
                        height: cellSize,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          border: Border.all(color: Colors.black),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'AWAY',
                              style: TextStyle(
                                fontSize: cellSize * 0.15,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            Text(
                              'HOME',
                              style: TextStyle(
                                fontSize: cellSize * 0.15,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    Positioned(
                      top: cellSize,
                      left: cellSize,
                      child: SizedBox(
                        width: cellSize * 10,
                        height: cellSize * 10,
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 10,
                            childAspectRatio: 1.0,
                          ),
                          itemCount: 100,
                          itemBuilder: (context, index) {
                            final row = index ~/ 10;
                            final col = index % 10;
                            final key = '$row-$col';
                            final isSelected = selectedSquares.containsKey(key);
                            
                            return GestureDetector(
                              onTap: () => _onSquareTapped(row, col),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected 
                                    ? Colors.green.shade200 
                                    : Colors.white,
                                  border: Border.all(
                                    color: Colors.black,
                                    width: 0.5,
                                  ),
                                ),
                                child: Center(
                                  child: isSelected 
                                    ? Text(
                                        selectedSquares[key]!,
                                        style: TextStyle(
                                          fontSize: cellSize * 0.15,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        textAlign: TextAlign.center,
                                      )
                                    : null,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
