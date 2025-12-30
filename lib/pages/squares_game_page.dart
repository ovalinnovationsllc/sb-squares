import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user_model.dart';
import '../models/game_score_model.dart';
import '../models/square_selection_model.dart';
import '../models/board_numbers_model.dart';
import '../models/game_config_model.dart';
import '../services/game_score_service.dart';
import '../services/square_selection_service.dart';
import '../services/board_numbers_service.dart';
import '../services/game_config_service.dart';
import '../widgets/footer_widget.dart';
import '../utils/user_color_generator.dart';
import '../utils/platform_storage.dart';
import '../main.dart';
import 'admin_dashboard.dart';

class SquaresGamePage extends StatefulWidget {
  final UserModel user;
  
  const SquaresGamePage({super.key, required this.user});

  @override
  State<SquaresGamePage> createState() => _SquaresGamePageState();
}

class _SquaresGamePageState extends State<SquaresGamePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GameScoreService _gameScoreService = GameScoreService();
  final SquareSelectionService _selectionService = SquareSelectionService();
  final BoardNumbersService _boardNumbersService = BoardNumbersService();
  final GameConfigService _configService = GameConfigService();
  List<int> awayTeamNumbers = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
  List<int> homeTeamNumbers = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
  BoardNumbersModel? _currentBoardNumbers;
  
  // Team names from config
  String _homeTeamName = 'AFC';
  String _awayTeamName = 'NFC';
  
  // Separate selected squares for each quarter - now stores full model for entry number
  final Map<String, SquareSelectionModel> q1SelectedSquares = {};
  final Map<String, SquareSelectionModel> q2SelectedSquares = {};
  final Map<String, SquareSelectionModel> q3SelectedSquares = {};
  final Map<String, SquareSelectionModel> q4SelectedSquares = {};
  
  bool _isLoadingSelections = true;
  
  // Quarter scores for highlighting winners
  List<GameScoreModel> _quarterScores = [];
  
  // Stream subscriptions for real-time updates
  StreamSubscription<List<SquareSelectionModel>>? _selectionsSubscription;
  StreamSubscription<List<GameScoreModel>>? _scoresSubscription;
  StreamSubscription<BoardNumbersModel?>? _boardNumbersSubscription;
  StreamSubscription<GameConfigModel>? _configSubscription;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    
    // Set up real-time stream subscriptions
    _setupStreamListeners();
  }
  
  void _setupStreamListeners() {
    // Listen to selections stream
    _selectionsSubscription = _selectionService.selectionsStream().listen(
      (selections) {
        if (mounted) {
          setState(() {
            // Clear existing selections
            q1SelectedSquares.clear();
            q2SelectedSquares.clear();
            q3SelectedSquares.clear();
            q4SelectedSquares.clear();

            // Update with real-time data - store full model for entry number
            for (final selection in selections) {
              final map = _getQuarterMap(selection.quarter);
              map[selection.squareKey] = selection;
            }

            _isLoadingSelections = false;
          });

        }
      },
      onError: (error) {
        print('Error in selections stream: $error');
      },
    );

    // Listen to scores stream
    _scoresSubscription = _gameScoreService.scoresStream().listen(
      (scores) {
        if (mounted) {
          setState(() {
            _quarterScores = scores;
          });
        }
      },
      onError: (error) {
        print('Error in scores stream: $error');
      },
    );

    // Listen to board numbers stream
    _boardNumbersSubscription = _boardNumbersService.boardNumbersStream().listen(
      (boardNumbers) {
        if (mounted) {
          setState(() {
            _currentBoardNumbers = boardNumbers;
            if (boardNumbers != null) {
              homeTeamNumbers = boardNumbers.homeNumbers;
              awayTeamNumbers = boardNumbers.awayNumbers;
            } else {
              // Reset to default (will be hidden in UI)
              homeTeamNumbers = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
              awayTeamNumbers = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
            }
          });
        }
      },
      onError: (error) {
        print('🚨 Error in board numbers stream: $error');
      },
    );

    // Listen to config stream
    _configSubscription = _configService.configStream().listen(
      (config) {
        if (mounted) {
          setState(() {
            _homeTeamName = config.homeTeamName;
            _awayTeamName = config.awayTeamName;
          });
        }
      },
      onError: (error) {
        print('Error in config stream: $error');
      },
    );
  }
  
  
  
  @override
  void dispose() {
    // Cancel all stream subscriptions to prevent setState() after dispose
    _selectionsSubscription?.cancel();
    _scoresSubscription?.cancel();
    _boardNumbersSubscription?.cancel();
    _configSubscription?.cancel();
    
    _tabController.dispose();
    super.dispose();
  }

  void _onSquareTapped(int row, int col, int quarter) async {
    if (_isLoadingSelections) return; // Prevent taps while loading

    // Check if user has paid - if not, show payment required message
    if (!widget.user.hasPaid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment required. Contact admin to activate account.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final key = '$row-$col';
    final selectedSquares = _getQuarterMap(quarter);
    final userName = widget.user.displayName.isEmpty ? widget.user.email : widget.user.displayName;

    // Check if square is already taken by another user
    if (selectedSquares.containsKey(key) && selectedSquares[key]!.userName != userName) {
      // Square is taken by someone else, show message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('This square is already taken by ${selectedSquares[key]!.userName}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // Check if user is trying to select a new square (not deselecting)
    final isDeselecting = selectedSquares.containsKey(key) && selectedSquares[key]!.userName == userName;

    // Check if user has reached their limit for this quarter
    if (!isDeselecting && _getUserQuarterSelectionCount(quarter) >= widget.user.numEntries) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You have reached your maximum of ${widget.user.numEntries} square${widget.user.numEntries != 1 ? 's' : ''} for this quarter'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // Calculate the next available entry number for this user in this quarter
    final entryNumber = isDeselecting ? 1 : _getNextEntryNumber(quarter, userName);

    // Save to Firestore
    print('Attempting to save selection: Q$quarter, ($row,$col) for user ${widget.user.id} (entry #$entryNumber)');
    final success = await _selectionService.saveSelection(
      quarter: quarter,
      row: row,
      col: col,
      userId: widget.user.id,
      userName: userName,
      entryNumber: entryNumber,
    );
    
    print('Save result: $success');
    
    if (success) {
      // Real-time updates will automatically sync the UI
      
      // Show feedback
      if (isDeselecting) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Square deselected'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 1),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Square selected!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save selection. Please try again.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
  
  Map<String, SquareSelectionModel> _getQuarterMap(int quarter) {
    switch (quarter) {
      case 1:
        return q1SelectedSquares;
      case 2:
        return q2SelectedSquares;
      case 3:
        return q3SelectedSquares;
      case 4:
        return q4SelectedSquares;
      default:
        return q1SelectedSquares;
    }
  }

  int _getUserSelectionsCount() {
    int count = 0;
    final userName = widget.user.displayName.isEmpty ? widget.user.email : widget.user.displayName;
    count += q1SelectedSquares.values.where((v) => v.userName == userName).length;
    count += q2SelectedSquares.values.where((v) => v.userName == userName).length;
    count += q3SelectedSquares.values.where((v) => v.userName == userName).length;
    count += q4SelectedSquares.values.where((v) => v.userName == userName).length;
    return count;
  }

  int _getUserQuarterSelectionCount(int quarter) {
    final userName = widget.user.displayName.isEmpty ? widget.user.email : widget.user.displayName;
    final selectedSquares = _getQuarterMap(quarter);
    return selectedSquares.values.where((v) => v.userName == userName).length;
  }

  /// Get the next available entry number for this user in this quarter
  int _getNextEntryNumber(int quarter, String userName) {
    final selectedSquares = _getQuarterMap(quarter);
    final userSelections = selectedSquares.values
        .where((v) => v.userName == userName)
        .map((v) => v.entryNumber)
        .toSet();

    // Find the lowest unused entry number starting from 1
    for (int i = 1; i <= widget.user.numEntries; i++) {
      if (!userSelections.contains(i)) {
        return i;
      }
    }
    // Fallback (shouldn't happen if limits are enforced)
    return userSelections.length + 1;
  }

  /// Check if a user has multiple entries in the given quarter
  bool _userHasMultipleEntriesInQuarter(int quarter, String? userName) {
    if (userName == null) return false;
    final selectedSquares = _getQuarterMap(quarter);
    final count = selectedSquares.values.where((v) => v.userName == userName).length;
    return count > 1;
  }
  
  String _getSquareType(int row, int col, int quarter) {
    // Find the score for this quarter
    final score = _quarterScores.firstWhere(
      (s) => s.quarter == quarter,
      orElse: () => GameScoreModel(id: '', quarter: quarter, homeScore: 0, awayScore: 0),
    );
    
    if (score.id.isEmpty || _currentBoardNumbers == null) return 'normal'; // No score set yet or no board numbers
    
    final homeScoreDigit = score.homeLastDigit;
    final awayScoreDigit = score.awayLastDigit;
    
    // Find the grid coordinates that correspond to these score digits  
    // Use the same arrays that are used for visual display
    final homeNumbers = homeTeamNumbers;
    final awayNumbers = awayTeamNumbers;
    
    // Find which grid position corresponds to the score digits
    int? homeRow, awayCol;
    
    for (int i = 0; i < homeNumbers.length; i++) {
      if (homeNumbers[i] == homeScoreDigit) {
        homeRow = i;
        break;
      }
    }
    
    for (int i = 0; i < awayNumbers.length; i++) {
      if (awayNumbers[i] == awayScoreDigit) {
        awayCol = i;
        break;
      }
    }
    
    // Debug logging (reduced)
    if (homeRow != null && awayCol != null && row == homeRow && col == awayCol) {
      print('🎮 Q$quarter Winner at Grid ($row,$col): ${homeNumbers[row]}-${awayNumbers[col]}');
    }
    
    if (homeRow == null || awayCol == null) {
      // Score digits not found in board numbers - shouldn't happen
      return 'normal';
    }
    
    // Check if this is the winning square
    if (row == homeRow && col == awayCol) {
      print('✅ WINNER FOUND at Grid ($row,$col) - Numbers: ${homeNumbers[row]}-${awayNumbers[col]}');
      return 'winner';
    }
    
    // Check if this is an adjacent square (up, down, left, right) - wrapping around edges
    if ((row == (homeRow + 1) % 10 && col == awayCol) || // down
        (row == (homeRow - 1 + 10) % 10 && col == awayCol) || // up
        (row == homeRow && col == (awayCol + 1) % 10) || // right
        (row == homeRow && col == (awayCol - 1 + 10) % 10)) { // left
      return 'adjacent';
    }
    
    // Check if this is a diagonal square - wrapping around edges
    if ((row == (homeRow + 1) % 10 && col == (awayCol + 1) % 10) || // down-right
        (row == (homeRow + 1) % 10 && col == (awayCol - 1 + 10) % 10) || // down-left
        (row == (homeRow - 1 + 10) % 10 && col == (awayCol + 1) % 10) || // up-right
        (row == (homeRow - 1 + 10) % 10 && col == (awayCol - 1 + 10) % 10)) { // up-left
      return 'diagonal';
    }
    
    return 'normal';
  }
  
  void _showInstructions() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: const BoxConstraints(
            maxWidth: 700,
          ),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Game Instructions',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                      const Text(
                        'BUY A 2026 SUPER BOWL SQUARE - PLAY TO GET PAID',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '* 13th year running *',
                        style: TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'HIT UP TO 9 BOXES EACH QUARTER',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Will pay the winning quarter score and each adjacent and diagonal box!\n'
                        'The board is never ending and a perpetual cylinder on the edges - wrap it!\n'
                        'Box assignment will be a random draw',
                        style: TextStyle(fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      _buildInstructionsGrid(),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Column(
                          children: [
                            Text(
                              'Each quarter wins as follows -',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 8),
                            Wrap(
                              alignment: WrapAlignment.spaceEvenly,
                              children: [
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 4.0),
                                  child: Column(
                                    children: [
                                      Text(
                                        'Winning score:',
                                        style: TextStyle(color: Colors.white, fontSize: 12),
                                        textAlign: TextAlign.center,
                                      ),
                                      Text(
                                        '\$2400',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 4.0),
                                  child: Column(
                                    children: [
                                      Text(
                                        'Adjacent box:',
                                        style: TextStyle(color: Colors.white, fontSize: 12),
                                        textAlign: TextAlign.center,
                                      ),
                                      Text(
                                        '\$150',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 4.0),
                                  child: Column(
                                    children: [
                                      Text(
                                        'Diagonal box:',
                                        style: TextStyle(color: Colors.white, fontSize: 12),
                                        textAlign: TextAlign.center,
                                      ),
                                      Text(
                                        '\$100',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
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
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: Colors.purple,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Column(
                          children: [
                            Text(
                              'SPECIAL BONUS - Halftime & Final Only!',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Reverse + 5 wins \$200',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 4),
                            Text(
                              'At Q2 & Q4: Reverse scores, add 5 to each, last digits win!\n'
                              'Example: 10-3 → Reverse to 3-10 → Add 5 → 8-15 → Winner: 8 & 5',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
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
    );
  }
  
  Widget _buildInstructionsGrid() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInstructionCell('Diagonal\n\$100', Colors.blue[100]!),
              _buildInstructionCell('Adjacent\n\$150', Colors.grey[200]!),
              _buildInstructionCell('Diagonal\n\$100', Colors.blue[100]!),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInstructionCell('Adjacent\n\$150', Colors.grey[200]!),
              _buildInstructionCell('WINNER\n\$2400', Colors.red[200]!),
              _buildInstructionCell('Adjacent\n\$150', Colors.grey[200]!),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInstructionCell('Diagonal\n\$100', Colors.blue[100]!),
              _buildInstructionCell('Adjacent\n\$150', Colors.grey[200]!),
              _buildInstructionCell('Diagonal\n\$100', Colors.blue[100]!),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildInstructionCell(String text, Color color) {
    return Flexible(
      child: Container(
        constraints: const BoxConstraints(
          minWidth: 60,
          minHeight: 45,
        ),
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: Colors.black, width: 1),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(2.0),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    print('_logout called');
    // Clear storage
    await PlatformStorage.remove('sb_squares_user');
    print('Storage cleared, mounted: $mounted');

    // Navigate to login screen instead of trying to reload on mobile
    if (mounted) {
      print('Navigating to LaunchPage');
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LaunchPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Super Bowl Squares'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Q1'),
            Tab(text: 'Q2'),
            Tab(text: 'Q3'),
            Tab(text: 'Q4'),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              print('PopupMenu selected: $value');
              switch (value) {
                case 'instructions':
                  _showInstructions();
                  break;
                case 'logout':
                  _logout();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'instructions',
                child: Row(
                  children: [
                    Icon(Icons.help_outline),
                    SizedBox(width: 8),
                    Text('Game Instructions'),
                  ],
                ),
              ),
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
          if (widget.user.isAdmin)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Icon(
                Icons.admin_panel_settings,
                color: Colors.amber,
                size: 20,
              ),
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
                    widget.user.displayName.isEmpty 
                        ? 'Welcome!' 
                        : 'Welcome, ${widget.user.displayName}!',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                Text(
                  widget.user.hasPaid 
                      ? '${_getUserSelectionsCount()}/${widget.user.numEntries * 4} squares'
                      : 'Payment Required',
                  style: TextStyle(
                    fontSize: 14,
                    color: !widget.user.hasPaid
                        ? Colors.orange.shade700
                        : _getUserSelectionsCount() >= widget.user.numEntries * 4
                            ? Colors.red 
                            : Theme.of(context).colorScheme.onSurface,
                    fontWeight: !widget.user.hasPaid ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
                if (widget.user.isAdmin)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Icon(
                      Icons.admin_panel_settings,
                      color: Colors.amber.shade700,
                      size: 20,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildQuarterGrid(1),
                _buildQuarterGrid(2),
                _buildQuarterGrid(3),
                _buildQuarterGrid(4),
              ],
            ),
          ),
          const FooterWidget(),
        ],
      ),
    );
  }
  
  Widget _buildQuarterGrid(int quarter) {
    if (_isLoadingSelections) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    final selectedSquares = _getQuarterMap(quarter);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: widget.user.hasPaid
                  ? Text(
                      '${_getUserQuarterSelectionCount(quarter)} of ${widget.user.numEntries} square${widget.user.numEntries != 1 ? 's' : ''} selected',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock, color: Colors.orange.shade700, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Payment required to select squares',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            Expanded(
              child: AspectRatio(
                aspectRatio: 1.0,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final double gridSize = constraints.maxWidth;
                    final double cellSize = gridSize / 11;
                      
                    return Stack(
                      children: [
                        // Away team label (top, spread horizontally)
                        Positioned(
                          top: cellSize * 0.15,
                          left: cellSize,
                          child: SizedBox(
                            width: cellSize * 10,
                            height: cellSize * 0.4,
                            child: Wrap(
                              alignment: WrapAlignment.spaceEvenly,
                              children: _awayTeamName.toUpperCase().split('').map((letter) => 
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: cellSize * 0.02),
                                  child: Text(
                                    letter,
                                    style: GoogleFonts.rubik(
                                      fontSize: cellSize * 0.25,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade700,
                                      height: 1.0,
                                    ),
                                  ),
                                ),
                              ).toList(),
                            ),
                          ),
                        ),
                        
                        Positioned(
                          top: cellSize * 0.6,
                          left: cellSize,
                          child: SizedBox(
                            width: cellSize * 10,
                            height: cellSize * 0.4,
                            child: Row(
                              children: [
                                for (int i = 0; i < 10; i++)
                                  Container(
                                    width: cellSize,
                                    height: cellSize * 0.4,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade100,
                                      border: Border.all(color: Colors.black),
                                    ),
                                    child: Text(
                                      _currentBoardNumbers != null ? '${awayTeamNumbers[i]}' : '',
                                      style: GoogleFonts.rubik(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        
                        // Home team label (left side, vertical)
                        Positioned(
                          top: cellSize * 1.2,
                          left: cellSize * 0.1,
                          child: SizedBox(
                            width: cellSize * 0.4,
                            height: cellSize * 9.6,
                            child: Wrap(
                              direction: Axis.vertical,
                              alignment: WrapAlignment.spaceEvenly,
                              children: _homeTeamName.toUpperCase().split('').map((letter) => 
                                Padding(
                                  padding: EdgeInsets.symmetric(vertical: cellSize * 0.02),
                                  child: Text(
                                    letter,
                                    style: GoogleFonts.rubik(
                                      fontSize: cellSize * 0.25,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red.shade700,
                                      height: 1.0,
                                    ),
                                  ),
                                ),
                              ).toList(),
                            ),
                          ),
                        ),
                        
                        Positioned(
                          top: cellSize,
                          left: cellSize * 0.6,
                          child: SizedBox(
                            width: cellSize * 0.4,
                            height: cellSize * 10,
                            child: Column(
                              children: [
                                for (int i = 0; i < 10; i++)
                                  Container(
                                    width: cellSize * 0.4,
                                    height: cellSize,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade100,
                                      border: Border.all(color: Colors.black),
                                    ),
                                    child: Text(
                                      _currentBoardNumbers != null ? '${homeTeamNumbers[i]}' : '',
                                      style: GoogleFonts.rubik(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Colors.red.shade700,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        
                        Positioned(
                          top: cellSize * 0.6,
                          left: cellSize * 0.6,
                          child: Container(
                            width: cellSize * 0.4,
                            height: cellSize * 0.4,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              border: Border.all(color: Colors.black),
                            ),
                            child: const SizedBox(), // Empty corner
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
                                final squareType = _getSquareType(row, col, quarter);
                                final selection = selectedSquares[key];
                                final squareOwnerName = selection?.userName;
                                final entryNumber = selection?.entryNumber ?? 1;

                                // Determine the color based on square type and user
                                Color backgroundColor;
                                Color borderColor = Colors.black;
                                double borderWidth = 0.5;

                                if (squareType == 'winner') {
                                  backgroundColor = isSelected ? Colors.red.shade400 : Colors.red.shade200;
                                  borderColor = Colors.red.shade700;
                                  borderWidth = 2.0;
                                } else if (squareType == 'adjacent') {
                                  backgroundColor = isSelected ? Colors.amber.shade400 : Colors.amber.shade200;
                                  borderColor = Colors.amber.shade700;
                                  borderWidth = 1.5;
                                } else if (squareType == 'diagonal') {
                                  backgroundColor = isSelected ? Colors.blue.shade300 : Colors.blue.shade200;
                                  borderColor = Colors.blue.shade600;
                                  borderWidth = 1.0;
                                } else {
                                  // Use user-specific colors for normal squares
                                  if (isSelected && squareOwnerName != null) {
                                    // Generate a unique color for each user based on their name
                                    backgroundColor = UserColorGenerator.getColorForUser(squareOwnerName);
                                    borderColor = UserColorGenerator.getDarkColorForUser(squareOwnerName);

                                    // If it's the current user's square, make it slightly different
                                    final currentUserName = widget.user.displayName.isEmpty ? widget.user.email : widget.user.displayName;
                                    if (squareOwnerName == currentUserName) {
                                      backgroundColor = UserColorGenerator.getOwnSquareColor(squareOwnerName);
                                      borderWidth = 1.0;
                                    }
                                  } else {
                                    backgroundColor = Colors.white;
                                  }
                                }

                                // Circled number characters for entry badge
                                const circledNumbers = ['①', '②', '③', '④', '⑤', '⑥', '⑦', '⑧', '⑨', '⑩'];

                                return GestureDetector(
                                  onTap: () => _onSquareTapped(row, col, quarter),
                                  child: Opacity(
                                    opacity: widget.user.hasPaid ? 1.0 : 0.7,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: backgroundColor,
                                        border: Border.all(
                                          color: borderColor,
                                          width: borderWidth,
                                        ),
                                      ),
                                    child: Stack(
                                      children: [
                                        // Prize badge for winning squares
                                        if (squareType != 'normal')
                                          Positioned(
                                            top: 2,
                                            right: 2,
                                            child: Container(
                                              padding: const EdgeInsets.all(2),
                                              decoration: BoxDecoration(
                                                color: squareType == 'winner'
                                                  ? Colors.red.shade700
                                                  : squareType == 'adjacent'
                                                    ? Colors.amber.shade700
                                                    : Colors.blue.shade700,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                squareType == 'winner'
                                                  ? '\$2400'
                                                  : squareType == 'adjacent'
                                                    ? '\$150'
                                                    : '\$100',
                                                style: GoogleFonts.rubik(
                                                  color: Colors.white,
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        // Entry number badge (bottom-left corner) - show if owner has multiple entries in this quarter
                                        if (isSelected && selection != null && _userHasMultipleEntriesInQuarter(quarter, squareOwnerName))
                                          Positioned(
                                            bottom: 1,
                                            left: 1,
                                            child: Text(
                                              entryNumber <= 10 ? circledNumbers[entryNumber - 1] : '$entryNumber',
                                              style: TextStyle(
                                                fontSize: cellSize * 0.18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                                shadows: [
                                                  Shadow(
                                                    color: Colors.black.withOpacity(0.7),
                                                    blurRadius: 2,
                                                    offset: const Offset(0.5, 0.5),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        // Owner name in center
                                        Center(
                                          child: isSelected && squareOwnerName != null
                                            ? Text(
                                                squareOwnerName,
                                                style: TextStyle(
                                                  fontSize: cellSize * 0.15,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.white,
                                                  shadows: [
                                                    Shadow(
                                                      color: Colors.black.withOpacity(0.5),
                                                      blurRadius: 2,
                                                      offset: const Offset(1, 1),
                                                    ),
                                                  ],
                                                ),
                                                textAlign: TextAlign.center,
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              )
                                            : null,
                                        ),
                                      ],
                                    ),
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
          ],
        ),
      ),
    );
  }
}