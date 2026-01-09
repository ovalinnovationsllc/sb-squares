import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../utils/web_reload_stub.dart'
    if (dart.library.html) '../utils/web_reload.dart';
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
import '../services/version_service.dart';
import '../services/user_service.dart';
import '../widgets/footer_widget.dart';
import '../widgets/coach_mark_overlay.dart';
import '../utils/user_color_generator.dart';
import '../utils/platform_storage.dart';
import '../utils/nfl_team_colors.dart';
import '../main.dart';

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
  final VersionService _versionService = VersionService();
  final UserService _userService = UserService();

  // Current user - refreshed from Firestore
  late UserModel _currentUser;

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
  
  // Update available flag
  bool _updateAvailable = false;

  // Coach marks overlay
  bool _showCoachMarks = false;

  // Stream subscriptions for real-time updates
  StreamSubscription<List<SquareSelectionModel>>? _selectionsSubscription;
  StreamSubscription<List<GameScoreModel>>? _scoresSubscription;
  StreamSubscription<BoardNumbersModel?>? _boardNumbersSubscription;
  StreamSubscription<GameConfigModel>? _configSubscription;
  StreamSubscription<bool>? _versionSubscription;
  StreamSubscription<UserModel?>? _userSubscription;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    // Initialize current user with widget value
    _currentUser = widget.user;

    // Set up real-time stream subscriptions
    _setupStreamListeners();

    // Show coach marks for mobile users who haven't seen them
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkShowCoachMarks();
    });
  }

  void _checkShowCoachMarks() {
    // Only show on mobile devices and if user hasn't seen them
    if (_isMobileDevice(context) && !_currentUser.hasSeenCoachMarks) {
      setState(() {
        _showCoachMarks = true;
      });
    }
  }

  void _dismissCoachMarks() async {
    setState(() {
      _showCoachMarks = false;
    });
    // Update Firestore to mark coach marks as seen
    await _userService.markCoachMarksSeen(_currentUser.id);

    // Also update local storage so it persists across sessions
    final updatedUser = _currentUser.copyWith(hasSeenCoachMarks: true);
    final userJson = jsonEncode(updatedUser.toJson());
    await PlatformStorage.setString('sb_squares_user', userJson);
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

    // Listen to version stream for update notifications
    _versionSubscription = _versionService.versionStream().listen(
      (updateAvailable) {
        if (mounted && updateAvailable != _updateAvailable) {
          setState(() {
            _updateAvailable = updateAvailable;
          });
        }
      },
      onError: (error) {
        print('Error in version stream: $error');
      },
    );

    // Listen to user stream for real-time user updates (e.g., numEntries changes)
    _userSubscription = _userService.userStream(_currentUser.id).listen(
      (user) {
        if (mounted && user != null) {
          setState(() {
            _currentUser = user;
          });
        }
      },
      onError: (error) {
        print('Error in user stream: $error');
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
    _versionSubscription?.cancel();
    _userSubscription?.cancel();

    _tabController.dispose();
    super.dispose();
  }

  Future<void> _onSquareTapped(int row, int col, int quarter) async {
    if (_isLoadingSelections) return; // Prevent taps while loading

    // Check if board is locked (numbers have been randomized)
    if (_currentBoardNumbers != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Board is locked. Squares cannot be changed after numbers are drawn.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final key = '$row-$col';
    final selectedSquares = _getQuarterMap(quarter);
    final userName = _currentUser.displayName.isEmpty ? _currentUser.email : _currentUser.displayName;

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
    if (!isDeselecting && _getUserQuarterSelectionCount(quarter) >= _currentUser.numEntries) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You have reached your maximum of ${_currentUser.numEntries} square${_currentUser.numEntries != 1 ? 's' : ''} for this quarter'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // Calculate the next available entry number for this user in this quarter
    final entryNumber = isDeselecting ? 1 : _getNextEntryNumber(quarter, userName);

    // Save to Firestore
    print('Attempting to save selection: Q$quarter, ($row,$col) for user ${_currentUser.id} (entry #$entryNumber)');
    final success = await _selectionService.saveSelection(
      quarter: quarter,
      row: row,
      col: col,
      userId: _currentUser.id,
      userName: userName,
      entryNumber: entryNumber,
    );
    
    print('Save result: $success');
    
    if (!success) {
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
    final userName = _currentUser.displayName.isEmpty ? _currentUser.email : _currentUser.displayName;
    count += q1SelectedSquares.values.where((v) => v.userName == userName).length;
    count += q2SelectedSquares.values.where((v) => v.userName == userName).length;
    count += q3SelectedSquares.values.where((v) => v.userName == userName).length;
    count += q4SelectedSquares.values.where((v) => v.userName == userName).length;
    return count;
  }

  int _getUserQuarterSelectionCount(int quarter) {
    final userName = _currentUser.displayName.isEmpty ? _currentUser.email : _currentUser.displayName;
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
    for (int i = 1; i <= _currentUser.numEntries; i++) {
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

  /// Check if device is mobile (narrow screen)
  bool _isMobileDevice(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }

  /// Reload the page (web only)
  void _reloadPage() {
    if (kIsWeb) {
      reloadWebPage();
    }
  }

  /// Show zoomed quadrant dialog for mobile users
  void _showQuadrantZoom(int quarter, int quadrant, Map<String, SquareSelectionModel> selectedSquares) {
    // Quadrant: 0=top-left, 1=top-right, 2=bottom-left, 3=bottom-right
    final startRow = (quadrant >= 2) ? 5 : 0;
    final startCol = (quadrant % 2 == 1) ? 5 : 0;

    final quadrantNames = ['Top-Left', 'Top-Right', 'Bottom-Left', 'Bottom-Right'];

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.95,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.inversePrimary,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Q$quarter - ${quadrantNames[quadrant]}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                // Zoomed grid
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: AspectRatio(
                      aspectRatio: 1.0,
                      child: _buildZoomedQuadrant(quarter, startRow, startCol, selectedSquares, setDialogState),
                    ),
                  ),
                ),
                // Tap to dismiss hint
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Tap outside or X to close',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build a zoomed 5x5 quadrant view
  Widget _buildZoomedQuadrant(int quarter, int startRow, int startCol, Map<String, SquareSelectionModel> selectedSquares, StateSetter setDialogState) {
    // Get NFL team colors
    final homeColors = NFLTeamColors.getTeamColors(_homeTeamName);
    final awayColors = NFLTeamColors.getTeamColors(_awayTeamName);
    final homePrimary = homeColors?.primary ?? Colors.red.shade700;
    final awayPrimary = awayColors?.primary ?? Colors.blue.shade700;

    return LayoutBuilder(
      builder: (context, constraints) {
        final gridSize = constraints.maxWidth;
        final cellSize = gridSize / 6; // 5 cells + 1 for labels

        return Column(
          children: [
            // Away team numbers header
            Row(
              children: [
                SizedBox(width: cellSize * 0.6, height: cellSize * 0.6), // Corner spacer - matches home team column width
                for (int col = startCol; col < startCol + 5; col++)
                  Container(
                    width: cellSize,
                    height: cellSize * 0.6,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: awayPrimary.withValues(alpha: 0.2),
                      border: Border.all(color: Colors.black),
                    ),
                    child: Text(
                      _currentBoardNumbers != null ? '${awayTeamNumbers[col]}' : '',
                      style: GoogleFonts.rubik(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: awayPrimary,
                      ),
                    ),
                  ),
              ],
            ),
            // Grid rows with home team numbers
            for (int row = startRow; row < startRow + 5; row++)
              Row(
                children: [
                  // Home team number
                  Container(
                    width: cellSize * 0.6,
                    height: cellSize,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: homePrimary.withValues(alpha: 0.2),
                      border: Border.all(color: Colors.black),
                    ),
                    child: Text(
                      _currentBoardNumbers != null ? '${homeTeamNumbers[row]}' : '',
                      style: GoogleFonts.rubik(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: homePrimary,
                      ),
                    ),
                  ),
                  // Cells
                  for (int col = startCol; col < startCol + 5; col++)
                    _buildZoomedCell(row, col, quarter, selectedSquares, cellSize, setDialogState),
                ],
              ),
          ],
        );
      },
    );
  }

  /// Build a single zoomed cell
  Widget _buildZoomedCell(int row, int col, int quarter, Map<String, SquareSelectionModel> selectedSquares, double cellSize, StateSetter setDialogState) {
    final key = '$row-$col';
    final isSelected = selectedSquares.containsKey(key);
    final squareType = _getSquareType(row, col, quarter);
    final selection = selectedSquares[key];
    final squareOwnerName = selection?.userName;
    final entryNumber = selection?.entryNumber ?? 1;

    // Determine the color based on user (same as main grid)
    Color backgroundColor;
    Color borderColor = Colors.black;
    double borderWidth = 1.0;

    if (isSelected && squareOwnerName != null) {
      backgroundColor = UserColorGenerator.getColorForUser(squareOwnerName);
      borderColor = UserColorGenerator.getDarkColorForUser(squareOwnerName);
      final currentUserName = _currentUser.displayName.isEmpty ? _currentUser.email : _currentUser.displayName;
      if (squareOwnerName == currentUserName) {
        backgroundColor = UserColorGenerator.getOwnSquareColor(squareOwnerName);
      }
    } else {
      backgroundColor = Colors.white;
    }

    // Calculate total prize - check each prize independently
    int prizeMoney = 0;

    // Check main winner and adjacent/diagonal prizes
    final winnerPos = _getWinnerPosition(quarter);
    if (winnerPos != null) {
      int dRow = row - winnerPos.row;
      int dCol = col - winnerPos.col;
      if (dRow > 5) dRow -= 10;
      if (dRow < -5) dRow += 10;
      if (dCol > 5) dCol -= 10;
      if (dCol < -5) dCol += 10;

      if (dRow == 0 && dCol == 0) {
        prizeMoney += 2400; // Main winner
      } else if (dRow.abs() <= 1 && dCol.abs() <= 1) {
        if (dRow == 0 || dCol == 0) {
          prizeMoney += 150; // Adjacent
        } else {
          prizeMoney += 100; // Diagonal
        }
      }
    }

    // Check bonus winner (Q2 and Q4 only) - adds to any existing prize
    final bonusPos = _getReverseBonusPosition(quarter);
    if (bonusPos != null && row == bonusPos.row && col == bonusPos.col) {
      prizeMoney += 200;
    }

    const circledNumbers = ['①', '②', '③', '④', '⑤', '⑥', '⑦', '⑧', '⑨', '⑩'];

    return GestureDetector(
      onTap: () async {
        // Handle tap without closing the dialog
        await _onSquareTapped(row, col, quarter);
        // Wait for Firestore stream to update the map
        await Future.delayed(const Duration(milliseconds: 300));
        // Rebuild dialog to show updated state
        setDialogState(() {});
      },
      child: Container(
        width: cellSize,
        height: cellSize,
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: Stack(
          children: [
            // Prize badge
            if (prizeMoney > 0)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '\$$prizeMoney',
                    style: GoogleFonts.rubik(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            // Entry number badge
            if (isSelected && selection != null && _userHasMultipleEntriesInQuarter(quarter, squareOwnerName))
              Positioned(
                bottom: 2,
                left: 2,
                child: Text(
                  entryNumber <= 10 ? circledNumbers[entryNumber - 1] : '$entryNumber',
                  style: TextStyle(
                    fontSize: cellSize * 0.2,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.7),
                        blurRadius: 2,
                        offset: const Offset(0.5, 0.5),
                      ),
                    ],
                  ),
                ),
              ),
            // Owner name
            Center(
              child: isSelected && squareOwnerName != null
                  ? Padding(
                      padding: const EdgeInsets.all(2),
                      child: Text(
                        squareOwnerName,
                        style: TextStyle(
                          fontSize: cellSize * 0.18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 2,
                              offset: const Offset(1, 1),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
  
  /// Get the winner position (row, col) for a quarter, returns null if no winner yet
  ({int row, int col})? _getWinnerPosition(int quarter) {
    final score = _quarterScores.firstWhere(
      (s) => s.quarter == quarter,
      orElse: () => GameScoreModel(id: '', quarter: quarter, homeScore: 0, awayScore: 0),
    );

    if (score.id.isEmpty || _currentBoardNumbers == null) return null;

    final homeScoreDigit = score.homeLastDigit;
    final awayScoreDigit = score.awayLastDigit;

    int? homeRow, awayCol;
    for (int i = 0; i < homeTeamNumbers.length; i++) {
      if (homeTeamNumbers[i] == homeScoreDigit) {
        homeRow = i;
        break;
      }
    }
    for (int i = 0; i < awayTeamNumbers.length; i++) {
      if (awayTeamNumbers[i] == awayScoreDigit) {
        awayCol = i;
        break;
      }
    }

    if (homeRow != null && awayCol != null) {
      return (row: homeRow, col: awayCol);
    }
    return null;
  }

  /// Get the reverse +5 bonus winner position for Q2 and Q4
  ({int row, int col})? _getReverseBonusPosition(int quarter) {
    if (quarter != 2 && quarter != 4) return null;

    final score = _quarterScores.firstWhere(
      (s) => s.quarter == quarter,
      orElse: () => GameScoreModel(id: '', quarter: quarter, homeScore: 0, awayScore: 0),
    );

    if (score.id.isEmpty || _currentBoardNumbers == null) return null;

    final reversedHomeDigit = (score.awayScore + 5) % 10;
    final reversedAwayDigit = (score.homeScore + 5) % 10;

    int? bonusHomeRow, bonusAwayCol;
    for (int i = 0; i < homeTeamNumbers.length; i++) {
      if (homeTeamNumbers[i] == reversedHomeDigit) {
        bonusHomeRow = i;
        break;
      }
    }
    for (int i = 0; i < awayTeamNumbers.length; i++) {
      if (awayTeamNumbers[i] == reversedAwayDigit) {
        bonusAwayCol = i;
        break;
      }
    }

    if (bonusHomeRow != null && bonusAwayCol != null) {
      return (row: bonusHomeRow, col: bonusAwayCol);
    }
    return null;
  }

  /// Get the border for a cell that is part of a winning 3x3 area
  /// Returns thick borders only on the outer edges of the 3x3 area
  /// Note: Only the main winner gets a 3x3 border, bonus winner gets outlined if outside the 3x3
  Border? _getWinningAreaBorder(int row, int col, int quarter, Color borderColor) {
    final winnerPos = _getWinnerPosition(quarter);
    final mainBorder = _getBorderForWinnerArea(row, col, winnerPos, borderColor);

    // Check if this is a reverse bonus winner that's outside the main 3x3 area
    final bonusPos = _getReverseBonusPosition(quarter);
    if (bonusPos != null && row == bonusPos.row && col == bonusPos.col) {
      // Check if bonus is inside the main 3x3 area
      if (winnerPos != null) {
        int dRow = bonusPos.row - winnerPos.row;
        int dCol = bonusPos.col - winnerPos.col;
        if (dRow > 5) dRow -= 10;
        if (dRow < -5) dRow += 10;
        if (dCol > 5) dCol -= 10;
        if (dCol < -5) dCol += 10;

        // If bonus is outside the 3x3 area, give it a full black border
        if (dRow < -1 || dRow > 1 || dCol < -1 || dCol > 1) {
          return Border.all(color: Colors.black, width: 3.0);
        }
      } else {
        // No main winner yet but there's a bonus - give it a border
        return Border.all(color: Colors.black, width: 3.0);
      }
    }

    return mainBorder;
  }

  Border? _getBorderForWinnerArea(int row, int col, ({int row, int col})? winnerPos, Color borderColor) {
    if (winnerPos == null) return null;

    final winRow = winnerPos.row;
    final winCol = winnerPos.col;

    // Calculate position relative to winner (with wrap-around)
    int dRow = row - winRow;
    int dCol = col - winCol;

    // Handle wrap-around: if distance is > 5, it's actually closer on the other side
    if (dRow > 5) dRow -= 10;
    if (dRow < -5) dRow += 10;
    if (dCol > 5) dCol -= 10;
    if (dCol < -5) dCol += 10;

    // Check if this cell is within the 3x3 area (dRow and dCol both in -1, 0, 1)
    if (dRow < -1 || dRow > 1 || dCol < -1 || dCol > 1) return null;

    const thickWidth = 3.0;
    const thinWidth = 0.5;
    final thinBorder = BorderSide(color: Colors.black, width: thinWidth);
    final thickBorder = BorderSide(color: borderColor, width: thickWidth);

    // Determine which edges need thick borders (outer edges of 3x3)
    final topThick = dRow == -1;
    final bottomThick = dRow == 1;
    final leftThick = dCol == -1;
    final rightThick = dCol == 1;

    return Border(
      top: topThick ? thickBorder : thinBorder,
      bottom: bottomThick ? thickBorder : thinBorder,
      left: leftThick ? thickBorder : thinBorder,
      right: rightThick ? thickBorder : thinBorder,
    );
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

    // Check for Reverse +5 bonus winner (Q2 and Q4 only)
    if (quarter == 2 || quarter == 4) {
      // Reverse scores and add 5, then take last digit
      final reversedHomeDigit = (score.awayScore + 5) % 10;
      final reversedAwayDigit = (score.homeScore + 5) % 10;

      // Find grid position for the bonus winner
      int? bonusHomeRow, bonusAwayCol;
      for (int i = 0; i < homeNumbers.length; i++) {
        if (homeNumbers[i] == reversedHomeDigit) {
          bonusHomeRow = i;
          break;
        }
      }
      for (int i = 0; i < awayNumbers.length; i++) {
        if (awayNumbers[i] == reversedAwayDigit) {
          bonusAwayCol = i;
          break;
        }
      }

      if (bonusHomeRow != null && bonusAwayCol != null && row == bonusHomeRow && col == bonusAwayCol) {
        print('🏆 REVERSE +5 BONUS at Grid ($row,$col) - Numbers: ${homeNumbers[row]}-${awayNumbers[col]}');
        return 'reverse_bonus';
      }
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
              _buildInstructionCell('Diagonal\n\$100', Colors.red[200]!),
              _buildInstructionCell('Adjacent\n\$150', Colors.blue[200]!),
              _buildInstructionCell('Diagonal\n\$100', Colors.red[200]!),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInstructionCell('Adjacent\n\$150', Colors.blue[200]!),
              _buildInstructionCell('WINNER\n\$2400', Colors.green[300]!),
              _buildInstructionCell('Adjacent\n\$150', Colors.blue[200]!),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInstructionCell('Diagonal\n\$100', Colors.red[200]!),
              _buildInstructionCell('Adjacent\n\$150', Colors.blue[200]!),
              _buildInstructionCell('Diagonal\n\$100', Colors.red[200]!),
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
    return Stack(
      children: [
        Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Super Bowl Squares - 2026'),
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
          if (_currentUser.isAdmin)
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
          // Update available banner
          if (_updateAvailable)
            Material(
              color: Colors.blue.shade700,
              child: InkWell(
                onTap: () {
                  // Reload the page to get the update
                  if (kIsWeb) {
                    // ignore: avoid_web_libraries_in_flutter
                    // Use JavaScript interop for web reload
                    _reloadPage();
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.system_update, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      const Flexible(
                        child: Text(
                          'Update available! Tap to refresh',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.refresh, color: Colors.white, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          // User info header - moved from AppBar to prevent overflow
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            color: Theme.of(context).colorScheme.inversePrimary.withValues(alpha: 0.1),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _currentUser.displayName.isEmpty 
                        ? 'Welcome!' 
                        : 'Welcome, ${_currentUser.displayName}!',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                Text(
                  '${_getUserSelectionsCount()}/${_currentUser.numEntries * 4} squares',
                  style: TextStyle(
                    fontSize: 14,
                    color: _getUserSelectionsCount() >= _currentUser.numEntries * 4
                        ? Colors.red
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_currentUser.isAdmin)
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
    ),
    if (_showCoachMarks)
      CoachMarkOverlay(
        onDismiss: _dismissCoachMarks,
      ),
    ],
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${_getUserQuarterSelectionCount(quarter)} of ${_currentUser.numEntries} square${_currentUser.numEntries != 1 ? 's' : ''} selected',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  if (_currentBoardNumbers != null) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock, size: 14, color: Colors.red.shade700),
                          const SizedBox(width: 4),
                          Text(
                            'LOCKED',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: AspectRatio(
                  aspectRatio: 1.0,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final double gridSize = constraints.maxWidth;
                    final double cellSize = gridSize / 11;

                    // Get NFL team colors
                    final homeColors = NFLTeamColors.getTeamColors(_homeTeamName);
                    final awayColors = NFLTeamColors.getTeamColors(_awayTeamName);
                    final homePrimary = homeColors?.primary ?? Colors.red.shade700;
                    final homeLight = homeColors?.primary.withValues(alpha: 0.3) ?? Colors.red.shade100;
                    final awayPrimary = awayColors?.primary ?? Colors.blue.shade700;
                    final awayLight = awayColors?.primary.withValues(alpha: 0.3) ?? Colors.blue.shade100;

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Away team label (top, spread horizontally)
                        Positioned(
                          top: cellSize * 0.05,
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
                                      color: awayPrimary,
                                      height: 1.0,
                                    ),
                                  ),
                                ),
                              ).toList(),
                            ),
                          ),
                        ),

                        Positioned(
                          top: cellSize * 0.4,
                          left: cellSize,
                          child: SizedBox(
                            width: cellSize * 10,
                            height: cellSize * 0.6,
                            child: Row(
                              children: [
                                for (int i = 0; i < 10; i++)
                                  Container(
                                    width: cellSize,
                                    height: cellSize * 0.6,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: awayLight,
                                      border: Border.all(color: Colors.black),
                                    ),
                                    child: Text(
                                      _currentBoardNumbers != null ? '${awayTeamNumbers[i]}' : '',
                                      style: GoogleFonts.rubik(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: awayPrimary,
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
                                      color: homePrimary,
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
                          left: cellSize * 0.5,
                          child: SizedBox(
                            width: cellSize * 0.5,
                            height: cellSize * 10,
                            child: Column(
                              children: [
                                for (int i = 0; i < 10; i++)
                                  Container(
                                    width: cellSize * 0.5,
                                    height: cellSize,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: homeLight,
                                      border: Border.all(color: Colors.black),
                                    ),
                                    child: Text(
                                      _currentBoardNumbers != null ? '${homeTeamNumbers[i]}' : '',
                                      style: GoogleFonts.rubik(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: homePrimary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        
                        Positioned(
                          top: cellSize * 0.4,
                          left: cellSize * 0.5,
                          child: Container(
                            width: cellSize * 0.5,
                            height: cellSize * 0.6,
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
                          child: GestureDetector(
                            onLongPressStart: _isMobileDevice(context) ? (details) {
                              // Determine which quadrant was long-pressed
                              final localX = details.localPosition.dx;
                              final localY = details.localPosition.dy;
                              final gridWidth = cellSize * 10;
                              final gridHeight = cellSize * 10;

                              int quadrant;
                              if (localY < gridHeight / 2) {
                                quadrant = localX < gridWidth / 2 ? 0 : 1; // Top-left or top-right
                              } else {
                                quadrant = localX < gridWidth / 2 ? 2 : 3; // Bottom-left or bottom-right
                              }

                              _showQuadrantZoom(quarter, quadrant, selectedSquares);
                            } : null,
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

                                // Use user-specific colors for all squares (including winners)
                                if (isSelected && squareOwnerName != null) {
                                  // Generate a unique color for each user based on their name
                                  backgroundColor = UserColorGenerator.getColorForUser(squareOwnerName);
                                  borderColor = UserColorGenerator.getDarkColorForUser(squareOwnerName);

                                  // If it's the current user's square, make it slightly different
                                  final currentUserName = _currentUser.displayName.isEmpty ? _currentUser.email : _currentUser.displayName;
                                  if (squareOwnerName == currentUserName) {
                                    backgroundColor = UserColorGenerator.getOwnSquareColor(squareOwnerName);
                                  }
                                } else {
                                  backgroundColor = Colors.white;
                                }

                                // Get special border for winning 3x3 area
                                final winningBorder = _getWinningAreaBorder(row, col, quarter, Colors.black);

                                // Calculate total prize - check each prize independently
                                int prizeMoney = 0;

                                // Check main winner and adjacent/diagonal prizes
                                final winnerPos = _getWinnerPosition(quarter);
                                if (winnerPos != null) {
                                  int dRow = row - winnerPos.row;
                                  int dCol = col - winnerPos.col;
                                  if (dRow > 5) dRow -= 10;
                                  if (dRow < -5) dRow += 10;
                                  if (dCol > 5) dCol -= 10;
                                  if (dCol < -5) dCol += 10;

                                  if (dRow == 0 && dCol == 0) {
                                    prizeMoney += 2400; // Main winner
                                  } else if (dRow.abs() <= 1 && dCol.abs() <= 1) {
                                    if (dRow == 0 || dCol == 0) {
                                      prizeMoney += 150; // Adjacent
                                    } else {
                                      prizeMoney += 100; // Diagonal
                                    }
                                  }
                                }

                                // Check bonus winner (Q2 and Q4 only) - adds to any existing prize
                                final bonusPos = _getReverseBonusPosition(quarter);
                                if (bonusPos != null && row == bonusPos.row && col == bonusPos.col) {
                                  prizeMoney += 200;
                                }

                                // Circled number characters for entry badge
                                const circledNumbers = ['①', '②', '③', '④', '⑤', '⑥', '⑦', '⑧', '⑨', '⑩'];

                                final cellContent = Container(
                                  decoration: BoxDecoration(
                                    color: backgroundColor,
                                    border: winningBorder ?? Border.all(
                                      color: borderColor,
                                      width: borderWidth,
                                    ),
                                  ),
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        // Prize badge for winning squares
                                        if (prizeMoney > 0)
                                          Positioned(
                                            top: 2,
                                            right: 2,
                                            child: Container(
                                              padding: const EdgeInsets.all(2),
                                              decoration: BoxDecoration(
                                                color: Colors.black,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                '\$$prizeMoney',
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
                                                    color: Colors.black.withValues(alpha: 0.7),
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
                                                      color: Colors.black.withValues(alpha: 0.5),
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
                                );

                                final cell = GestureDetector(
                                  onTap: () => _onSquareTapped(row, col, quarter),
                                  child: cellContent,
                                );

                                // Only show tooltip on desktop (not mobile) to avoid interfering with long-press
                                if (!_isMobileDevice(context) && squareOwnerName != null) {
                                  return Tooltip(
                                    message: squareOwnerName,
                                    waitDuration: const Duration(milliseconds: 500),
                                    child: cell,
                                  );
                                }
                                return cell;
                              },
                            ),
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
          ],
        ),
      ),
    );
  }
}