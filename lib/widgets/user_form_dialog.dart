import 'package:flutter/material.dart';
import '../config/security_config.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';

class UserFormDialog extends StatefulWidget {
  final UserModel? user; // null for create, non-null for edit
  final VoidCallback onUserSaved;

  const UserFormDialog({
    super.key,
    this.user,
    required this.onUserSaved,
  });

  @override
  State<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _numEntriesController = TextEditingController();
  
  bool _isAdmin = false;
  bool _hasPaid = false;
  bool _isLoading = false;
  
  final UserService _userService = UserService();

  @override
  void initState() {
    super.initState();
    if (widget.user != null) {
      // Pre-fill form for editing
      _emailController.text = widget.user!.email;
      _displayNameController.text = widget.user!.displayName;
      _numEntriesController.text = widget.user!.numEntries.toString();
      _isAdmin = widget.user!.isAdmin;
      _hasPaid = widget.user!.hasPaid;
    } else {
      // Default values for new user
      _numEntriesController.text = '0';
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _displayNameController.dispose();
    _numEntriesController.dispose();
    super.dispose();
  }

  bool get _isEditing => widget.user != null;

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_isEditing) {
        // Update existing user
        final updatedUser = widget.user!.copyWith(
          email: _emailController.text.trim().toLowerCase(),
          displayName: _displayNameController.text.trim(),
          numEntries: int.parse(_numEntriesController.text),
          isAdmin: _isAdmin,
          hasPaid: _hasPaid,
        );
        
        final success = await _userService.updateUser(updatedUser);
        if (success) {
          widget.onUserSaved();
          Navigator.of(context).pop();
          _showSnackBar('User updated successfully');
        } else {
          _showSnackBar('Error updating user', isError: true);
        }
      } else {
        // Create new user
        final newUser = await _userService.createUserWithEmail(
          email: _emailController.text.trim().toLowerCase(),
          displayName: _displayNameController.text.trim(),
          numEntries: int.parse(_numEntriesController.text),
          isAdmin: _isAdmin,
          hasPaid: _hasPaid,
        );
        
        if (newUser != null) {
          widget.onUserSaved();
          Navigator.of(context).pop();
          _showSnackBar('User created successfully');
        } else {
          _showSnackBar('Error creating user', isError: true);
        }
      }
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
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
    return AlertDialog(
      title: Text(_isEditing ? 'Edit User' : 'Create New User'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email Address *',
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Email is required';
                    }
                    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,}$');
                    if (!emailRegex.hasMatch(value.trim())) {
                      // Clear the field when invalid email is detected
                      Future.delayed(Duration.zero, () {
                        _emailController.clear();
                      });
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _displayNameController,
                  decoration: const InputDecoration(
                    labelText: 'Display Name',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    // Display name is optional
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _numEntriesController,
                  decoration: const InputDecoration(
                    labelText: 'Number of Entries',
                    prefixIcon: Icon(Icons.sports_football),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Number of entries is required';
                    }
                    final num = int.tryParse(value.trim());
                    if (num == null || num < 0) {
                      return 'Enter a valid number (0 or greater)';
                    }
                    if (num > SecurityConfig.maxEntriesPerUser) {
                      return 'Maximum ${SecurityConfig.maxEntriesPerUser} entries allowed';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Paid Status'),
                  subtitle: Text(_hasPaid ? 'Account is paid' : 'Account is unpaid'),
                  value: _hasPaid,
                  onChanged: (value) => setState(() => _hasPaid = value),
                  secondary: Icon(
                    _hasPaid ? Icons.paid : Icons.money_off,
                    color: _hasPaid ? Colors.green : Colors.red,
                  ),
                ),
                SwitchListTile(
                  title: const Text('Admin Status'),
                  subtitle: Text(_isAdmin ? 'User is an admin' : 'Regular user'),
                  value: _isAdmin,
                  onChanged: (value) => setState(() => _isAdmin = value),
                  secondary: Icon(
                    _isAdmin ? Icons.admin_panel_settings : Icons.person,
                    color: _isAdmin ? Colors.amber : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveUser,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isEditing ? 'Update' : 'Create'),
        ),
      ],
    );
  }
}