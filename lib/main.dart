import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'config/security_config.dart';
import 'models/user_model.dart';
import 'services/user_service.dart';
import 'services/game_config_service.dart';
import 'pages/admin_dashboard.dart';
import 'pages/welcome_screen.dart';
import 'pages/squares_game_page.dart';
import 'widgets/football_field_logo.dart';
import 'widgets/super_bowl_banner.dart';
import 'widgets/footer_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize game configuration if it doesn't exist
  final configService = GameConfigService();
  await configService.createDefaultConfig();
  
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
        textTheme: GoogleFonts.rubikTextTheme(
          ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.green)).textTheme,
        ),
        appBarTheme: AppBarTheme(
          titleTextStyle: GoogleFonts.rubik(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
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
  final TextEditingController _emailController = TextEditingController();
  final UserService _userService = UserService();
  bool _isEmailValid = false;
  String? _emailError;
  bool _isCheckingDatabase = false;
  bool _userExists = false;
  UserModel? _currentUser;
  Timer? _debounceTimer;
  Timer? _errorClearTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    // Add listener for UI updates only (no validation)
    _emailController.addListener(_onEmailTextChanged);
    
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
    
    // Check for saved authentication on startup
    _checkSavedAuthentication();
  }

  @override
  void dispose() {
    // Cancel timers to prevent setState() after dispose
    _debounceTimer?.cancel();
    _errorClearTimer?.cancel();
    
    // Dispose controllers and animations
    _controller.dispose();
    _emailController.dispose();
    super.dispose();
  }
  
  void _onEmailTextChanged() {
    // Just update UI state when text changes - no validation
    setState(() {
      // Clear any existing errors when user starts typing again
      if (_emailError != null) {
        _emailError = null;
        _isEmailValid = false;
        _userExists = false;
        _currentUser = null;
      }
    });
  }

  // Save user authentication to localStorage
  void _saveUserToLocalStorage(UserModel user) {
    try {
      final userJson = jsonEncode(user.toJson());
      html.window.localStorage['sb_squares_user'] = userJson;
      print('User saved to localStorage');
    } catch (e) {
      print('Error saving user to localStorage: $e');
    }
  }

  // Load user authentication from localStorage
  UserModel? _loadUserFromLocalStorage() {
    try {
      final userJson = html.window.localStorage['sb_squares_user'];
      if (userJson != null) {
        final userData = jsonDecode(userJson) as Map<String, dynamic>;
        return UserModel.fromJson(userData);
      }
    } catch (e) {
      print('Error loading user from localStorage: $e');
      // Clear corrupted data
      html.window.localStorage.remove('sb_squares_user');
    }
    return null;
  }

  // Clear user authentication from localStorage
  void _clearUserFromLocalStorage() {
    html.window.localStorage.remove('sb_squares_user');
    print('User cleared from localStorage');
  }

  // Check for saved authentication on app startup
  void _checkSavedAuthentication() {
    final savedUser = _loadUserFromLocalStorage();
    if (savedUser != null) {
      setState(() {
        _currentUser = savedUser;
        _emailController.text = savedUser.email;
        _isEmailValid = true;
        _userExists = true;
      });
      
      // Auto-navigate to the appropriate page
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToGame();
      });
    }
  }

  Future<void> _validateEmail() async {
    final email = _emailController.text.trim().toLowerCase();
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,}$');
    
    // First check email format
    if (email.isEmpty) {
      setState(() {
        _isEmailValid = false;
        _userExists = false;
        _currentUser = null;
        _emailError = null;
        _isCheckingDatabase = false;
      });
      return;
    }
    
    if (!emailRegex.hasMatch(email)) {
      setState(() {
        _isEmailValid = false;
        _userExists = false;
        _currentUser = null;
        _emailError = 'Please enter a valid email address';
        _isCheckingDatabase = false;
      });
      return;
    }
    
    // Email format is valid, now check Firestore
    setState(() {
      _isCheckingDatabase = true;
      _emailError = null;
    });
    
    try {
      // Check if user exists in Firestore using UserService
      final user = await _userService.getUserByEmail(email);
      
      setState(() {
        _currentUser = user;
        _userExists = user != null;
        _isEmailValid = user != null; // Allow all valid users, not just admins
        _isCheckingDatabase = false;
        
        if (user == null) {
          _emailError = 'Email not found. Access denied.';
        } else {
          _emailError = null;
          // Allow unpaid users to view the board but not select squares
          if (user.numEntries >= 100) {
            _emailError = 'Maximum entries reached for this account.';
            _isEmailValid = false;
          } else {
            // Save user to localStorage for persistence across page refreshes
            _saveUserToLocalStorage(user);
          }
        }
      });
    } catch (e) {
      setState(() {
        _isCheckingDatabase = false;
        _isEmailValid = false;
        _userExists = false;
        _currentUser = null;
        _emailError = 'Error checking database. Please try again.';
      });
      
      print('Error checking user in Firestore: $e');
    }
  }

  void _navigateToGame() {
    if (!_isEmailValid || _currentUser == null) return;
    
    // Determine destination based on user type and whether they've seen instructions
    Widget destination;
    if (_currentUser!.isAdmin) {
      // Admins go to admin dashboard
      destination = AdminDashboard(currentUser: _currentUser!);
    } else if (_currentUser!.hasSeenInstructions) {
      // Regular users who have seen instructions go directly to the game
      destination = SquaresGamePage(user: _currentUser!);
    } else {
      // First-time users see the welcome screen with instructions
      destination = WelcomeScreen(user: _currentUser!);
    }
    
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => destination,
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
        child: Column(
          children: [
            Expanded(
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
                              const SizedBox(height: 40),
                              Container(
                                width: 400,
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: Column(
                                  children: [
                                    TextField(
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      enabled: !_isCheckingDatabase,
                                      maxLength: 100,
                                      style: const TextStyle(color: Colors.white),
                                      onSubmitted: (value) async {
                                        // Validate email when user presses Enter
                                        await _validateEmail();
                                        // Navigate if validation passed
                                        if (_isEmailValid && _currentUser != null) {
                                          _navigateToGame();
                                        }
                                      },
                                      decoration: InputDecoration(
                                        counterText: '',
                                        hintText: 'Use your invite email',
                                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                                        labelText: 'Email',
                                        labelStyle: const TextStyle(color: Colors.white),
                                        errorText: _emailError,
                                        errorStyle: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w500),
                                        prefixIcon: const Icon(Icons.email, color: Colors.white70),
                                        suffixIcon: _isCheckingDatabase 
                                          ? const Padding(
                                              padding: EdgeInsets.all(12.0),
                                              child: SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                                                ),
                                              ),
                                            )
                                          : null,
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(15),
                                          borderSide: BorderSide(color: Colors.white.withOpacity(0.5), width: 2),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(15),
                                          borderSide: const BorderSide(color: Colors.amber, width: 2),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(15),
                                          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
                                        ),
                                        focusedErrorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(15),
                                          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
                                        ),
                                        disabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(15),
                                          borderSide: BorderSide(color: Colors.white.withOpacity(0.3), width: 2),
                                        ),
                                        filled: true,
                                        fillColor: Colors.black.withOpacity(0.3),
                                      ),
                                    ),
                                    if (_emailController.text.isNotEmpty && _userExists && !_isCheckingDatabase)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8.0),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.check_circle, color: Colors.green.shade300, size: 20),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Access granted',
                                              style: TextStyle(color: Colors.green.shade300, fontSize: 14, fontWeight: FontWeight.w500),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (_isCheckingDatabase)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8.0),
                                        child: Text(
                                          'Checking database...',
                                          style: TextStyle(color: Colors.amber.shade300, fontSize: 14),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 30),
                              ElevatedButton(
                                onPressed: _emailController.text.isNotEmpty && !_isCheckingDatabase 
                                    ? () async {
                                        // Validate email when user clicks button  
                                        await _validateEmail();
                                        // Navigate if validation passed
                                        if (_isEmailValid && _currentUser != null) {
                                          _navigateToGame();
                                        }
                                      }
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _emailController.text.isNotEmpty && !_isCheckingDatabase ? Colors.amber : Colors.grey,
                                  foregroundColor: _emailController.text.isNotEmpty && !_isCheckingDatabase ? Colors.black : Colors.white60,
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
                                  children: [
                                    Icon(
                                      _currentUser?.isAdmin == true 
                                          ? Icons.admin_panel_settings 
                                          : Icons.sports_football, 
                                      size: 28
                                    ),
                                    const SizedBox(width: 10),
                                    Text(_currentUser?.isAdmin == true 
                                        ? 'ADMIN DASHBOARD' 
                                        : 'ENTER THE GAME'),
                                    const SizedBox(width: 10),
                                    const Icon(Icons.arrow_forward, size: 28),
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
            const FooterWidget(),
          ],
        ),
      ),
    );
  }
}

