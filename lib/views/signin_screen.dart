import 'package:flutter/material.dart';
import 'package:eduverse/services/auth_service.dart';
import 'package:eduverse/services/email_verification_service.dart';
import 'package:eduverse/views/student/home_screen.dart';
import 'package:eduverse/views/register_screen_with_verification.dart';
import 'package:eduverse/views/teacher/teacher_home_screen.dart';
import 'package:eduverse/features/admin/screens/admin_dashboard_screen.dart';
import 'package:eduverse/features/admin/services/admin_service.dart';
import 'package:eduverse/utils/app_theme.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SigninScreen extends StatefulWidget {
  const SigninScreen({super.key});

  @override
  State<SigninScreen> createState() => _SigninScreenState();
}

class _SigninScreenState extends State<SigninScreen> {
  bool isStudent = true; // role toggle
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  final _auth = AuthService();
  final _emailVerificationService = EmailVerificationService();
  GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;

  bool _loading = false;
  String? _errorMessage; // For displaying error at top of form

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _initializeControllers() {
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  void _disposeControllers() {
    _emailController.dispose();
    _passwordController.dispose();
  }

  bool _showEmailError = false;
  bool _showPasswordError = false;

  String? _validateEmail(String? value) {
    if (!_showEmailError) return null;
    // If user has entered content, don't show error
    if (value != null && value.trim().isNotEmpty) {
      return null;
    }
    return 'Please enter your email';
  }

  String? _validatePassword(String? value) {
    if (!_showPasswordError) return null;
    // If user has entered content, don't show error
    if (value != null && value.trim().isNotEmpty) {
      return null;
    }
    return 'Please enter your password';
  }

  // Reset form state when toggling roles
  void _onRoleToggle(bool studentSelected) {
    if (isStudent == studentSelected) return; // No change needed

    // Unfocus any active field
    FocusScope.of(context).unfocus();

    // Dispose old controllers
    _disposeControllers();

    // Reinitialize controllers with fresh instances
    _initializeControllers();

    setState(() {
      isStudent = studentSelected;
      _errorMessage = null;

      // Create new form key to force complete form rebuild without validation
      _formKey = GlobalKey<FormState>();
    });
  }

  // Show forgot password dialog with email verification
  void _showForgotPasswordDialog() {
    final TextEditingController resetEmailController = TextEditingController();
    final TextEditingController verificationCodeController =
        TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController =
        TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;
    bool codeSent = false;
    bool codeVerified = false;
    bool obscureNewPassword = true;
    bool obscureConfirmPassword = true;
    String? emailError;
    String? codeSuccessMessage;
    bool passwordsMatch = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Monitor password matching
          void checkPasswordMatch() {
            final match =
                newPasswordController.text == confirmPasswordController.text ||
                confirmPasswordController.text.isEmpty;
            if (passwordsMatch != match) {
              setDialogState(() => passwordsMatch = match);
            }
          }

          return AlertDialog(
            backgroundColor: AppTheme.getCardColor(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Reset Password',
              style: TextStyle(
                color: AppTheme.getTextPrimary(context),
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!codeVerified) ...[
                      Text(
                        'Enter your registered email address to receive a verification code.',
                        style: TextStyle(
                          color: AppTheme.getTextSecondary(context),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: resetEmailController,
                        keyboardType: TextInputType.emailAddress,
                        enabled: !codeSent,
                        style: TextStyle(
                          color: AppTheme.getTextPrimary(context),
                        ),
                        onChanged: (_) {
                          if (emailError != null) {
                            setDialogState(() => emailError = null);
                          }
                        },
                        validator: (value) {
                          if (emailError != null) return null;
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your email';
                          }
                          final emailRegex = RegExp(
                            r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                          );
                          if (!emailRegex.hasMatch(value.trim())) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          labelText: 'Email',
                          hintText: 'Enter your registered email',
                          errorText: emailError,
                          prefixIcon: Icon(
                            Icons.email_outlined,
                            color: emailError != null
                                ? Theme.of(context).colorScheme.error
                                : AppTheme.getIconSecondary(context),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),

                      // Success message for code sent (inline instead of snackbar)
                      if (codeSuccessMessage != null && codeSent) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.green.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  codeSuccessMessage!,
                                  style: TextStyle(
                                    color: Colors.green[700],
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      if (codeSent) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: verificationCodeController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.getTextPrimary(context),
                            fontSize: 18,
                            letterSpacing: 8,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter the code';
                            }
                            if (value.trim().length != 6) {
                              return 'Code must be 6 digits';
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            labelText: 'Verification Code',
                            hintText: '000000',
                            counterText: "",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ] else ...[
                      // Password reset section
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.green.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.verified,
                              color: Colors.green,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Email verified! Create your new password.',
                                style: TextStyle(
                                  color: Colors.green[700],
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // New Password field with visibility toggle
                      TextFormField(
                        controller: newPasswordController,
                        obscureText: obscureNewPassword,
                        style: TextStyle(
                          color: AppTheme.getTextPrimary(context),
                        ),
                        onChanged: (_) => checkPasswordMatch(),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter new password';
                          }
                          if (value.trim().length < 8) {
                            return 'Password must be at least 8 characters';
                          }
                          if (!value.contains(RegExp(r'[a-zA-Z]'))) {
                            return 'Password must contain at least 1 letter';
                          }
                          if (!value.contains(
                            RegExp(r'[!@#$%^&*(),.?":{}|<>]'),
                          )) {
                            return 'Password must contain at least 1 special character';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          labelText: 'New Password',
                          hintText: 'Enter new password',
                          prefixIcon: Icon(
                            Icons.lock_outline,
                            color: AppTheme.getIconSecondary(context),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureNewPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: AppTheme.getIconSecondary(context),
                            ),
                            onPressed: () {
                              setDialogState(() {
                                obscureNewPassword = !obscureNewPassword;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Confirm Password field with visibility toggle and real-time matching
                      TextFormField(
                        controller: confirmPasswordController,
                        obscureText: obscureConfirmPassword,
                        style: TextStyle(
                          color: AppTheme.getTextPrimary(context),
                        ),
                        onChanged: (_) => checkPasswordMatch(),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please confirm your password';
                          }
                          if (value != newPasswordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          hintText: 'Confirm your password',
                          prefixIcon: Icon(
                            Icons.lock_outline,
                            color: AppTheme.getIconSecondary(context),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureConfirmPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: AppTheme.getIconSecondary(context),
                            ),
                            onPressed: () {
                              setDialogState(() {
                                obscureConfirmPassword =
                                    !obscureConfirmPassword;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          // Real-time password match indicator
                          helperText:
                              confirmPasswordController.text.isNotEmpty &&
                                  passwordsMatch
                              ? '✓ Passwords match'
                              : null,
                          helperStyle: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                          errorText:
                              confirmPasswordController.text.isNotEmpty &&
                                  !passwordsMatch
                              ? 'Passwords do not match'
                              : null,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: AppTheme.getTextSecondary(context)),
                ),
              ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        if (!codeSent) {
                          // Validate email format first
                          if (!formKey.currentState!.validate()) return;

                          setDialogState(() {
                            isLoading = true;
                            emailError = null;
                          });

                          try {
                            // Check if email exists in database FIRST
                            final emailExists = await _auth.checkEmailExists(
                              resetEmailController.text.trim(),
                            );

                            if (!emailExists) {
                              setDialogState(() {
                                emailError =
                                    'This email is not registered with EduVerse';
                                isLoading = false;
                              });
                              return;
                            }

                            // Check rate limit (max 2 verification codes per week)
                            final rateLimitError =
                                await _emailVerificationService
                                    .checkVerificationCodeRateLimit(
                                      resetEmailController.text.trim(),
                                    );
                            if (rateLimitError != null) {
                              setDialogState(() {
                                emailError = rateLimitError;
                                isLoading = false;
                              });
                              return;
                            }

                            // Send verification code
                            await _emailVerificationService
                                .sendVerificationCode(
                                  resetEmailController.text.trim(),
                                );
                            setDialogState(() {
                              codeSent = true;
                              codeSuccessMessage =
                                  'Verification code sent to your email!';
                              isLoading = false;
                            });
                          } catch (e) {
                            setDialogState(() {
                              emailError = e.toString().replaceAll(
                                'Exception: ',
                                '',
                              );
                              isLoading = false;
                            });
                          }
                        } else if (!codeVerified) {
                          // Verify code
                          if (!formKey.currentState!.validate()) return;

                          setDialogState(() => isLoading = true);

                          try {
                            final verified = await _emailVerificationService
                                .verifyCode(
                                  resetEmailController.text.trim(),
                                  verificationCodeController.text.trim(),
                                );
                            if (verified) {
                              setDialogState(() {
                                codeVerified = true;
                                isLoading = false;
                              });
                            }
                          } catch (e) {
                            setDialogState(() => isLoading = false);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    e.toString().replaceAll('Exception: ', ''),
                                  ),
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.error,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        } else {
                          // Reset password using Cloud Function
                          if (!formKey.currentState!.validate()) return;
                          if (!passwordsMatch) return;

                          setDialogState(() => isLoading = true);

                          try {
                            // Call Cloud Function to actually update password
                            await _auth.resetPasswordViaCloudFunction(
                              email: resetEmailController.text.trim(),
                              newPassword: newPasswordController.text,
                            );

                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              // Show success dialog
                              _showPasswordResetSuccessDialog(
                                resetEmailController.text.trim(),
                                isActualReset: true,
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isLoading = false);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    e.toString().replaceAll('Exception: ', ''),
                                  ),
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.error,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.isDarkMode(context)
                      ? AppTheme.darkAccent
                      : AppTheme.primaryColor,
                  foregroundColor: AppTheme.isDarkMode(context)
                      ? Colors.black
                      : Colors.white,
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        !codeSent
                            ? 'Send Code'
                            : !codeVerified
                            ? 'Verify Code'
                            : 'Reset Password',
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Show password reset success dialog
  void _showPasswordResetSuccessDialog(
    String email, {
    bool isActualReset = false,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.getCardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isActualReset ? Icons.check_circle : Icons.mark_email_read,
                color: Colors.green,
                size: 60,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isActualReset
                  ? 'Password Changed Successfully!'
                  : 'Password Reset Link Sent!',
              style: TextStyle(
                color: AppTheme.getTextPrimary(context),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              isActualReset
                  ? 'Your password has been updated successfully for:'
                  : 'We\'ve sent a password reset link to:',
              style: TextStyle(
                color: AppTheme.getTextSecondary(context),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              email,
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              isActualReset
                  ? 'You can now sign in with your new password. A confirmation email has been sent to your inbox.'
                  : 'Please check your inbox and follow the link to set your new password.',
              style: TextStyle(
                color: AppTheme.getTextSecondary(context),
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.isDarkMode(context)
                      ? AppTheme.darkAccent
                      : AppTheme.primaryColor,
                  foregroundColor: AppTheme.isDarkMode(context)
                      ? Colors.black
                      : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  isActualReset ? 'Sign In Now' : 'Got It',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _login() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final user = await _auth.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        selectedRole: isStudent ? "student" : "teacher",
      );
      return user?.uid;
    } catch (e) {
      // Unfocus all fields after failed login
      FocusScope.of(context).unfocus();

      setState(() {
        _errorMessage = _formatErrorMessage(e.toString());
        _passwordController.clear(); // Clear password on error
      });
      return null;
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // Format error messages to be more user-friendly
  String _formatErrorMessage(String error) {
    if (error.contains('user-not-found') || error.contains('No user exists')) {
      return 'No account found with this email';
    } else if (error.contains('wrong-password') ||
        error.contains('invalid-credential')) {
      return 'Incorrect email or password';
    } else if (error.contains('invalid-email')) {
      return 'Please enter a valid email address';
    } else if (error.contains('too-many-requests')) {
      return 'Too many failed attempts. Please try again later';
    } else if (error.contains('network')) {
      return 'Network error. Please check your connection';
    } else if (error.contains('Invalid role')) {
      return 'This account is not registered as a ${isStudent ? "student" : "teacher"}';
    }
    return 'Login failed. Please check your credentials';
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
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  // Google Sign In Handler - Coming Soon
  void _handleGoogleSignIn() {
    _showInfoSnackBar('Login through Google is coming soon!');
  }

  // GitHub Sign In Handler - Coming Soon
  void _handleGitHubSignIn() {
    _showInfoSnackBar('Login through GitHub is coming soon!');
  }

  // Build Google icon using official SVG
  Widget _buildGoogleIcon() {
    return SvgPicture.asset(
      'assets/images/google_logo.svg',
      width: 24,
      height: 24,
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
                padding: const EdgeInsets.symmetric(vertical: 50),
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
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.4 : 0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.school_rounded,
                        size: 60,
                        color: AppTheme.getPrimaryColor(context),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "eduVerse",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Welcome back!",
                      style: TextStyle(color: Colors.white70, fontSize: 16),
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

                    // Role toggle
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

                    // Error message display (shown at top of form)
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.error.withOpacity(0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Theme.of(context).colorScheme.error,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() => _errorMessage = null),
                              child: Icon(
                                Icons.close,
                                color: Theme.of(context).colorScheme.error,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Wrap fields in Form widget
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Email field
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: TextStyle(
                              color: AppTheme.getTextPrimary(context),
                            ),
                            validator: _validateEmail,
                            onChanged: (_) {
                              if (_showEmailError) {
                                setState(() {
                                  _showEmailError = false;
                                });
                                _formKey.currentState?.validate();
                              }
                            },
                            decoration: InputDecoration(
                              labelText: "Email",
                              hintText: "Enter your email",
                              prefixIcon: Icon(
                                Icons.email_outlined,
                                color: AppTheme.getIconSecondary(context),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              errorStyle: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.error,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Password field
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: TextStyle(
                              color: AppTheme.getTextPrimary(context),
                            ),
                            validator: _validatePassword,
                            onChanged: (_) {
                              if (_showPasswordError) {
                                setState(() {
                                  _showPasswordError = false;
                                });
                                _formKey.currentState?.validate();
                              }
                            },
                            decoration: InputDecoration(
                              labelText: "Password",
                              hintText: "Enter your password",
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
                              errorStyle: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.error,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Forgot password
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _showForgotPasswordDialog,
                        child: Text(
                          "Forgot Password?",
                          style: TextStyle(
                            color: AppTheme.getPrimaryColor(context),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Sign In button
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _loading
                            ? null
                            : () async {
                                setState(() {
                                  _showEmailError = true;
                                  _showPasswordError = true;
                                });
                                if (!_formKey.currentState!.validate()) {
                                  return;
                                }

                                final uid = await _login();
                                if (uid == null || !mounted) return;

                                if (!mounted) return;

                                // Check if user is an admin
                                final adminService = AdminService();
                                final isAdmin = await adminService.isUserAdmin(
                                  uid,
                                );

                                if (!mounted) return;

                                if (isAdmin) {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const AdminDashboardScreen(),
                                    ),
                                  );
                                } else if (isStudent) {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => HomeScreen(
                                        role: isStudent ? "student" : "teacher",
                                        uid: uid,
                                      ),
                                    ),
                                  );
                                } else {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => TeacherHomeScreen(
                                        role: isStudent ? "student" : "teacher",
                                        uid: uid,
                                      ),
                                    ),
                                  );
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
                                "Sign In",
                                style: TextStyle(fontSize: 18),
                              ),
                      ),
                    ),

                    const SizedBox(height: 30),

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

                    // Google Sign-in button
                    SizedBox(
                      height: 56,
                      child: OutlinedButton(
                        onPressed: _loading ? null : _handleGoogleSignIn,
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
                                'Continue with Google',
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

                    // GitHub Sign-in button (only for students)
                    if (isStudent) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 56,
                        child: OutlinedButton(
                          onPressed: _loading ? null : _handleGitHubSignIn,
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
                                  'Continue with GitHub',
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

                    const SizedBox(height: 30),

                    // Register link - wrapped to prevent overflow
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          "Don't have an account?",
                          style: TextStyle(
                            fontSize: 16,
                            color: AppTheme.getTextSecondary(context),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const RegisterScreenWithVerification(),
                              ),
                            );
                          },
                          child: const Text(
                            "Register",
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
