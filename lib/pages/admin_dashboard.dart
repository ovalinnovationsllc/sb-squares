import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user_model.dart';
import '../models/game_score_model.dart';
import '../services/user_service.dart';
import '../services/game_score_service.dart';
import '../services/square_selection_service.dart';
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
  final TextEditingController _searchController = TextEditingController();
  List<UserModel> _users = [];
  List<UserModel> _filteredUsers = [];
  List<GameScoreModel> _quarterScores = [];
  bool _isLoading = true;
  String? _error;
  String _sortFilter = 'all'; // 'all', 'paid', 'unpaid'
  String _searchQuery = '';

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
      
      setState(() {
        _users = users;
        _quarterScores = quarterScores;
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
        backgroundColor: isError ? Colors.red : Colors.green,
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
                  const Text(
                    'Administrator',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error, size: 64, color: Colors.red),
                            const SizedBox(height: 16),
                            Text(_error!, style: const TextStyle(color: Colors.red)),
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
                              _buildQuarterScoresSection(),
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
                    style: const TextStyle(fontSize: 16, color: Colors.green),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Unpaid: $_unpaidUsers',
                    style: const TextStyle(fontSize: 16, color: Colors.red),
                  ),
                ),
              ],
            ),
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
                        backgroundColor: Colors.deepOrange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _clearAllUsers,
                      icon: const Icon(Icons.delete_forever, size: 16),
                      label: const Text('Clear All Users'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Use this section to manage the game. Clear squares to remove selections, or clear all users to reset the entire system.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
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
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900),
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
                    backgroundColor: Colors.orange,
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
                crossAxisCount: 4,
                childAspectRatio: 1.2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
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
                  color: hasScore ? Colors.green.shade50 : Colors.grey.shade100,
                  child: InkWell(
                    onTap: () => _showQuarterScoreDialog(quarter),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Q$quarter',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (hasScore) ...[
                            Text(
                              'Home: ${score.homeScore}',
                              style: GoogleFonts.rubik(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'Away: ${score.awayScore}',
                              style: GoogleFonts.rubik(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Winner: ${score.homeLastDigit}-${score.awayLastDigit}',
                              style: GoogleFonts.rubik(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
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
                            const Icon(
                              Icons.add_circle_outline,
                              size: 32,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Set Score',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
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
                Text('Filter: ', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
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
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
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
                          color: user.hasPaid ? Colors.green : Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          user.hasPaid ? 'Paid' : 'Unpaid',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      user.isAdmin 
                          ? const Icon(Icons.admin_panel_settings, color: Colors.amber, size: 20)
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
                            color: Colors.blue,
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
                                ? Colors.grey 
                                : Colors.red,
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
        backgroundColor: Colors.red,
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
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
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
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Payouts: Winner \$2,400 | Adjacent \$150 | Diagonal \$100',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
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