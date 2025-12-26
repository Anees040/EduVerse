import 'package:flutter/material.dart';
import 'package:eduverse/services/auth_service.dart';
import 'package:eduverse/views/student/home_screen.dart';
import 'package:eduverse/views/register_screen.dart';
import 'package:eduverse/views/teacher/teacher_home_screen.dart';
import 'package:eduverse/utils/app_theme.dart';

class SigninScreen extends StatefulWidget {
  const SigninScreen({super.key});

  @override
  State<SigninScreen> createState() => _SigninScreenState();
}

class _SigninScreenState extends State<SigninScreen> {
  bool isStudent = true; // role toggle
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _auth = AuthService();
  bool _obscurePassword = true;
  final _formKey = GlobalKey<FormState>();
  bool _submitted = false;
  String? _loginError; // show under password on auth failure
  bool _loading = false;

  Future<String?> _login() async {
    setState(() => _loading = true);
    try {
      final user = await _auth.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        selectedRole: isStudent ? "student" : "teacher",
      );
      return user?.uid;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
                              onTap: () => setState(() => isStudent = true),
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
                              onTap: () => setState(() => isStudent = false),
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

                    // Email field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(color: AppTheme.getTextPrimary(context)),
                      autovalidateMode: _submitted
                          ? AutovalidateMode.always
                          : AutovalidateMode.disabled,
                      decoration: InputDecoration(
                        label: Row(
                          children: [
                            const Text('Email'),
                            if (_submitted && _emailController.text.trim().isEmpty)
                              Text(' *', style: TextStyle(color: AppTheme.getErrorColor(context))),
                          ],
                        ),
                        hintText: "Enter your email",
                        prefixIcon: Icon(
                          Icons.email_outlined,
                          color: AppTheme.getIconSecondary(context),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (v) {
                        final val = v?.trim() ?? '';
                        if (val.isEmpty) return 'Please enter your email';
                        final emailReg = RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}");
                        if (!emailReg.hasMatch(val)) return 'Please enter a valid email';
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Password field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: TextStyle(color: AppTheme.getTextPrimary(context)),
                      autovalidateMode: _submitted
                          ? AutovalidateMode.always
                          : AutovalidateMode.disabled,
                      decoration: InputDecoration(
                        label: Row(
                          children: [
                            const Text('Password'),
                            if (_submitted && _passwordController.text.isEmpty)
                              Text(' *', style: TextStyle(color: AppTheme.getErrorColor(context))),
                          ],
                        ),
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
                        errorText: _loginError,
                      ),
                      validator: (v) {
                        final val = v ?? '';
                        if (val.isEmpty) return 'Please enter your password';
                        return null;
                      },
                    ),

                    // Forgot password
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          // TODO: Implement forgot password
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Forgot password feature coming soon",
                              ),
                            ),
                          );
                        },
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
                                setState(() => _submitted = true);
                                if (!(_formKey.currentState?.validate() ?? false)) return;

                                try {
                                  // Clear any previous inline error
                                  setState(() => _loginError = null);
                                  final uid = await _login();
                                  if (uid == null || !mounted) return;

                                  if (isStudent) {
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
                                } catch (e) {
                                  // Authentication failed - clear password and show inline error
                                  _passwordController.clear();
                                  setState(() => _loginError = 'Invalid credentials. Please try again.');
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: AppTheme.getErrorColor(context),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      content: Text(e.toString(), style: const TextStyle(color: Colors.white)),
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

                    // Register link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
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
                                builder: (context) => const RegisterScreen(),
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
