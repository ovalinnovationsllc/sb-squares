import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import '../widgets/footer_widget.dart';
import '../widgets/user_form_dialog.dart';

class AdminDashboard extends StatefulWidget {
  final UserModel currentUser;
  
  const AdminDashboard({super.key, required this.currentUser});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final UserService _userService = UserService();
  List<UserModel> _users = [];
  List<UserModel> _filteredUsers = [];
  bool _isLoading = true;
  String? _error;
  String _sortFilter = 'all'; // 'all', 'paid', 'unpaid'

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      
      final users = await _userService.getAllUsers();
      
      setState(() {
        _users = users;
        _applyFilter();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading users: $e';
        _isLoading = false;
      });
    }
  }

  int get _totalUsers => _users.length;
  int get _paidUsers => _users.where((user) => user.isPaid).length;
  int get _unpaidUsers => _users.where((user) => !user.isPaid).length;
  int get _totalEntries => _users.fold(0, (sum, user) => sum + user.numEntries);
  int get _adminUsers => _users.where((user) => user.isAdmin).length;

  void _applyFilter() {
    switch (_sortFilter) {
      case 'paid':
        _filteredUsers = _users.where((user) => user.isPaid).toList();
        break;
      case 'unpaid':
        _filteredUsers = _users.where((user) => !user.isPaid).toList();
        break;
      default:
        _filteredUsers = List.from(_users);
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Admin Dashboard'),
        centerTitle: true,
        actions: [
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
                          color: user.isPaid ? Colors.green : Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          user.isPaid ? 'Paid' : 'Unpaid',
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
                        user.created != null 
                            ? '${user.created!.month}/${user.created!.day}/${user.created!.year}'
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