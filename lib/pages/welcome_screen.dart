import '../utils/platform_storage.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import '../widgets/footer_widget.dart';
import 'squares_game_page.dart';

class WelcomeScreen extends StatelessWidget {
  final UserModel user;

  const WelcomeScreen({super.key, required this.user});

  static void _logout(BuildContext context) async {
    // Clear storage
    await PlatformStorage.remove('sb_squares_user');
    
    // Navigate to login screen instead of trying to reload on mobile
    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  void _navigateToGame(BuildContext context) async {
    // Mark that the user has seen the instructions
    final userService = UserService();
    await userService.markInstructionsSeen(user.id);
    
    // Update the local user model to reflect this change
    final updatedUser = user.copyWith(hasSeenInstructions: true);
    
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => SquaresGamePage(user: updatedUser),
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
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Super Bowl Squares 2026'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'logout') {
                _logout(context);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // User info header - moved from AppBar to prevent overflow
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            color: Theme.of(context).colorScheme.inversePrimary.withOpacity(0.1),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    user.displayName.isEmpty 
                        ? 'Welcome!' 
                        : 'Welcome, ${user.displayName}!',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                Text(
                  'Entries: ${user.numEntries}/100',
                  style: TextStyle(
                    fontSize: 14,
                    color: user.numEntries >= 100 
                        ? Colors.red 
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Title
                  const Text(
                    'BUY A 2026 SUPER BOWL SQUARE - PLAY TO GET PAID',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '* 13th year running *',
                    style: TextStyle(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Game Description
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text(
                            'THE GAME NOW SELLS ITSELF - MORE PEOPLE INTERESTED EACH YEAR\n'
                            'YOU CAN BE IN - WAITING LIST EVERY YEAR - DON\'T MISS OUT\n'
                            'SOLD OUT 2025 IN UNDER 25 MINUTES',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // How It Works
                  const Text(
                    'Payouts Everywhere',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'HIT UP TO 9 BOXES EACH QUARTER',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text(
                            'Will pay the winning quarter score and each adjacent and diagonal box!\n'
                            'The board is never ending and a perpetual cylinder on the edges - wrap it!\n'
                            'Box assignment will be a random draw',
                            style: TextStyle(fontSize: 15),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Example Grid
                  _buildExampleGrid(),
                  const SizedBox(height: 24),

                  // Payout Structure
                  const Card(
                    color: Colors.green,
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text(
                            'Each quarter wins as follows -',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 12),
                          Wrap(
                            alignment: WrapAlignment.spaceEvenly,
                            children: [
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8.0),
                                child: Column(
                                  children: [
                                    Text(
                                      'Winning score - red:',
                                      style: TextStyle(color: Colors.white, fontSize: 14),
                                      textAlign: TextAlign.center,
                                    ),
                                    Text(
                                      '\$2400',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8.0),
                                child: Column(
                                  children: [
                                    Text(
                                      'Adjacent box - black:',
                                      style: TextStyle(color: Colors.white, fontSize: 14),
                                      textAlign: TextAlign.center,
                                    ),
                                    Text(
                                      '\$150',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8.0),
                                child: Column(
                                  children: [
                                    Text(
                                      'Diagonal box - blue:',
                                      style: TextStyle(color: Colors.white, fontSize: 14),
                                      textAlign: TextAlign.center,
                                    ),
                                    Text(
                                      '\$100',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Special Rules
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '* \$200 prize at half and final (reverse the number and add 5 to each)**',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Ex: Score 17 - 10  (Change to 0-7 and add 5 = winner of 5 and 2)',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Important Info
                  const Card(
                    color: Colors.orange,
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text(
                            'Payments based on full board. Need full board to play the squares.',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Will change the board number layout each quarter - re-randomize score boxes!!',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'There will be no monies refunded once the board is filled. If you do not complete your payment, I will seek another player after Feb 1st.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Cost
                  const Card(
                    color: Colors.red,
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'Cost \$150 per box - paying out large money! WINNERS ALL OVER',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Enter Game Button
                  ElevatedButton(
                    onPressed: () => _navigateToGame(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
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
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
          ),
          const FooterWidget(),
        ],
      ),
    );
  }

  Widget _buildExampleGrid() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Example Payout Pattern',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Center(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top row
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildGridCell('Diagonal\n\$100', Colors.blue[100]!, isBlue: true),
                        _buildGridCell('Adjacent\n\$150', Colors.grey[200]!),
                        _buildGridCell('Diagonal\n\$100', Colors.blue[100]!, isBlue: true),
                      ],
                    ),
                    // Middle row
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildGridCell('Adjacent\n\$150', Colors.grey[200]!),
                        _buildGridCell('WINNER\n\$2400', Colors.red[200]!, isRed: true),
                        _buildGridCell('Adjacent\n\$150', Colors.grey[200]!),
                      ],
                    ),
                    // Bottom row
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildGridCell('Diagonal\n\$100', Colors.blue[100]!, isBlue: true),
                        _buildGridCell('Adjacent\n\$150', Colors.grey[200]!),
                        _buildGridCell('Diagonal\n\$100', Colors.blue[100]!, isBlue: true),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Red = Winner (\$2400) | Black = Adjacent (\$150) | Blue = Diagonal (\$100)',
              style: TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridCell(String text, Color color, {bool isRed = false, bool isBlue = false}) {
    return Flexible(
      child: Container(
        constraints: const BoxConstraints(
          minWidth: 60,
          minHeight: 50,
        ),
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: Colors.black, width: 1),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isRed ? Colors.red : (isBlue ? Colors.blue : Colors.black),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}