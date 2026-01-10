import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'config/security_config.dart';
import 'models/user_model.dart';
import 'services/user_service.dart';
import 'services/verification_service.dart';
import 'services/version_service.dart';
import 'services/square_selection_service.dart';
import 'utils/platform_storage.dart';
import 'utils/blur_dialog.dart';
import 'utils/web_reload_stub.dart'
    if (dart.library.html) 'utils/web_reload.dart';
import 'services/game_config_service.dart';
import 'pages/admin_dashboard.dart';
import 'pages/welcome_screen.dart';
import 'pages/squares_game_page.dart';
import 'widgets/football_field_logo.dart';
import 'widgets/super_bowl_banner.dart';
import 'widgets/footer_widget.dart';
import 'providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait on mobile devices
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize game configuration if it doesn't exist
  final configService = GameConfigService();
  await configService.createDefaultConfig();

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Super Bowl Squares - 2026',
          theme: themeProvider.lightTheme.copyWith(
            textTheme: GoogleFonts.rubikTextTheme(
              themeProvider.lightTheme.textTheme,
            ),
            appBarTheme: themeProvider.lightTheme.appBarTheme.copyWith(
              titleTextStyle: GoogleFonts.rubik(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          darkTheme: themeProvider.darkTheme.copyWith(
            textTheme: GoogleFonts.rubikTextTheme(
              themeProvider.darkTheme.textTheme,
            ),
            appBarTheme: themeProvider.darkTheme.appBarTheme.copyWith(
              titleTextStyle: GoogleFonts.rubik(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: const LaunchPage(),
        );
      },
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
  final GameConfigService _configService = GameConfigService();
  final VersionService _versionService = VersionService();
  bool _isEmailValid = false;
  String? _emailError;
  bool _isCheckingDatabase = false;
  bool _userExists = false;
  UserModel? _currentUser;
  Timer? _debounceTimer;
  Timer? _errorClearTimer;
  StreamSubscription? _configSubscription;
  StreamSubscription<bool>? _versionSubscription;
  String _homeTeamName = 'HOME';
  String _awayTeamName = 'AWAY';
  bool _updateAvailable = false;

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

    // Listen to config changes for team names
    _configSubscription = _configService.configStream().listen((config) {
      if (mounted) {
        setState(() {
          _homeTeamName = config.homeTeamName;
          _awayTeamName = config.awayTeamName;
        });
      }
    });

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

    // Check for saved authentication on startup
    _checkSavedAuthentication();
  }

  void _reloadPage() {
    if (kIsWeb) {
      reloadWebPage();
    }
  }

  @override
  void dispose() {
    // Cancel timers and subscriptions to prevent setState() after dispose
    _debounceTimer?.cancel();
    _errorClearTimer?.cancel();
    _configSubscription?.cancel();
    _versionSubscription?.cancel();

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

      // Auto-navigate if admin or already verified
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (savedUser.isAdmin || savedUser.emailVerified) {
          _navigateToGame();
        }
        // Unverified non-admins stay on login page
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
          _emailError = 'Email not found.\nPlease create an account using the link below.';
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

  void _showSignUpDialog() async {
    final formKey = GlobalKey<FormState>();
    final emailController = TextEditingController();
    final displayNameController = TextEditingController();
    final entriesController = TextEditingController();
    bool isSubmitting = false;
    String? errorMessage;
    int squaresUsed = 0;
    int remainingEntries = 100;
    const int maxTotalEntries = 100;

    // Fetch actual squares used from selections
    final selectionService = SquareSelectionService();
    try {
      squaresUsed = await selectionService.getUniqueSquaresCount();
      remainingEntries = maxTotalEntries - squaresUsed;
      if (remainingEntries < 0) remainingEntries = 0;
    } catch (e) {
      print('Error fetching squares count: $e');
    }

    if (!mounted) return;

    showBlurDialog(
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
                      // Show remaining entries info
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: remainingEntries > 0
                              ? Colors.green.withOpacity(0.2)
                              : Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: remainingEntries > 0 ? Colors.green : Colors.redAccent,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              remainingEntries > 0 ? Icons.check_circle : Icons.error,
                              color: remainingEntries > 0 ? Colors.green : Colors.redAccent,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                remainingEntries > 0
                                    ? '$remainingEntries of $maxTotalEntries entries available'
                                    : 'All entries have been claimed!',
                                style: TextStyle(
                                  color: remainingEntries > 0 ? Colors.green : Colors.redAccent,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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
                      if (remainingEntries > 0) ...[
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
                          decoration: _signUpInputDecoration(
                            'Number of Entries',
                            Icons.grid_view,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Number of entries is required';
                            }
                            final entries = int.tryParse(value.trim());
                            if (entries == null || entries < 1) {
                              return 'Please enter a valid number (1 or more)';
                            }
                            if (entries > remainingEntries) {
                              return 'Only $remainingEntries entries available';
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
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    remainingEntries > 0 ? 'Cancel' : 'Close',
                    style: TextStyle(color: Colors.white.withOpacity(0.7)),
                  ),
                ),
                if (remainingEntries > 0)
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

    showBlurDialog(
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
                            codeController.clear();
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
      body: Column(
        children: [
          // Update available banner
          if (_updateAvailable)
            Material(
              color: Colors.blue.shade700,
              child: InkWell(
                onTap: _reloadPage,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  child: SafeArea(
                    bottom: false,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.system_update, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Update available - Tap to refresh',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.refresh, color: Colors.white, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: Builder(
              builder: (context) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: isDark
                          ? [
                              const Color(0xFF1a1a1a),
                              const Color(0xFF2d2d2d),
                              const Color(0xFF121212),
                            ]
                          : [
                              const Color(0xFF1a472a),
                              const Color(0xFF228B22),
                              const Color(0xFF006400),
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
                              FootballFieldLogo(
                                homeTeamName: _homeTeamName,
                                awayTeamName: _awayTeamName,
                              ),
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
                                      textCapitalization: TextCapitalization.none,
                                      autocorrect: false,
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
                                          borderSide: BorderSide(
                                            color: _emailError != null ? Colors.redAccent : Colors.white.withOpacity(0.5),
                                            width: 2,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(15),
                                          borderSide: BorderSide(
                                            color: _emailError != null ? Colors.redAccent : Colors.amber,
                                            width: 2,
                                          ),
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
                                    if (_emailError != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8.0),
                                        child: Text(
                                          _emailError!,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.redAccent,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 14,
                                          ),
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
      );
              },
            ),
          ),
        ],
      ),
    );
  }
}

