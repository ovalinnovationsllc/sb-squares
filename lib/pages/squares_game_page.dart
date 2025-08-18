import 'package:flutter/material.dart';
import '../models/user_model.dart';
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
  final List<int> awayTeamNumbers = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
  final List<int> homeTeamNumbers = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
  
  // Separate selected squares for each quarter
  final Map<String, String> q1SelectedSquares = {};
  final Map<String, String> q2SelectedSquares = {};
  final Map<String, String> q3SelectedSquares = {};
  final Map<String, String> q4SelectedSquares = {};
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onSquareTapped(int row, int col, int quarter) {
    final key = '$row-$col';
    final selectedSquares = _getQuarterMap(quarter);
    
    setState(() {
      // Check if user has already selected a square for this quarter
      if (selectedSquares.values.contains(widget.user.displayName.isEmpty ? widget.user.email : widget.user.displayName)) {
        // Remove their previous selection
        selectedSquares.removeWhere((k, v) => v == (widget.user.displayName.isEmpty ? widget.user.email : widget.user.displayName));
      }
      
      // Toggle the current square
      if (selectedSquares.containsKey(key)) {
        // If clicking on an already selected square by this user, deselect it
        if (selectedSquares[key] == (widget.user.displayName.isEmpty ? widget.user.email : widget.user.displayName)) {
          selectedSquares.remove(key);
        }
      } else {
        // Select the new square
        selectedSquares[key] = widget.user.displayName.isEmpty 
            ? widget.user.email 
            : widget.user.displayName;
      }
    });
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
    if (q1SelectedSquares.values.contains(userName)) count++;
    if (q2SelectedSquares.values.contains(userName)) count++;
    if (q3SelectedSquares.values.contains(userName)) count++;
    if (q4SelectedSquares.values.contains(userName)) count++;
    return count;
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
                        'BUY A 2025 SUPER BOWL SQUARE - PLAY TO GET PAID',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '* 12th year running *',
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
                    'Selections: ${_getUserSelectionsCount()}/${widget.user.numEntries * 4}',
                    style: TextStyle(
                      fontSize: 12,
                      color: _getUserSelectionsCount() >= widget.user.numEntries * 4
                          ? Colors.red 
                          : Colors.white70,
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
    final selectedSquares = _getQuarterMap(quarter);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                'Quarter $quarter - ${selectedSquares.values.where((v) => v == (widget.user.displayName.isEmpty ? widget.user.email : widget.user.displayName)).length} of ${widget.user.numEntries} box${widget.user.numEntries != 1 ? 'es' : ''} selected',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
                                  onTap: () => _onSquareTapped(row, col, quarter),
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
          ],
        ),
      ),
    );
  }
}