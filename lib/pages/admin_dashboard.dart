import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user_model.dart';
import '../models/game_score_model.dart';
import '../models/board_numbers_model.dart';
import '../models/game_config_model.dart';
import '../services/user_service.dart';
import '../services/game_score_service.dart';
import '../services/square_selection_service.dart';
import '../services/board_numbers_service.dart';
import '../services/game_config_service.dart';
import '../widgets/footer_widget.dart';
import '../widgets/user_form_dialog.dart';
import 'welcome_screen.dart';
import 'squares_game_page.dart';

class AdminDashboard extends StatefulWidget {
  final UserModel currentUser;
  
  const AdminDashboard({super.key, required this.currentUser});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final UserService _userService = UserService();
  final GameScoreService _gameScoreService = GameScoreService();
  final SquareSelectionService _selectionService = SquareSelectionService();
  final BoardNumbersService _boardNumbersService = BoardNumbersService();
  final GameConfigService _configService = GameConfigService();
  final TextEditingController _searchController = TextEditingController();
  List<UserModel> _users = [];
  List<UserModel> _filteredUsers = [];
  List<GameScoreModel> _quarterScores = [];
  BoardNumbersModel? _currentBoardNumbers;
  GameConfigModel? _currentConfig;
  bool _isLoading = true;
  String? _error;
  String _sortFilter = 'all'; // 'all', 'paid', 'unpaid'
  String _searchQuery = '';
  
  // Theme-based color scheme
  ColorScheme get _colorScheme => Theme.of(context).colorScheme;
  Color get _primaryColor => _colorScheme.primary;
  Color get _secondaryColor => _colorScheme.secondary;
  Color get _surfaceColor => _colorScheme.surface;
  Color get _errorColor => _colorScheme.error;
  Color get _onSurfaceColor => _colorScheme.onSurface;
  Color get _onSurfaceVariantColor => _colorScheme.onSurfaceVariant;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _applyFilter();
    });
  }

  Future<void> _loadUsers() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      
      final users = await _userService.getAllUsers();
      final quarterScores = await _gameScoreService.getAllQuarterScores();
      final boardNumbers = await _boardNumbersService.getCurrentBoardNumbers();
      final config = await _configService.getCurrentConfig();
      
      setState(() {
        _users = users;
        _quarterScores = quarterScores;
        _currentBoardNumbers = boardNumbers;
        _currentConfig = config;
        _applyFilter();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading data: $e';
        _isLoading = false;
      });
    }
  }

  int get _totalUsers => _users.length;
  int get _paidUsers => _users.where((user) => user.hasPaid).length;
  int get _unpaidUsers => _users.where((user) => !user.hasPaid).length;
  int get _totalEntries => _users.fold(0, (sum, user) => sum + user.numEntries);
  int get _adminUsers => _users.where((user) => user.isAdmin).length;

  void _applyFilter() {
    List<UserModel> filtered = List.from(_users);
    
    // Apply payment status filter
    switch (_sortFilter) {
      case 'paid':
        filtered = filtered.where((user) => user.hasPaid).toList();
        break;
      case 'unpaid':
        filtered = filtered.where((user) => !user.hasPaid).toList();
        break;
      default:
        // Keep all users
        break;
    }
    
    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((user) {
        final displayName = user.displayName.toLowerCase();
        final email = user.email.toLowerCase();
        return displayName.contains(_searchQuery) || email.contains(_searchQuery);
      }).toList();
    }
    
    _filteredUsers = filtered;
  }

  void _updateFilter(String filter) {
    setState(() {
      _sortFilter = filter;
      _applyFilter();
    });
  }

  void _showCreateUserDialog() {
    showDialog(
      context: context,
      builder: (context) => UserFormDialog(
        onUserSaved: _loadUsers,
      ),
    );
  }

  void _showEditUserDialog(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => UserFormDialog(
        user: user,
        onUserSaved: _loadUsers,
      ),
    );
  }

  Future<void> _deleteUser(UserModel user) async {
    // Prevent deleting self
    if (user.id == widget.currentUser.id) {
      _showSnackBar('Cannot delete your own account', isError: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete ${user.displayName.isEmpty ? user.email : user.displayName}?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: _errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _userService.deleteUser(user.id);
      if (success) {
        _showSnackBar('User deleted successfully');
        await _loadUsers();
      } else {
        _showSnackBar('Error deleting user', isError: true);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? _errorColor : _primaryColor,
      ),
    );
  }
  
  void _navigateToWelcome() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WelcomeScreen(user: widget.currentUser),
      ),
    );
  }
  
  void _navigateToGame() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SquaresGamePage(user: widget.currentUser),
      ),
    );
  }

  void _showQuarterScoreDialog(int quarter) {
    final existingScore = _quarterScores.firstWhere(
      (score) => score.quarter == quarter,
      orElse: () => GameScoreModel(
        id: '', 
        quarter: quarter, 
        homeScore: 0, 
        awayScore: 0,
      ),
    );

    showDialog(
      context: context,
      builder: (context) => _QuarterScoreDialog(
        quarter: quarter,
        existingScore: existingScore,
        onScoreSaved: () {
          _loadUsers(); // Reload data
          _showSnackBar('Quarter $quarter score updated');
        },
        gameScoreService: _gameScoreService,
      ),
    );
  }

  void _clearQuarterScore(int quarter) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear Quarter $quarter Score'),
        content: const Text('Are you sure you want to clear this quarter score?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: _errorColor),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _gameScoreService.clearQuarterScore(quarter);
      if (success) {
        _showSnackBar('Quarter $quarter score cleared');
        await _loadUsers();
      } else {
        _showSnackBar('Error clearing quarter score', isError: true);
      }
    }
  }

  void _clearAllQuarterScores() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Quarter Scores'),
        content: const Text(
          'Are you sure you want to clear ALL quarter scores?\n\n'
          'This will remove all scores and winning square highlights.\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: _errorColor),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      bool allSuccess = true;
      
      // Clear all quarters (1-4)
      for (int quarter = 1; quarter <= 4; quarter++) {
        final success = await _gameScoreService.clearQuarterScore(quarter);
        if (!success) {
          allSuccess = false;
        }
      }
      
      if (allSuccess) {
        _showSnackBar('All quarter scores cleared successfully');
        await _loadUsers();
      } else {
        _showSnackBar('Some scores could not be cleared', isError: true);
        await _loadUsers(); // Still reload to show current state
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Admin Dashboard'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sports_football),
            tooltip: 'Play Game',
            onSelected: (value) {
              if (value == 'welcome') {
                _navigateToWelcome();
              } else if (value == 'game') {
                _navigateToGame();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'welcome',
                child: ListTile(
                  leading: Icon(Icons.help_outline),
                  title: Text('Game Instructions'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'game',
                child: ListTile(
                  leading: Icon(Icons.grid_view),
                  title: Text('Play Game'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    widget.currentUser.displayName.isEmpty 
                        ? 'Admin' 
                        : widget.currentUser.displayName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Administrator',
                    style: TextStyle(
                      fontSize: 12,
                      color: _colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Icon(
              Icons.admin_panel_settings,
              color: _secondaryColor,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error, size: 64, color: _errorColor),
                            const SizedBox(height: 16),
                            Text(_error!, style: TextStyle(color: _errorColor)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadUsers,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadUsers,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSummaryList(),
                              const SizedBox(height: 24),
                              _buildTeamNamesSection(),
                              const SizedBox(height: 24),
                              _buildQuarterScoresSection(),
                              const SizedBox(height: 24),
                              _buildBoardNumbersSection(),
                              const SizedBox(height: 24),
                              _buildBoardManagementSection(),
                              const SizedBox(height: 24),
                              _buildUsersTable(),
                            ],
                          ),
                        ),
                      ),
          ),
          const FooterWidget(),
        ],
      ),
    );
  }

  Widget _buildSummaryList() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Game Summary',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text('Total Users: $_totalUsers', style: const TextStyle(fontSize: 16)),
                ),
                Expanded(
                  child: Text('Total Entries: $_totalEntries', style: const TextStyle(fontSize: 16)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Paid: $_paidUsers',
                    style: TextStyle(fontSize: 16, color: _primaryColor),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Unpaid: $_unpaidUsers',
                    style: TextStyle(fontSize: 16, color: _errorColor),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoardNumbersSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Board Numbers',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    if (_currentBoardNumbers == null) ...[
                      ElevatedButton.icon(
                        onPressed: _randomizeBoardNumbers,
                        icon: const Icon(Icons.shuffle, size: 16),
                        label: const Text('Randomize Numbers'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          foregroundColor: _colorScheme.onSecondary,
                        ),
                      ),
                    ] else ...[
                      ElevatedButton.icon(
                        onPressed: _randomizeBoardNumbers,
                        icon: const Icon(Icons.shuffle, size: 16),
                        label: const Text('Re-randomize'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _secondaryColor,
                          foregroundColor: _colorScheme.onSecondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _clearBoardNumbers,
                        icon: const Icon(Icons.clear, size: 16),
                        label: const Text('Clear Numbers'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _secondaryColor,
                          foregroundColor: _colorScheme.onSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_currentBoardNumbers != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _colorScheme.outline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Numbers Randomized',
                      style: GoogleFonts.rubik(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Randomized by: ${_currentBoardNumbers!.randomizedBy}',
                      style: TextStyle(fontSize: 14, color: _onSurfaceVariantColor),
                    ),
                    Text(
                      'Date: ${_currentBoardNumbers!.randomizedAt?.toLocal().toString().split(' ')[0] ?? 'Unknown'}',
                      style: TextStyle(fontSize: 14, color: _onSurfaceVariantColor),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Home Team:',
                                style: GoogleFonts.rubik(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _errorColor,
                                ),
                              ),
                              Text(
                                _currentBoardNumbers!.homeNumbers.join(', '),
                                style: GoogleFonts.rubik(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Away Team:',
                                style: GoogleFonts.rubik(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _secondaryColor,
                                ),
                              ),
                              Text(
                                _currentBoardNumbers!.awayNumbers.join(', '),
                                style: GoogleFonts.rubik(
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
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _colorScheme.outline),
                ),
                child: Row(
                  children: [
                    Icon(Icons.shuffle, color: _colorScheme.onSecondaryContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Numbers Not Yet Randomized',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _colorScheme.onSecondaryContainer,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Players can select squares but numbers are hidden. Randomize when ready.',
                            style: TextStyle(fontSize: 14, color: _onSurfaceVariantColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBoardManagementSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Board Management',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _clearAllBoardSelections,
                      icon: const Icon(Icons.clear_all, size: 16),
                      label: const Text('Clear All Squares'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _secondaryColor,
                        foregroundColor: _colorScheme.onSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _clearAllUsers,
                      icon: const Icon(Icons.delete_forever, size: 16),
                      label: const Text('Clear All Users'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _errorColor,
                        foregroundColor: _colorScheme.onError,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Use this section to manage the game. Clear squares to remove selections, or clear all users to reset the entire system.',
              style: TextStyle(fontSize: 14, color: _onSurfaceVariantColor),
            ),
          ],
        ),
      ),
    );
  }

  void _clearAllBoardSelections() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Square Selections'),
        content: const Text(
          'Are you sure you want to clear ALL square selections from the board?\n\n'
          'This will remove all user selections from all quarters.\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: _errorColor),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _selectionService.clearAllSelections();
      
      if (success) {
        _showSnackBar('All square selections cleared successfully');
      } else {
        _showSnackBar('Failed to clear selections', isError: true);
      }
    }
  }

  void _clearAllUsers() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Users'),
        content: const Text(
          'Are you sure you want to delete ALL users from the system?\n\n'
          'This will permanently delete all user accounts and data.\n\n'
          'WARNING: This action cannot be undone and will remove all users including admins (except yourself).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: _errorColor),
            child: const Text('DELETE ALL USERS'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Show second confirmation
      final doubleConfirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('FINAL CONFIRMATION'),
          content: const Text(
            'This will delete ALL users permanently.\n\n'
            'Are you absolutely sure?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: _errorColor),
              child: const Text('YES, DELETE ALL'),
            ),
          ],
        ),
      );

      if (doubleConfirmed == true) {
        final success = await _userService.clearAllUsers();
        
        if (success) {
          _showSnackBar('All users cleared successfully');
          await _loadUsers();
        } else {
          _showSnackBar('Failed to clear users', isError: true);
        }
      }
    }
  }

  void _randomizeBoardNumbers() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Randomize Board Numbers'),
        content: const Text(
          'This will randomly assign numbers 0-9 to the board.\n\n'
          'Once randomized, all players will be able to see which numbers correspond to their squares.\n\n'
          'Are you sure you want to randomize the board numbers?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
            child: const Text('Randomize Numbers'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _boardNumbersService.randomizeBoardNumbers(
        adminUserId: widget.currentUser.id,
        adminName: widget.currentUser.displayName.isEmpty 
            ? widget.currentUser.email 
            : widget.currentUser.displayName,
      );
      
      if (success) {
        _showSnackBar('Board numbers randomized successfully!');
        await _loadUsers(); // Reload to get updated board numbers
      } else {
        _showSnackBar('Failed to randomize board numbers', isError: true);
      }
    }
  }

  void _clearBoardNumbers() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Board Numbers'),
        content: const Text(
          'This will remove the current number randomization.\n\n'
          'The board will go back to showing "?" instead of numbers.\n\n'
          'Are you sure you want to clear the board numbers?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: _secondaryColor),
            child: const Text('Clear Numbers'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _boardNumbersService.clearBoardNumbers();
      
      if (success) {
        _showSnackBar('Board numbers cleared successfully');
        await _loadUsers(); // Reload to get updated state
      } else {
        _showSnackBar('Failed to clear board numbers', isError: true);
      }
    }
  }

  Widget _buildTeamNamesSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Team Names',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _colorScheme.outline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Home Team',
                          style: TextStyle(
                            fontSize: 12,
                            color: _colorScheme.onErrorContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentConfig?.homeTeamName ?? 'AFC',
                          style: GoogleFonts.rubik(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _colorScheme.onErrorContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _colorScheme.outline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Away Team',
                          style: TextStyle(
                            fontSize: 12,
                            color: _colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentConfig?.awayTeamName ?? 'NFC',
                          style: GoogleFonts.rubik(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _showEditTeamNamesDialog,
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit Teams'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _colorScheme.tertiary,
                        foregroundColor: _colorScheme.onTertiary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_currentConfig == null)
                      ElevatedButton.icon(
                        onPressed: _forceCreateConfig,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Create Config'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _secondaryColor,
                          foregroundColor: _colorScheme.onSecondary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _forceCreateConfig() async {
    _showSnackBar('Creating config collection...', isError: false);
    
    try {
      await _configService.forceInitializeConfig();
      _showSnackBar('Config collection created successfully!');
      await _loadUsers(); // Reload to show the new config
    } catch (e) {
      _showSnackBar('Failed to create config: $e', isError: true);
    }
  }

  void _showEditTeamNamesDialog() {
    final homeController = TextEditingController(text: _currentConfig?.homeTeamName ?? 'AFC');
    final awayController = TextEditingController(text: _currentConfig?.awayTeamName ?? 'NFC');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Team Names'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: homeController,
              decoration: InputDecoration(
                labelText: 'Home Team Name',
                hintText: 'e.g., AFC, Steelers',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.home, color: _colorScheme.onErrorContainer),
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 20,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: awayController,
              decoration: InputDecoration(
                labelText: 'Away Team Name',
                hintText: 'e.g., NFC, Cowboys',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.flight_takeoff, color: _colorScheme.onSecondaryContainer),
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 20,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final homeTeam = homeController.text.trim();
              final awayTeam = awayController.text.trim();
              
              if (!_configService.validateTeamNames(homeTeam, awayTeam)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Team names must be between 1-20 characters'),
                    backgroundColor: _errorColor,
                  ),
                );
                return;
              }
              
              Navigator.of(context).pop();
              
              final success = await _configService.updateTeamNames(
                homeTeamName: homeTeam,
                awayTeamName: awayTeam,
                updatedBy: widget.currentUser.displayName.isEmpty 
                    ? widget.currentUser.email 
                    : widget.currentUser.displayName,
              );
              
              if (success) {
                _showSnackBar('Team names updated successfully!');
                await _loadUsers();
              } else {
                _showSnackBar('Failed to update team names', isError: true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _colorScheme.tertiary),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuarterWinnersInfo(int quarter, GameScoreModel score) {
    return FutureBuilder<Map<String, List<String>>>(
      future: _getQuarterWinners(quarter, score),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }
        
        if (snapshot.hasError) {
          return Text(
            'Error loading winners',
            style: TextStyle(fontSize: 10, color: _errorColor),
          );
        }
        
        final winners = snapshot.data ?? {};
        if (winners.isEmpty) {
          return Text(
            'No winners found',
            style: TextStyle(fontSize: 10, color: _onSurfaceVariantColor),
          );
        }

        return Column(
      children: [
        // Winner (Main prize)
        if (winners['winner'] != null && winners['winner']!.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: _colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '🏆 ${winners['winner']!.first} - \$2400',
              style: GoogleFonts.rubik(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: _colorScheme.onPrimaryContainer,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        
        const SizedBox(height: 2),
        
        // Adjacent winners
        if (winners['adjacent'] != null && winners['adjacent']!.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: _colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              children: [
                Text(
                  '📍 Adjacent Winners (\$150 each)',
                  style: GoogleFonts.rubik(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _colorScheme.onTertiaryContainer,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Column(
                  children: winners['adjacent']!.map<Widget>((winner) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Text(
                      winner,
                      style: GoogleFonts.rubik(
                        fontSize: 9,
                        color: _colorScheme.onTertiaryContainer,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )).toList(),
                ),
              ],
            ),
          ),
        
        const SizedBox(height: 2),
        
        // Diagonal winners
        if (winners['diagonal'] != null && winners['diagonal']!.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: _colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              children: [
                Text(
                  '🔷 Diagonal Winners (\$100 each)',
                  style: GoogleFonts.rubik(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _colorScheme.onSecondaryContainer,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Column(
                  children: winners['diagonal']!.map<Widget>((winner) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Text(
                      winner,
                      style: GoogleFonts.rubik(
                        fontSize: 9,
                        color: _colorScheme.onSecondaryContainer,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )).toList(),
                ),
              ],
            ),
          ),
        
        const SizedBox(height: 2),
        
        // Total payout
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: _colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '💰 Total: \$${_calculateTotalPayout(winners)}',
            style: GoogleFonts.rubik(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: _colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
      },
    );
  }

  Future<Map<String, List<String>>> _getQuarterWinners(int quarter, GameScoreModel score) async {
    final winners = {
      'winner': <String>[],
      'adjacent': <String>[],
      'diagonal': <String>[],
    };

    if (score.id.isEmpty || _currentBoardNumbers == null) return winners;

    // Get the last digits from the score
    final homeScoreDigit = score.homeLastDigit;
    final awayScoreDigit = score.awayLastDigit;
    
    // Find the grid coordinates that correspond to these score digits
    final homeNumbers = _currentBoardNumbers!.homeNumbers;
    final awayNumbers = _currentBoardNumbers!.awayNumbers;
    
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
    if (homeRow != null && awayCol != null) {
      print('🎯 Q$quarter Admin: Winner at Grid ($homeRow,$awayCol) for score ${score.homeScore}-${score.awayScore}');
    }
    
    if (homeRow == null || awayCol == null) {
      // Score digits not found in board numbers - shouldn't happen
      return winners;
    }

    // Fetch all selections for this quarter
    final quarterSelections = await _selectionService.getQuarterSelections(quarter);
    
    // Create a map of grid coordinates to user names
    final Map<String, String> squareOwners = {};
    for (final selection in quarterSelections) {
      final key = '${selection.row}-${selection.col}';
      squareOwners[key] = selection.userName;
    }

    // The winning square grid coordinate
    final winningSquare = '$homeRow-$awayCol';
    final winnerName = squareOwners[winningSquare];
    if (winnerName != null) {
      winners['winner']!.add('$winnerName ($homeScoreDigit-$awayScoreDigit)');
    } else {
      winners['winner']!.add('No owner ($homeScoreDigit-$awayScoreDigit)');
    }
    
    // Calculate adjacent squares (wrapping around edges)
    final adjacentSquares = [
      '${(homeRow + 1) % 10}-$awayCol',     // down
      '${(homeRow - 1 + 10) % 10}-$awayCol', // up
      '$homeRow-${(awayCol + 1) % 10}',     // right
      '$homeRow-${(awayCol - 1 + 10) % 10}', // left
    ];
    
    // Calculate diagonal squares (wrapping around edges)
    final diagonalSquares = [
      '${(homeRow + 1) % 10}-${(awayCol + 1) % 10}',        // down-right
      '${(homeRow + 1) % 10}-${(awayCol - 1 + 10) % 10}',   // down-left
      '${(homeRow - 1 + 10) % 10}-${(awayCol + 1) % 10}',   // up-right
      '${(homeRow - 1 + 10) % 10}-${(awayCol - 1 + 10) % 10}', // up-left
    ];

    // Convert grid coordinates to display format with actual user names
    winners['adjacent'] = adjacentSquares.map((gridCoord) {
      final parts = gridCoord.split('-');
      final row = int.parse(parts[0]);
      final col = int.parse(parts[1]);
      final homeNum = homeNumbers[row];
      final awayNum = awayNumbers[col];
      final ownerName = squareOwners[gridCoord];
      if (ownerName != null) {
        return '$ownerName ($homeNum-$awayNum)';
      } else {
        return 'No owner ($homeNum-$awayNum)';
      }
    }).toList();
    
    winners['diagonal'] = diagonalSquares.map((gridCoord) {
      final parts = gridCoord.split('-');
      final row = int.parse(parts[0]);
      final col = int.parse(parts[1]);
      final homeNum = homeNumbers[row];
      final awayNum = awayNumbers[col];
      final ownerName = squareOwners[gridCoord];
      if (ownerName != null) {
        return '$ownerName ($homeNum-$awayNum)';
      } else {
        return 'No owner ($homeNum-$awayNum)';
      }
    }).toList();

    return winners;
  }

  int _calculateTotalPayout(Map<String, List<String>> winners) {
    int total = 0; // Calculate total payout for winners
    total += (winners['winner']?.length ?? 0) * 2400; // Winner: $2400 each
    total += (winners['adjacent']?.length ?? 0) * 150; // Adjacent: $150 each
    total += (winners['diagonal']?.length ?? 0) * 100; // Diagonal: $100 each
    return total;
  }

  Widget _buildQuarterScoresSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Quarter Scores & Winners',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: _clearAllQuarterScores,
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: const Text('Clear All Scores'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _secondaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4, // Back to 4 columns for smaller boxes
                childAspectRatio: 0.6, // Much taller to accommodate winner details
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: 4,
              itemBuilder: (context, index) {
                final quarter = index + 1;
                final score = _quarterScores.firstWhere(
                  (s) => s.quarter == quarter,
                  orElse: () => GameScoreModel(
                    id: '', 
                    quarter: quarter, 
                    homeScore: 0, 
                    awayScore: 0,
                  ),
                );
                final hasScore = score.id.isNotEmpty;

                return Card(
                  elevation: 1,
                  color: hasScore ? _colorScheme.primaryContainer : _colorScheme.surfaceVariant,
                  child: InkWell(
                    onTap: () => _showQuarterScoreDialog(quarter),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          Text(
                            'Q$quarter',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (hasScore) ...[
                            Text(
                              'Home: ${score.homeScore}',
                              style: GoogleFonts.rubik(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'Away: ${score.awayScore}',
                              style: GoogleFonts.rubik(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Winner: ${score.homeLastDigit}-${score.awayLastDigit}',
                              style: GoogleFonts.rubik(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _primaryColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Expanded(
                              child: SingleChildScrollView(
                                child: _buildQuarterWinnersInfo(quarter, score),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 16),
                                  onPressed: () => _showQuarterScoreDialog(quarter),
                                  tooltip: 'Edit Score',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () => _clearQuarterScore(quarter),
                                  tooltip: 'Clear Score',
                                ),
                              ],
                            ),
                          ] else ...[
                            Icon(
                              Icons.add_circle_outline,
                              size: 28,
                              color: _onSurfaceVariantColor,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Set Score',
                              style: TextStyle(
                                fontSize: 14,
                                color: _onSurfaceVariantColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'User Details',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search users...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text('Filter: ', style: TextStyle(fontSize: 16, color: _onSurfaceVariantColor)),
                DropdownButton<String>(
                  value: _sortFilter,
                  onChanged: (value) => _updateFilter(value!),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Users')),
                    DropdownMenuItem(value: 'paid', child: Text('Paid Only')),
                    DropdownMenuItem(value: 'unpaid', child: Text('Unpaid Only')),
                  ],
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _showCreateUserDialog,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Create User'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: _colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _loadUsers,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Display Name')),
                DataColumn(label: Text('Email')),
                DataColumn(label: Text('Entries')),
                DataColumn(label: Text('Paid')),
                DataColumn(label: Text('Admin')),
                DataColumn(label: Text('Created')),
                DataColumn(label: Text('Actions')),
              ],
              rows: _filteredUsers.map((user) {
                return DataRow(
                  cells: [
                    DataCell(Text(user.displayName.isEmpty ? '-' : user.displayName)),
                    DataCell(Text(user.email)),
                    DataCell(Text(user.numEntries.toString())),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: user.hasPaid ? _primaryColor : _errorColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          user.hasPaid ? 'Paid' : 'Unpaid',
                          style: TextStyle(
                            color: _colorScheme.onPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      user.isAdmin 
                          ? Icon(Icons.admin_panel_settings, color: _secondaryColor, size: 20)
                          : const Text('-'),
                    ),
                    DataCell(
                      Text(
                        user.createdAt != null 
                            ? '${user.createdAt!.month}/${user.createdAt!.day}/${user.createdAt!.year}'
                            : '-',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => _showEditUserDialog(user),
                            icon: const Icon(Icons.edit, size: 20),
                            tooltip: 'Edit User',
                            color: _secondaryColor,
                          ),
                          IconButton(
                            onPressed: user.id == widget.currentUser.id 
                                ? null 
                                : () => _deleteUser(user),
                            icon: const Icon(Icons.delete, size: 20),
                            tooltip: user.id == widget.currentUser.id 
                                ? 'Cannot delete self' 
                                : 'Delete User',
                            color: user.id == widget.currentUser.id 
                                ? _onSurfaceVariantColor 
                                : _errorColor,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _QuarterScoreDialog extends StatefulWidget {
  final int quarter;
  final GameScoreModel existingScore;
  final VoidCallback onScoreSaved;
  final GameScoreService gameScoreService;

  const _QuarterScoreDialog({
    required this.quarter,
    required this.existingScore,
    required this.onScoreSaved,
    required this.gameScoreService,
  });

  @override
  State<_QuarterScoreDialog> createState() => _QuarterScoreDialogState();
}

class _QuarterScoreDialogState extends State<_QuarterScoreDialog> {
  final _formKey = GlobalKey<FormState>();
  final _homeScoreController = TextEditingController();
  final _awayScoreController = TextEditingController();
  bool _isLoading = false;

  // Theme-based color scheme
  ColorScheme get _colorScheme => Theme.of(context).colorScheme;
  Color get _primaryColor => _colorScheme.primary;
  Color get _errorColor => _colorScheme.error;
  Color get _onSurfaceVariantColor => _colorScheme.onSurfaceVariant;

  @override
  void initState() {
    super.initState();
    if (widget.existingScore.id.isNotEmpty) {
      _homeScoreController.text = widget.existingScore.homeScore.toString();
      _awayScoreController.text = widget.existingScore.awayScore.toString();
    }
  }

  @override
  void dispose() {
    _homeScoreController.dispose();
    _awayScoreController.dispose();
    super.dispose();
  }

  Future<void> _saveScore() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final homeScore = int.parse(_homeScoreController.text);
      final awayScore = int.parse(_awayScoreController.text);

      final success = await widget.gameScoreService.setQuarterScore(
        quarter: widget.quarter,
        homeScore: homeScore,
        awayScore: awayScore,
      );

      if (success) {
        widget.onScoreSaved();
        Navigator.of(context).pop();
      } else {
        _showError('Failed to save score');
      }
    } catch (e) {
      _showError('Error saving score: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _errorColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final homeScore = int.tryParse(_homeScoreController.text) ?? 0;
    final awayScore = int.tryParse(_awayScoreController.text) ?? 0;
    final homeDigit = homeScore % 10;
    final awayDigit = awayScore % 10;

    return AlertDialog(
      title: Text('Quarter ${widget.quarter} Score'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _homeScoreController,
                      decoration: const InputDecoration(
                        labelText: 'Home Score',
                        prefixIcon: Icon(Icons.home),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Required';
                        }
                        final num = int.tryParse(value.trim());
                        if (num == null || num < 0) {
                          return 'Valid number >= 0';
                        }
                        return null;
                      },
                      onChanged: (value) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _awayScoreController,
                      decoration: const InputDecoration(
                        labelText: 'Away Score',
                        prefixIcon: Icon(Icons.flight_takeoff),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Required';
                        }
                        final num = int.tryParse(value.trim());
                        if (num == null || num < 0) {
                          return 'Valid number >= 0';
                        }
                        return null;
                      },
                      onChanged: (value) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_homeScoreController.text.isNotEmpty && _awayScoreController.text.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _colorScheme.outline),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Winning Combination',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Home: $homeScore (last digit: $homeDigit)',
                        style: const TextStyle(fontSize: 14),
                      ),
                      Text(
                        'Away: $awayScore (last digit: $awayDigit)',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Winning Square: $homeDigit-$awayDigit',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _primaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Payouts: Winner \$2,400 | Adjacent \$150 | Diagonal \$100',
                        style: TextStyle(fontSize: 12, color: _onSurfaceVariantColor),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveScore,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save Score'),
        ),
      ],
    );
  }
}