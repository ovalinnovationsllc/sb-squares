import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'config/security_config.dart';
import 'models/user_model.dart';
import 'services/user_service.dart';
import 'services/verification_service.dart';
import 'utils/platform_storage.dart';
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
  final VerificationService _verificationService = VerificationService();
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

  // Save user authentication to storage
  void _saveUserToLocalStorage(UserModel user) async {
    try {
      final userJson = jsonEncode(user.toJson());
      await PlatformStorage.setString('sb_squares_user', userJson);
      print('User saved to storage');
    } catch (e) {
      print('Error saving user to storage: $e');
    }
  }

  // Load user authentication from storage
  Future<UserModel?> _loadUserFromLocalStorage() async {
    try {
      final userJson = await PlatformStorage.getString('sb_squares_user');
      if (userJson != null) {
        final userData = jsonDecode(userJson) as Map<String, dynamic>;
        return UserModel.fromJson(userData);
      }
    } catch (e) {
      print('Error loading user from storage: $e');
      // Clear corrupted data
      await PlatformStorage.remove('sb_squares_user');
    }
    return null;
  }

  // Clear user authentication from storage
  void _clearUserFromLocalStorage() async {
    await PlatformStorage.remove('sb_squares_user');
    print('User cleared from storage');
  }

  // Check for saved authentication on app startup
  void _checkSavedAuthentication() async {
    final savedUser = await _loadUserFromLocalStorage();
    print('_checkSavedAuthentication: savedUser = ${savedUser?.email}');
    if (savedUser != null) {
      setState(() {
        _currentUser = savedUser;
        _emailController.text = savedUser.email;
        _isEmailValid = true;
        _userExists = true;
      });

      // Auto-navigate only for admins, others need to verify every time
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (savedUser.isAdmin) {
          _navigateToGame();
        }
        // Non-admins stay on login page - they need to verify every time
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

  void _showSignUpDialog() {
    final formKey = GlobalKey<FormState>();
    final emailController = TextEditingController();
    final displayNameController = TextEditingController();
    final entriesController = TextEditingController(text: '1');
    bool isSubmitting = false;
    String? errorMessage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1a472a),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Colors.amber, width: 2),
              ),
              title: Row(
                children: [
                  const Icon(Icons.person_add, color: Colors.amber, size: 28),
                  const SizedBox(width: 10),
                  Text(
                    'Sign Up',
                    style: GoogleFonts.rubik(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.redAccent),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  errorMessage!,
                                  style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: Colors.white),
                        decoration: _signUpInputDecoration('Email', Icons.email),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Email is required';
                          }
                          final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,}$');
                          if (!emailRegex.hasMatch(value.trim())) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: displayNameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _signUpInputDecoration('Display Name', Icons.person),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Display name is required';
                          }
                          if (value.trim().length < 2) {
                            return 'Name must be at least 2 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: entriesController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: _signUpInputDecoration('Number of Entries', Icons.grid_view),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Number of entries is required';
                          }
                          final entries = int.tryParse(value.trim());
                          if (entries == null) {
                            return 'Please enter a valid number';
                          }
                          if (entries < 1 || entries > 100) {
                            return 'Entries must be between 1 and 100';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Each entry costs \$150',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white.withOpacity(0.7)),
                  ),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;

                          setDialogState(() {
                            isSubmitting = true;
                            errorMessage = null;
                          });

                          final email = emailController.text.trim().toLowerCase();

                          // Check if email already exists
                          final existingUser = await _userService.getUserByEmail(email);
                          if (existingUser != null) {
                            setDialogState(() {
                              isSubmitting = false;
                              errorMessage = 'An account with this email already exists. Please log in instead.';
                            });
                            return;
                          }

                          // Create the new user
                          final newUser = await _userService.createUserWithEmail(
                            email: email,
                            displayName: displayNameController.text.trim(),
                            numEntries: int.parse(entriesController.text.trim()),
                            isAdmin: false,
                            hasPaid: false,
                          );

                          if (newUser != null) {
                            // Save to local storage and set state
                            _saveUserToLocalStorage(newUser);
                            setState(() {
                              _currentUser = newUser;
                              _emailController.text = newUser.email;
                              _isEmailValid = true;
                              _userExists = true;
                            });

                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }

                            // Show verification dialog for new users
                            _showVerificationDialog(newUser);
                          } else {
                            setDialogState(() {
                              isSubmitting = false;
                              errorMessage = 'Failed to create account. Please try again.';
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Sign Up'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  InputDecoration _signUpInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      prefixIcon: Icon(icon, color: Colors.white70),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.amber, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
      ),
      filled: true,
      fillColor: Colors.black.withOpacity(0.3),
    );
  }

  Future<void> _showVerificationDialog(UserModel user) async {
    final codeController = TextEditingController();
    bool isSendingCode = true;
    bool isVerifying = false;
    String? errorMessage;
    String? successMessage;
    bool canResend = false;
    int resendCountdown = 60;
    Timer? countdownTimer;

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Start countdown timer for resend
            void startCountdown() {
              resendCountdown = 60;
              canResend = false;
              countdownTimer?.cancel();
              countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
                if (resendCountdown > 0) {
                  setDialogState(() {
                    resendCountdown--;
                  });
                } else {
                  timer.cancel();
                  setDialogState(() {
                    canResend = true;
                  });
                }
              });
            }

            // Send code on first build
            if (isSendingCode) {
              isSendingCode = false;
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                final sendResult = await _verificationService.sendVerificationCode(
                  email: user.email,
                  userId: user.id,
                );
                if (sendResult.success) {
                  setDialogState(() {
                    successMessage = 'Code sent!';
                  });
                  startCountdown();
                } else {
                  setDialogState(() {
                    errorMessage = sendResult.message;
                    canResend = true;
                  });
                }
              });
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF1a472a),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Colors.amber, width: 2),
              ),
              title: Row(
                children: [
                  const Icon(Icons.verified_user, color: Colors.amber, size: 28),
                  const SizedBox(width: 10),
                  Text(
                    'Verify Email',
                    style: GoogleFonts.rubik(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      successMessage != null ? 'We sent a 6-digit code to:' : 'Sending code to:',
                      style: TextStyle(color: Colors.white.withOpacity(0.8)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      user.email,
                      style: const TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (successMessage == null && errorMessage == null)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    if (errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.redAccent),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (successMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                successMessage!,
                                style: const TextStyle(color: Colors.green, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    TextField(
                      controller: codeController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 12,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '------',
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 32,
                          letterSpacing: 12,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.amber, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.3),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: canResend
                          ? () async {
                              setDialogState(() {
                                successMessage = null;
                                errorMessage = null;
                              });
                              final result = await _verificationService.sendVerificationCode(
                                email: user.email,
                                userId: user.id,
                              );
                              if (result.success) {
                                setDialogState(() {
                                  successMessage = 'New code sent!';
                                });
                                startCountdown();
                              } else {
                                setDialogState(() {
                                  errorMessage = result.message;
                                });
                              }
                            }
                          : null,
                      child: Text(
                        canResend ? 'Resend Code' : 'Resend in ${resendCountdown}s',
                        style: TextStyle(
                          color: canResend ? Colors.amber : Colors.white.withOpacity(0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isVerifying
                      ? null
                      : () {
                          countdownTimer?.cancel();
                          Navigator.of(dialogContext).pop();
                        },
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white.withOpacity(0.7)),
                  ),
                ),
                ElevatedButton(
                  onPressed: isVerifying || codeController.text.length != 6
                      ? null
                      : () async {
                          setDialogState(() {
                            isVerifying = true;
                            errorMessage = null;
                          });

                          final result = await _verificationService.verifyCode(
                            userId: user.id,
                            code: codeController.text,
                          );

                          if (result.success) {
                            countdownTimer?.cancel();

                            // Update local user state with verified status
                            final verifiedUser = user.copyWith(emailVerified: true);
                            _saveUserToLocalStorage(verifiedUser);
                            setState(() {
                              _currentUser = verifiedUser;
                            });

                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }

                            // Navigate to the game
                            _navigateToGame();
                          } else {
                            setDialogState(() {
                              isVerifying = false;
                              errorMessage = result.message;
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                  ),
                  child: isVerifying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Verify'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
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
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height - 
                    MediaQuery.of(context).padding.top - 
                    MediaQuery.of(context).padding.bottom,
              ),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    Expanded(
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
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                              const SuperBowlBanner(),
                              const SizedBox(height: 20),
                              const FootballFieldLogo(),
                              const SizedBox(height: 40),
                              Container(
                                width: MediaQuery.of(context).size.width * 0.9,
                                constraints: const BoxConstraints(maxWidth: 400),
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
                                          // Admins skip verification, others always need to verify
                                          if (_currentUser!.isAdmin) {
                                            _navigateToGame();
                                          } else {
                                            _showVerificationDialog(_currentUser!);
                                          }
                                        }
                                      },
                                      decoration: InputDecoration(
                                        counterText: '',
                                        hintText: 'Enter account email',
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
                                          // Admins skip verification, others always need to verify
                                          if (_currentUser!.isAdmin) {
                                            _navigateToGame();
                                          } else {
                                            _showVerificationDialog(_currentUser!);
                                          }
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
                              const SizedBox(height: 20),
                              TextButton(
                                onPressed: () => _showSignUpDialog(),
                                child: Text(
                                  "Don't have an account? Sign Up",
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 16,
                                    decoration: TextDecoration.underline,
                                    decorationColor: Colors.white.withOpacity(0.9),
                                  ),
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
                    const FooterWidget(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

