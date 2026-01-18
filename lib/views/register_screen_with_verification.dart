import 'package:flutter/material.dart';
import 'package:eduverse/services/auth_service.dart';
import 'package:eduverse/services/email_verification_service.dart';
import 'package:eduverse/utils/app_theme.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';

class RegisterScreenWithVerification extends StatefulWidget {
  const RegisterScreenWithVerification({super.key});

  @override
  State<RegisterScreenWithVerification> createState() =>
      _RegisterScreenWithVerificationState();
}

class _RegisterScreenWithVerificationState
    extends State<RegisterScreenWithVerification> {
  bool isStudent = true;
  final _auth = AuthService();
  final _emailVerificationService = EmailVerificationService();
  GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  late TextEditingController _emailUsernameController; // For email username part only
  late TextEditingController _passwordController;
  late TextEditingController _confirmPasswordController;
  late TextEditingController _verificationCodeController;
  // Teacher-specific controllers
  late TextEditingController _experienceController;
  late TextEditingController _expertiseController;

  // Email domain dropdown
  final List<String> _emailDomains = [
    '@gmail.com',
    '@yahoo.com',
    '@outlook.com',
    '@hotmail.com',
    '@icloud.com',
    '@protonmail.com',
    '@mail.com',
    '@aol.com',
    '@zoho.com',
    '@yandex.com',
    '@gmx.com',
    '@live.com',
    '@msn.com',
  ];
  String _selectedEmailDomain = '@gmail.com';

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _loading = false;
  bool _isEmailVerified = false;
  bool _verificationCodeSent = false;
  bool _isVerifyingCode = false;
  String? _emailError; // Inline error for email verification
  String? _verificationCodeError; // Inline error for verification code
  String? _emailSuccessMessage; // Inline success message for code sent

  Timer? _resendTimer;
  int _resendCountdown = 0;
  
  // Resend limit tracking (3 times in 2 hours)
  int _resendAttempts = 0;
  DateTime? _firstResendTime;

  // Password strength tracking
  double _passwordStrength = 0;
  String _passwordStrengthText = '';
  Color _passwordStrengthColor = Colors.grey;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _passwordController.addListener(_updatePasswordStrength);
  }

  void _initializeControllers() {
    _usernameController = TextEditingController();
    _emailUsernameController = TextEditingController();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _verificationCodeController = TextEditingController();
    _experienceController = TextEditingController();
    _expertiseController = TextEditingController();
  }

  // Get full email address
  String get _fullEmail => '${_emailUsernameController.text.trim()}$_selectedEmailDomain';

  void _disposeControllers() {
    _usernameController.dispose();
    _emailUsernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _verificationCodeController.dispose();
    _experienceController.dispose();
    _expertiseController.dispose();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _passwordController.removeListener(_updatePasswordStrength);
    _disposeControllers();
    super.dispose();
  }

  void _updatePasswordStrength() {
    final password = _passwordController.text;
    double strength = 0;
    String text = '';
    Color color = Colors.grey;

    if (password.isEmpty) {
      strength = 0;
      text = '';
    } else if (password.length < 8) {
      strength = 0.2;
      text = 'Too short (min 8 chars)';
      color = Colors.red;
    } else {
      strength = 0.3;
      if (password.contains(RegExp(r'[A-Z]'))) strength += 0.15;
      if (password.contains(RegExp(r'[a-z]'))) strength += 0.15;
      if (password.contains(RegExp(r'[0-9]'))) strength += 0.15;
      if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
        strength += 0.15;
      }
      if (password.length >= 10) strength += 0.1;

      // Check if meets minimum requirements
      bool hasLetter = password.contains(RegExp(r'[a-zA-Z]'));
      bool hasSpecial = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
      
      if (!hasLetter || !hasSpecial) {
        text = hasLetter ? 'Add special char' : 'Add a letter';
        color = Colors.orange;
      } else if (strength < 0.6) {
        text = 'Fair';
        color = Colors.orange;
      } else if (strength < 0.8) {
        text = 'Good';
        color = Colors.lightGreen;
      } else {
        text = 'Strong';
        color = Colors.green;
      }
    }

    setState(() {
      _passwordStrength = strength.clamp(0, 1);
      _passwordStrengthText = text;
      _passwordStrengthColor = color;
    });
  }

  void _onRoleToggle(bool studentSelected) {
    if (isStudent == studentSelected) return; // No change needed
    
    // Unfocus any active field to prevent keyboard staying up or focus issues
    FocusScope.of(context).unfocus();
    
    // Remove listener before disposing
    _passwordController.removeListener(_updatePasswordStrength);
    
    // Dispose old controllers
    _disposeControllers();
    
    // Reinitialize controllers with fresh instances
    _initializeControllers();
    
    // Re-add listener to new password controller
    _passwordController.addListener(_updatePasswordStrength);
    
    setState(() {
      isStudent = studentSelected;
      
      // Create new form key to force complete form rebuild without validation
      _formKey = GlobalKey<FormState>();
      
      // Reset all other states
      _isEmailVerified = false;
      _verificationCodeSent = false;
      _emailError = null;
      _verificationCodeError = null;
      _passwordStrength = 0;
      _passwordStrengthText = '';
      _passwordStrengthColor = Colors.grey;
      _resendCountdown = 0;
      _resendAttempts = 0;
      _firstResendTime = null;
      if (_resendTimer != null) {
        _resendTimer!.cancel();
        _resendTimer = null;
      }
    });
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your full name';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  // Validate email username (the part before @)
  String? _validateEmailUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email username';
    }
    
    final username = value.trim();
    
    // Check for valid characters in username
    final usernameRegex = RegExp(r'^[a-zA-Z0-9._%+-]+$');
    if (!usernameRegex.hasMatch(username)) {
      return 'Only letters, numbers, and . _ % + - allowed';
    }
    
    if (username.length < 3) {
      return 'Username must be at least 3 characters';
    }
    
    return null;
  }

  // Full email validation (used internally for verification)
  String? _validateFullEmail() {
    final usernameValidation = _validateEmailUsername(_emailUsernameController.text);
    if (usernameValidation != null) {
      return usernameValidation;
    }
    return null; // Domain is always valid since it's from dropdown
  }

  String? _validatePassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a password';
    }
    
    List<String> missing = [];
    
    if (value.trim().length < 8) {
      missing.add('8+ characters');
    }
    if (!value.contains(RegExp(r'[a-zA-Z]'))) {
      missing.add('1 letter');
    }
    if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      missing.add('1 special character (!@#\$%^&*)');
    }
    
    if (missing.isNotEmpty) {
      return 'Password needs: ${missing.join(', ')}';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  // Optional validation - only validate if value is provided
  String? _validateExperience(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Optional field
    }
    final years = int.tryParse(value.trim());
    if (years == null || years < 0) {
      return 'Please enter a valid number';
    }
    return null;
  }

  // Optional validation - only validate if value is provided
  String? _validateExpertise(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Optional field
    }
    if (value.trim().length < 2) {
      return 'Must be at least 2 characters';
    }
    return null;
  }

  // Send verification code
  Future<void> _sendVerificationCode() async {
    // Clear any existing error first
    setState(() => _emailError = null);
    
    final emailValidation = _validateFullEmail();
    if (emailValidation != null) {
      setState(() {
        _emailError = emailValidation;
      });
      return;
    }
    
    // Check resend limit (3 times in 2 hours)
    if (_resendAttempts >= 3) {
      if (_firstResendTime != null) {
        final timeSinceFirst = DateTime.now().difference(_firstResendTime!);
        if (timeSinceFirst.inHours < 2) {
          final remainingMinutes = 120 - timeSinceFirst.inMinutes;
          setState(() {
            _emailError = 'Too many attempts. Please try again in $remainingMinutes minutes.';
          });
          return;
        } else {
          // Reset after 2 hours
          _resendAttempts = 0;
          _firstResendTime = null;
        }
      }
    }
    
    // Clear any previous errors and verification code field
    setState(() {
      _emailError = null;
      _verificationCodeError = null;
      _verificationCodeController.clear();
      _loading = true;
    });
    
    try {
      await _emailVerificationService.sendVerificationCode(
        _fullEmail,
      );
      
      // Track resend attempts
      if (_firstResendTime == null) {
        _firstResendTime = DateTime.now();
      }
      _resendAttempts++;
      
      setState(() {
        _verificationCodeSent = true;
        _emailSuccessMessage = 'Verification code sent to your email!';
        _resendCountdown = 60;
      });
      _startResendTimer();
    } catch (e) {
      if (mounted) {
        setState(() {
          _emailError = e.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Start resend timer
  void _startResendTimer() {
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_resendCountdown > 0) {
          _resendCountdown--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  // Verify code
  Future<void> _verifyCode() async {
    if (_verificationCodeController.text.trim().length != 6) {
      setState(() {
        _verificationCodeError = 'Please enter a valid 6-digit code';
      });
      return;
    }

    setState(() {
      _isVerifyingCode = true;
      _verificationCodeError = null;
    });
    
    try {
      final verified = await _emailVerificationService.verifyCode(
        _fullEmail,
        _verificationCodeController.text.trim(),
      );
      if (verified && mounted) {
        setState(() => _isEmailVerified = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 10),
                Text('Email verified successfully!'),
              ],
            ),
            backgroundColor: AppTheme.getSuccessColor(context),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _verificationCodeError = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _isVerifyingCode = false);
    }
  }

  Future<bool> _register() async {
    // Clear any existing email error first to avoid double errors
    setState(() => _emailError = null);
    
    // Validate email username first (for inline error)
    final emailValidation = _validateFullEmail();
    if (emailValidation != null) {
      setState(() {
        _emailError = emailValidation;
      });
      return false;
    }
    
    if (!_isEmailVerified) {
      // Show inline error instead of snackbar for consistency
      setState(() {
        _emailError = 'Please verify your email first';
      });
      return false;
    }

    setState(() => _loading = true);
    try {
      await _auth.signUp(
        name: _usernameController.text.trim(),
        role: isStudent ? "student" : "teacher",
        email: _fullEmail,
        password: _passwordController.text.trim(),
        yearsOfExperience: !isStudent
            ? _experienceController.text.trim()
            : null,
        subjectExpertise: !isStudent ? _expertiseController.text.trim() : null,
      );
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
      return false;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Helper to show snackbar professionally (clears previous ones)
  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars() // Clear any existing snackbars
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white),
              const SizedBox(width: 12),
              Text(message),
            ],
          ),
          backgroundColor: AppTheme.primaryColor,
          behavior: SnackBarBehavior.floating,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  // Google Sign Up Handler - Coming Soon
  void _handleGoogleSignUp() {
    _showInfoSnackBar('Sign up through Google is coming soon!');
  }

  // GitHub Sign Up Handler - Coming Soon
  void _handleGitHubSignUp() {
    _showInfoSnackBar('Sign up through GitHub is coming soon!');
  }

  // Build Google icon using official SVG
  Widget _buildGoogleIcon() {
    return SvgPicture.asset(
      'assets/images/google_logo.svg',
      width: 24,
      height: 24,
    );
  }

  // Build password requirement item with check/cross icon
  Widget _buildPasswordRequirement(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: isMet ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: isMet ? Colors.green[700] : Colors.grey[600],
              fontWeight: isMet ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.getCardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.getSuccessColor(context).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                color: AppTheme.getSuccessColor(context),
                size: 60,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Registration Successful!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.getTextPrimary(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Your ${isStudent ? "student" : "teacher"} account has been created successfully.',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.getTextSecondary(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: const Text('Continue to Sign In'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header with gradient
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40),
                decoration: BoxDecoration(
                  gradient: isDark
                      ? AppTheme.darkPrimaryGradient
                      : AppTheme.primaryGradient,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(40),
                    bottomRight: Radius.circular(40),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 8.0,
                        top: 8.0,
                        bottom: 8.0,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                            tooltip: 'Back',
                          ),
                        ],
                      ),
                    ),
                    Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.person_add_rounded,
                              size: 60,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "Create Account",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Join eduVerse today",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),

                    // Role toggle buttons
                    Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.darkElevated
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                        border: isDark
                            ? Border.all(color: AppTheme.darkBorder)
                            : null,
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _onRoleToggle(true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: isStudent
                                      ? AppTheme.getButtonColor(context)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.school,
                                      color: isStudent
                                          ? Colors.white
                                          : AppTheme.getTextSecondary(context),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Student",
                                      style: TextStyle(
                                        color: isStudent
                                            ? Colors.white
                                            : AppTheme.getTextSecondary(
                                                context,
                                              ),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _onRoleToggle(false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: !isStudent
                                      ? AppTheme.getButtonColor(context)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.person_outline,
                                      color: !isStudent
                                          ? Colors.white
                                          : AppTheme.getTextSecondary(context),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Teacher",
                                      style: TextStyle(
                                        color: !isStudent
                                            ? Colors.white
                                            : AppTheme.getTextSecondary(
                                                context,
                                              ),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Full Name
                          TextFormField(
                            controller: _usernameController,
                            style: TextStyle(
                              color: AppTheme.getTextPrimary(context),
                            ),
                            validator: _validateName,
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            decoration: InputDecoration(
                              labelText: "Full Name",
                              hintText: "Enter your full name",
                              prefixIcon: Icon(
                                Icons.person_outline,
                                color: AppTheme.getIconSecondary(context),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Email with verification - Username + Domain dropdown
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Email username input
                                  Expanded(
                                    flex: 3,
                                    child: TextFormField(
                                      controller: _emailUsernameController,
                                      keyboardType: TextInputType.text,
                                      style: TextStyle(
                                        color: AppTheme.getTextPrimary(context),
                                      ),
                                      validator: (value) {
                                        // Skip form validation if we already have inline error
                                        if (_emailError != null) return null;
                                        return _validateEmailUsername(value);
                                      },
                                      autovalidateMode: AutovalidateMode.onUserInteraction,
                                      enabled: !_isEmailVerified,
                                      onChanged: (value) {
                                        // Clear inline error when user types
                                        if (_emailError != null) {
                                          setState(() => _emailError = null);
                                        }
                                      },
                                      decoration: InputDecoration(
                                        labelText: "Email",
                                        hintText: "username",
                                        prefixIcon: Icon(
                                          Icons.email_outlined,
                                          color: _emailError != null 
                                              ? Theme.of(context).colorScheme.error
                                              : AppTheme.getIconSecondary(context),
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Domain dropdown
                                  Expanded(
                                    flex: 2,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: _isEmailVerified
                                              ? Colors.grey.withOpacity(0.3)
                                              : (isDark ? Colors.grey[700]! : Colors.grey[400]!),
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _selectedEmailDomain,
                                          isExpanded: true,
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          borderRadius: BorderRadius.circular(12),
                                          dropdownColor: AppTheme.getCardColor(context),
                                          style: TextStyle(
                                            color: _isEmailVerified
                                                ? Colors.grey
                                                : AppTheme.getTextPrimary(context),
                                            fontSize: 14,
                                          ),
                                          icon: Icon(
                                            Icons.arrow_drop_down,
                                            color: _isEmailVerified
                                                ? Colors.grey
                                                : AppTheme.getIconSecondary(context),
                                          ),
                                          items: _emailDomains.map((domain) {
                                            return DropdownMenuItem<String>(
                                              value: domain,
                                              child: Text(
                                                domain,
                                                style: TextStyle(
                                                  color: AppTheme.getTextPrimary(context),
                                                  fontSize: 14,
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: _isEmailVerified
                                              ? null
                                              : (value) {
                                                  if (value != null) {
                                                    setState(() {
                                                      _selectedEmailDomain = value;
                                                      if (_emailError != null) {
                                                        _emailError = null;
                                                      }
                                                    });
                                                  }
                                                },
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Verified icon
                                  if (_isEmailVerified)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: Icon(
                                        Icons.check_circle,
                                        color: AppTheme.getSuccessColor(context),
                                        size: 28,
                                      ),
                                    ),
                                ],
                              ),
                              // Show error message below
                              if (_emailError != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6, left: 12),
                                  child: Text(
                                    _emailError!,
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.error,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Success message when code is sent (inline instead of snackbar)
                          if (_emailSuccessMessage != null && _verificationCodeSent && !_isEmailVerified)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle, size: 16, color: Colors.green),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _emailSuccessMessage!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.green[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Verification status indicator
                          if (!_isEmailVerified)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDark
                                  ? AppTheme.darkAccent.withOpacity(0.12)
                                  : Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark
                                    ? AppTheme.darkAccent.withOpacity(0.3)
                                    : Colors.blue.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _verificationCodeSent
                                      ? Icons.pending_outlined
                                      : Icons.info_outline,
                                    size: 16,
                                    color: isDark
                                      ? AppTheme.darkAccent
                                      : (_verificationCodeSent ? Colors.orange : Colors.blue),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _verificationCodeSent
                                        ? 'Enter the 6-digit code sent to your email'
                                        : 'Email verification is required to create an account',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                          ? AppTheme.darkAccent
                                          : (_verificationCodeSent ? Colors.orange[700] : Colors.blue[700]),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          
                          if (_isEmailVerified)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle, size: 16, color: Colors.green),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Email verified successfully!',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 12),

                          // Send verification code button
                          if (!_isEmailVerified && !_verificationCodeSent)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _loading
                                    ? null
                                    : _sendVerificationCode,
                                icon: _loading 
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.mail_outline, size: 18),
                                label: Text(_loading ? 'Sending...' : 'Verify Email Address'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  backgroundColor: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),

                          // Verification code input
                          if (_verificationCodeSent && !_isEmailVerified) ...[
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _verificationCodeController,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              style: TextStyle(
                                color: AppTheme.getTextPrimary(context),
                                fontSize: 18,
                                letterSpacing: 3,
                              ),
                              textAlign: TextAlign.center,
                              onChanged: (_) {
                                // Clear error when user starts typing
                                if (_verificationCodeError != null) {
                                  setState(() => _verificationCodeError = null);
                                }
                              },
                              decoration: InputDecoration(
                                labelText: "Verification Code",
                                hintText: "000000",
                                counterText: "",
                                errorText: _verificationCodeError,
                                errorMaxLines: 2,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            
                            // Remaining resend attempts info
                            if (_resendAttempts > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Resend attempts: ${3 - _resendAttempts} remaining',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _resendAttempts >= 2 
                                        ? Colors.orange[700] 
                                        : Colors.grey[600],
                                  ),
                                ),
                              ),
                            
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _isVerifyingCode
                                        ? null
                                        : _verifyCode,
                                    child: _isVerifyingCode
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text('Verify Code'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                TextButton(
                                  onPressed: (_resendCountdown > 0 || _resendAttempts >= 3)
                                      ? null
                                      : _sendVerificationCode,
                                  child: Text(
                                    _resendAttempts >= 3
                                        ? 'Limit reached'
                                        : _resendCountdown > 0
                                            ? 'Resend ($_resendCountdown)s'
                                            : 'Resend Code',
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 16),

                          // Password
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: TextStyle(
                              color: AppTheme.getTextPrimary(context),
                            ),
                            validator: _validatePassword,
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            decoration: InputDecoration(
                              labelText: "Password",
                              hintText: "Create a password",
                              prefixIcon: Icon(
                                Icons.lock_outline,
                                color: AppTheme.getIconSecondary(context),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: AppTheme.getIconSecondary(context),
                                ),
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),

                          // Password strength indicator
                          if (_passwordController.text.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: _passwordStrength,
                                          backgroundColor: Colors.grey.shade300,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                _passwordStrengthColor,
                                              ),
                                          minHeight: 6,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      _passwordStrengthText,
                                      style: TextStyle(
                                        color: _passwordStrengthColor,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                // Password requirements checklist
                                _buildPasswordRequirement(
                                  'At least 8 characters',
                                  _passwordController.text.length >= 8,
                                ),
                                _buildPasswordRequirement(
                                  'Contains a letter (a-z, A-Z)',
                                  _passwordController.text.contains(RegExp(r'[a-zA-Z]')),
                                ),
                                _buildPasswordRequirement(
                                  'Contains a special character (!@#\$%^&*)',
                                  _passwordController.text.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]')),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 16),

                          // Confirm Password
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            style: TextStyle(
                              color: AppTheme.getTextPrimary(context),
                            ),
                            validator: _validateConfirmPassword,
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            decoration: InputDecoration(
                              labelText: "Confirm Password",
                              hintText: "Re-enter your password",
                              prefixIcon: Icon(
                                Icons.lock_outline,
                                color: AppTheme.getIconSecondary(context),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: AppTheme.getIconSecondary(context),
                                ),
                                onPressed: () => setState(
                                  () => _obscureConfirmPassword =
                                      !_obscureConfirmPassword,
                                ),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),

                          // Teacher-specific fields
                          if (!isStudent) ...[
                            const SizedBox(height: 16),
                            // Recommended fields info
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDark
                                  ? AppTheme.darkAccent.withOpacity(0.12)
                                  : Colors.blue.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark
                                    ? AppTheme.darkAccent.withOpacity(0.2)
                                    : Colors.blue.withOpacity(0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.lightbulb_outline, size: 16, color: isDark ? AppTheme.darkAccent : Colors.blue[600]),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'The following fields are optional but recommended to enhance your profile',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? AppTheme.darkAccent : Colors.blue[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _experienceController,
                              keyboardType: TextInputType.number,
                              style: TextStyle(
                                color: AppTheme.getTextPrimary(context),
                              ),
                              validator: _validateExperience,
                              autovalidateMode: AutovalidateMode.onUserInteraction,
                              decoration: InputDecoration(
                                labelText: "Years of Experience",
                                hintText: "Enter years of teaching experience",
                                helperText: "Optional",
                                helperStyle: TextStyle(
                                  color: AppTheme.getTextSecondary(context),
                                  fontSize: 11,
                                ),
                                prefixIcon: Icon(
                                  Icons.work_outline,
                                  color: AppTheme.getIconSecondary(context),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _expertiseController,
                              style: TextStyle(
                                color: AppTheme.getTextPrimary(context),
                              ),
                              validator: _validateExpertise,
                              autovalidateMode: AutovalidateMode.onUserInteraction,
                              decoration: InputDecoration(
                                labelText: "Subject Expertise",
                                hintText:
                                    "e.g., Mathematics, Physics, Chemistry",
                                helperText: "Optional",
                                helperStyle: TextStyle(
                                  color: AppTheme.getTextSecondary(context),
                                  fontSize: 11,
                                ),
                                prefixIcon: Icon(
                                  Icons.school_outlined,
                                  color: AppTheme.getIconSecondary(context),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Register button
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _loading
                            ? null
                            : () async {
                                if (!_formKey.currentState!.validate()) return;
                                bool success = await _register();
                                if (success && mounted) {
                                  _showSuccessDialog();
                                }
                              },
                        child: _loading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                "Create Account",
                                style: TextStyle(fontSize: 18),
                              ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Divider with "OR"
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: AppTheme.getTextSecondary(
                              context,
                            ).withOpacity(0.3),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'OR',
                            style: TextStyle(
                              color: AppTheme.getTextSecondary(context),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: AppTheme.getTextSecondary(
                              context,
                            ).withOpacity(0.3),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Google Sign-up button
                    SizedBox(
                      height: 56,
                      child: OutlinedButton(
                        onPressed: _loading ? null : _handleGoogleSignUp,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: AppTheme.getTextSecondary(
                              context,
                            ).withOpacity(0.3),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildGoogleIcon(),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                'Sign up with Google',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppTheme.getTextPrimary(context),
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // GitHub Sign-up button (only for students)
                    if (isStudent) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 56,
                        child: OutlinedButton(
                          onPressed: _loading ? null : _handleGitHubSignUp,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: AppTheme.getTextSecondary(
                                context,
                              ).withOpacity(0.3),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              FaIcon(
                                FontAwesomeIcons.github,
                                color: AppTheme.getTextPrimary(context),
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  'Sign up with GitHub',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: AppTheme.getTextPrimary(context),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Already have account?
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Already have an account?",
                          style: TextStyle(
                            fontSize: 16,
                            color: AppTheme.getTextSecondary(context),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            "Sign In",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
