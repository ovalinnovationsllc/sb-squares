import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user_model.dart';
import '../models/game_score_model.dart';
import '../models/square_selection_model.dart';
import '../services/game_score_service.dart';
import '../services/square_selection_service.dart';
import '../widgets/footer_widget.dart';
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
  final List<int> awayTeamNumbers = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
  final List<int> homeTeamNumbers = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
  
  // Separate selected squares for each quarter
  final Map<String, String> q1SelectedSquares = {};
  final Map<String, String> q2SelectedSquares = {};
  final Map<String, String> q3SelectedSquares = {};
  final Map<String, String> q4SelectedSquares = {};
  
  bool _isLoadingSelections = true;
  
  // Quarter scores for highlighting winners
  List<GameScoreModel> _quarterScores = [];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadQuarterScores();
    _loadSelections();
  }
  
  Future<void> _loadQuarterScores() async {
    try {
      final scores = await _gameScoreService.getAllQuarterScores();
      setState(() {
        _quarterScores = scores;
      });
    } catch (e) {
      print('Error loading quarter scores: $e');
    }
  }
  
  Future<void> _loadSelections() async {
    setState(() => _isLoadingSelections = true);
    
    try {
      final allSelections = await _selectionService.getAllSelections();
      
      print('Loaded selections from Firestore:');
      print('Q1: ${allSelections[1]?.length ?? 0} selections');
      print('Q2: ${allSelections[2]?.length ?? 0} selections');
      print('Q3: ${allSelections[3]?.length ?? 0} selections');
      print('Q4: ${allSelections[4]?.length ?? 0} selections');
      
      setState(() {
        // Clear existing selections
        q1SelectedSquares.clear();
        q2SelectedSquares.clear();
        q3SelectedSquares.clear();
        q4SelectedSquares.clear();
        
        // Load selections for each quarter
        for (final selection in allSelections[1] ?? []) {
          q1SelectedSquares[selection.squareKey] = selection.userName;
          print('Q1: Adding ${selection.userName} at ${selection.squareKey}');
        }
        for (final selection in allSelections[2] ?? []) {
          q2SelectedSquares[selection.squareKey] = selection.userName;
          print('Q2: Adding ${selection.userName} at ${selection.squareKey}');
        }
        for (final selection in allSelections[3] ?? []) {
          q3SelectedSquares[selection.squareKey] = selection.userName;
          print('Q3: Adding ${selection.userName} at ${selection.squareKey}');
        }
        for (final selection in allSelections[4] ?? []) {
          q4SelectedSquares[selection.squareKey] = selection.userName;
          print('Q4: Adding ${selection.userName} at ${selection.squareKey}');
        }
        
        _isLoadingSelections = false;
      });
    } catch (e) {
      print('Error loading selections: $e');
      setState(() => _isLoadingSelections = false);
    }
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onSquareTapped(int row, int col, int quarter) async {
    if (_isLoadingSelections) return; // Prevent taps while loading
    
    // Check if user has paid - if not, show payment required message
    if (!widget.user.hasPaid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment required to select squares. Please contact admin to activate your account.'),
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
    if (selectedSquares.containsKey(key) && selectedSquares[key] != userName) {
      // Square is taken by someone else, show message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('This square is already taken by ${selectedSquares[key]}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    
    // Check if user is trying to select a new square (not deselecting)
    final isDeselecting = selectedSquares.containsKey(key) && selectedSquares[key] == userName;
    
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
    
    // Save to Firestore
    print('Attempting to save selection: Q$quarter, ($row,$col) for user ${widget.user.id}');
    final success = await _selectionService.saveSelection(
      quarter: quarter,
      row: row,
      col: col,
      userId: widget.user.id,
      userName: userName,
    );
    
    print('Save result: $success');
    
    if (success) {
      // Reload selections to ensure sync with Firestore
      await _loadSelections();
      
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
  
  Map<String, String> _getQuarterMap(int quarter) {
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
    count += q1SelectedSquares.values.where((v) => v == userName).length;
    count += q2SelectedSquares.values.where((v) => v == userName).length;
    count += q3SelectedSquares.values.where((v) => v == userName).length;
    count += q4SelectedSquares.values.where((v) => v == userName).length;
    return count;
  }
  
  int _getUserQuarterSelectionCount(int quarter) {
    final userName = widget.user.displayName.isEmpty ? widget.user.email : widget.user.displayName;
    final selectedSquares = _getQuarterMap(quarter);
    return selectedSquares.values.where((v) => v == userName).length;
  }
  
  String _getSquareType(int row, int col, int quarter) {
    // Find the score for this quarter
    final score = _quarterScores.firstWhere(
      (s) => s.quarter == quarter,
      orElse: () => GameScoreModel(id: '', quarter: quarter, homeScore: 0, awayScore: 0),
    );
    
    if (score.id.isEmpty) return 'normal'; // No score set yet
    
    final homeDigit = score.homeLastDigit;
    final awayDigit = score.awayLastDigit;
    
    // Check if this is the winning square
    if (row == homeDigit && col == awayDigit) {
      return 'winner';
    }
    
    // Check if this is an adjacent square (up, down, left, right)
    if ((row == (homeDigit + 1) % 10 && col == awayDigit) || // down
        (row == (homeDigit - 1 + 10) % 10 && col == awayDigit) || // up
        (row == homeDigit && col == (awayDigit + 1) % 10) || // right
        (row == homeDigit && col == (awayDigit - 1 + 10) % 10)) { // left
      return 'adjacent';
    }
    
    // Check if this is a diagonal square
    if ((row == (homeDigit + 1) % 10 && col == (awayDigit + 1) % 10) || // down-right
        (row == (homeDigit + 1) % 10 && col == (awayDigit - 1 + 10) % 10) || // down-left
        (row == (homeDigit - 1 + 10) % 10 && col == (awayDigit + 1) % 10) || // up-right
        (row == (homeDigit - 1 + 10) % 10 && col == (awayDigit - 1 + 10) % 10)) { // up-left
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
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(16.0),
          child: Column(
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
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Column(
                                  children: [
                                    Text(
                                      'Winning score:',
                                      style: TextStyle(color: Colors.white, fontSize: 12),
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
                                Column(
                                  children: [
                                    Text(
                                      'Adjacent box:',
                                      style: TextStyle(color: Colors.white, fontSize: 12),
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
                                Column(
                                  children: [
                                    Text(
                                      'Diagonal box:',
                                      style: TextStyle(color: Colors.white, fontSize: 12),
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
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Cost \$150 per box - paying out large money! WINNERS ALL OVER',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
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
    return Container(
      width: 70,
      height: 50,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: Colors.black, width: 1),
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Super Bowl Squares'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '1st Quarter'),
            Tab(text: '2nd Quarter'),
            Tab(text: '3rd Quarter'),
            Tab(text: '4th Quarter'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () async {
              await _loadQuarterScores();
              await _loadSelections();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Board refreshed'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed: _showInstructions,
            icon: const Icon(Icons.help_outline),
            tooltip: 'Game Instructions',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    widget.user.displayName.isEmpty 
                        ? 'Welcome!' 
                        : widget.user.displayName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    widget.user.hasPaid 
                        ? 'Selections: ${_getUserSelectionsCount()}/${widget.user.numEntries * 4}'
                        : 'Payment Required',
                    style: TextStyle(
                      fontSize: 12,
                      color: !widget.user.hasPaid
                          ? Colors.orange.shade300
                          : _getUserSelectionsCount() >= widget.user.numEntries * 4
                              ? Colors.red 
                              : Colors.white70,
                      fontWeight: !widget.user.hasPaid ? FontWeight.bold : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.user.isAdmin)
            const Padding(
              padding: EdgeInsets.only(right: 8.0),
              child: Icon(
                Icons.admin_panel_settings,
                color: Colors.amber,
              ),
            ),
        ],
      ),
      body: Column(
        children: [
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
                                      style: GoogleFonts.rubik(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.blue.shade700,
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
                                      style: GoogleFonts.rubik(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.red.shade700,
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
                                  style: GoogleFonts.rubik(
                                    fontSize: cellSize * 0.15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                                Text(
                                  'HOME',
                                  style: GoogleFonts.rubik(
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
                                final squareType = _getSquareType(row, col, quarter);
                                
                                // Determine the color based on square type
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
                                  backgroundColor = isSelected ? Colors.green.shade200 : Colors.white;
                                }
                                
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
                                        Center(
                                          child: isSelected 
                                            ? Text(
                                                selectedSquares[key]!,
                                                style: TextStyle(
                                                  fontSize: cellSize * 0.15,
                                                  fontWeight: FontWeight.w500,
                                                  color: squareType != 'normal' 
                                                    ? Colors.white 
                                                    : Colors.black,
                                                ),
                                                textAlign: TextAlign.center,
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