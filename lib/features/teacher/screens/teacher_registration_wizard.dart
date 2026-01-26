import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:eduverse/services/email_verification_service.dart';
import 'package:eduverse/services/uploadToCloudinary.dart';
import 'package:eduverse/utils/app_theme.dart';
import 'dart:async';

/// Teacher Registration Wizard - Multi-step professional registration
/// Collects all required information before submitting for verification
class TeacherRegistrationWizard extends StatefulWidget {
  const TeacherRegistrationWizard({super.key});

  @override
  State<TeacherRegistrationWizard> createState() =>
      _TeacherRegistrationWizardState();
}

class _TeacherRegistrationWizardState extends State<TeacherRegistrationWizard> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = false;

  // Form keys for each page
  final _personalFormKey = GlobalKey<FormState>();
  final _professionalFormKey = GlobalKey<FormState>();
  final _credentialsFormKey = GlobalKey<FormState>();

  // Page 1: Personal Information
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _verificationCodeController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isEmailVerified = false;
  bool _verificationCodeSent = false;
  bool _isVerifyingCode = false;
  String? _emailError;
  String? _verificationSuccess;
  XFile? _profileImage;
  String? _profileImageUrl;

  Timer? _resendTimer;
  int _resendCountdown = 0;

  // Page 2: Professional Information
  final _headlineController = TextEditingController();
  final _bioController = TextEditingController();
  final _experienceController = TextEditingController();
  final _expertiseController = TextEditingController();
  String _selectedExpertise = 'Technology';
  final List<String> _expertiseAreas = [
    'Technology',
    'Business',
    'Design',
    'Marketing',
    'Data Science',
    'Language',
    'Music',
    'Photography',
    'Health & Fitness',
    'Personal Development',
    'Other',
  ];

  // Page 3: Credentials
  final _linkedinController = TextEditingController();
  final _portfolioController = TextEditingController();
  final _certificationController = TextEditingController();
  final _educationController = TextEditingController();
  final List<XFile> _credentialDocuments = [];
  final List<String> _credentialUrls = [];

  final _emailVerificationService = EmailVerificationService();
  final _imagePicker = ImagePicker();

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _verificationCodeController.dispose();
    _headlineController.dispose();
    _bioController.dispose();
    _experienceController.dispose();
    _expertiseController.dispose();
    _linkedinController.dispose();
    _portfolioController.dispose();
    _certificationController.dispose();
    _educationController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
          ),
          onPressed: () {
            if (_currentPage > 0) {
              _previousPage();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          'Teacher Registration',
          style: TextStyle(
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // Progress indicator
          _buildProgressIndicator(isDark),

          // Page content
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) {
                setState(() => _currentPage = index);
              },
              children: [
                _buildPersonalPage(isDark),
                _buildProfessionalPage(isDark),
                _buildCredentialsPage(isDark),
              ],
            ),
          ),

          // Navigation buttons
          _buildNavigationButtons(isDark),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(bool isDark) {
    final steps = ['Personal', 'Professional', 'Credentials'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: List.generate(steps.length, (index) {
          final isCompleted = index < _currentPage;
          final isCurrent = index == _currentPage;

          return Expanded(
            child: Row(
              children: [
                // Step indicator
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isCompleted || isCurrent
                        ? (isDark
                              ? AppTheme.darkPrimary
                              : AppTheme.primaryColor)
                        : (isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: isCurrent 
                                  ? Colors.white 
                                  : (isDark ? AppTheme.darkTextTertiary : AppTheme.textSecondary),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                // Step label
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        steps[index],
                        style: TextStyle(
                          color: isCurrent
                              ? (isDark
                                    ? AppTheme.darkTextPrimary
                                    : AppTheme.textPrimary)
                              : (isDark
                                    ? AppTheme.darkTextTertiary
                                    : AppTheme.textSecondary),
                          fontWeight: isCurrent
                              ? FontWeight.w600
                              : FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Connector line
                if (index < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: isCompleted
                          ? (isDark
                                ? AppTheme.darkPrimary
                                : AppTheme.primaryColor)
                          : (isDark
                                ? AppTheme.darkBorder
                                : Colors.grey.shade300),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ==================== PAGE 1: Personal Information ====================
  Widget _buildPersonalPage(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _personalFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Personal Information',
              style: TextStyle(
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Let\'s start with your basic information',
              style: TextStyle(
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 32),

            // Profile Picture
            Center(
              child: GestureDetector(
                onTap: _pickProfileImage,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCard : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark
                          ? AppTheme.darkBorder
                          : Colors.grey.shade300,
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: _profileImage != null
                        ? _buildProfileImageWidget(_profileImage!, isDark)
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.camera_alt_rounded,
                                size: 32,
                                color: isDark
                                    ? AppTheme.darkTextTertiary
                                    : Colors.grey,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Add Photo',
                                style: TextStyle(
                                  color: isDark
                                      ? AppTheme.darkTextTertiary
                                      : Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Full Name
            _buildTextField(
              controller: _nameController,
              label: 'Full Name',
              hint: 'Enter your full name',
              icon: Icons.person_outline_rounded,
              isDark: isDark,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your name';
                }
                if (value.trim().length < 2) {
                  return 'Name must be at least 2 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Email with verification
            _buildTextField(
              controller: _emailController,
              label: 'Email Address',
              hint: 'Enter your email',
              icon: Icons.email_outlined,
              isDark: isDark,
              enabled: !_isEmailVerified,
              keyboardType: TextInputType.emailAddress,
              errorText: _emailError,
              successText: _verificationSuccess,
              suffixIcon: _isEmailVerified
                  ? Icon(Icons.verified_rounded, color: AppTheme.success)
                  : null,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your email';
                }
                final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                if (!emailRegex.hasMatch(value.trim())) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),

            // Email verification button
            if (!_isEmailVerified) ...[
              const SizedBox(height: 8),
              if (!_verificationCodeSent)
                _buildVerifyEmailButton(isDark)
              else
                _buildVerificationCodeInput(isDark),
            ],
            const SizedBox(height: 16),

            // Password
            _buildTextField(
              controller: _passwordController,
              label: 'Password',
              hint: 'Create a strong password',
              icon: Icons.lock_outline_rounded,
              isDark: isDark,
              obscureText: _obscurePassword,
              onChanged: (_) => setState(() {}),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: isDark ? AppTheme.darkTextTertiary : Colors.grey,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a password';
                }
                if (value.length < 8) {
                  return 'Password must be at least 8 characters';
                }
                if (!value.contains(RegExp(r'[a-zA-Z]'))) {
                  return 'Password must contain at least one letter';
                }
                if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
                  return 'Password must contain at least one special character';
                }
                return null;
              },
            ),

            // Password strength indicator
            if (_passwordController.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildPasswordStrengthIndicator(isDark),
            ],
            const SizedBox(height: 16),

            // Confirm Password
            _buildTextField(
              controller: _confirmPasswordController,
              label: 'Confirm Password',
              hint: 'Re-enter your password',
              icon: Icons.lock_outline_rounded,
              isDark: isDark,
              obscureText: _obscureConfirmPassword,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_off
                      : Icons.visibility,
                  color: isDark ? AppTheme.darkTextTertiary : Colors.grey,
                ),
                onPressed: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please confirm your password';
                }
                if (value != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerifyEmailButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : _sendVerificationCode,
        icon: _isLoading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isDark ? AppTheme.darkPrimary : AppTheme.primaryColor,
                ),
              )
            : Icon(Icons.send_rounded, size: 18),
        label: Text(_isLoading ? 'Sending...' : 'Verify Email'),
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark
              ? AppTheme.darkPrimary
              : AppTheme.primaryColor,
          side: BorderSide(
            color: isDark ? AppTheme.darkPrimary : AppTheme.primaryColor,
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationCodeInput(bool isDark) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _verificationCodeController,
                keyboardType: TextInputType.number,
                style: TextStyle(
                  color: isDark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter 6-digit code',
                  hintStyle: TextStyle(
                    color: isDark ? AppTheme.darkTextTertiary : Colors.grey,
                  ),
                  filled: true,
                  fillColor: isDark ? AppTheme.darkCard : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark
                          ? AppTheme.darkBorder
                          : Colors.grey.shade300,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark
                          ? AppTheme.darkBorder
                          : Colors.grey.shade300,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _isVerifyingCode ? null : _verifyCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark
                    ? AppTheme.darkPrimary
                    : AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isVerifyingCode
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Verify'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Didn\'t receive code? ',
              style: TextStyle(
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
            TextButton(
              onPressed: _resendCountdown > 0 ? null : _sendVerificationCode,
              child: Text(
                _resendCountdown > 0
                    ? 'Resend in ${_resendCountdown}s'
                    : 'Resend',
                style: TextStyle(
                  color: _resendCountdown > 0
                      ? (isDark ? AppTheme.darkTextTertiary : Colors.grey)
                      : (isDark ? AppTheme.darkPrimary : AppTheme.primaryColor),
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==================== PAGE 2: Professional Information ====================
  Widget _buildProfessionalPage(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _professionalFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Professional Information',
              style: TextStyle(
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tell us about your teaching experience',
              style: TextStyle(
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 32),

            // Headline
            _buildTextField(
              controller: _headlineController,
              label: 'Professional Headline',
              hint: 'e.g., Senior Software Engineer with 10+ years',
              icon: Icons.work_outline_rounded,
              isDark: isDark,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a headline';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Bio
            _buildTextField(
              controller: _bioController,
              label: 'About You',
              hint:
                  'Tell students about yourself, your experience, and teaching style...',
              icon: Icons.description_outlined,
              isDark: isDark,
              maxLines: 5,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please write about yourself';
                }
                if (value.trim().length < 50) {
                  return 'Please write at least 50 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Years of Experience
            _buildTextField(
              controller: _experienceController,
              label: 'Years of Experience',
              hint: 'Enter number of years',
              icon: Icons.timer_outlined,
              isDark: isDark,
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter years of experience';
                }
                final years = int.tryParse(value);
                if (years == null || years < 0) {
                  return 'Please enter a valid number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Field of Expertise (Dropdown)
            Text(
              'Field of Expertise *',
              style: TextStyle(
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedExpertise,
                  isExpanded: true,
                  dropdownColor: isDark ? AppTheme.darkCard : Colors.white,
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: isDark ? AppTheme.darkTextSecondary : Colors.grey,
                  ),
                  items: _expertiseAreas.map((area) {
                    return DropdownMenuItem(
                      value: area,
                      child: Text(
                        area,
                        style: TextStyle(
                          color: isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.textPrimary,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedExpertise = value);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== PAGE 3: Credentials ====================
  Widget _buildCredentialsPage(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _credentialsFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Credentials & Documents',
              style: TextStyle(
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Upload your credentials for verification',
              style: TextStyle(
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 32),

            // LinkedIn Profile
            _buildTextField(
              controller: _linkedinController,
              label: 'LinkedIn Profile (Optional)',
              hint: 'https://linkedin.com/in/yourprofile',
              icon: Icons.link_rounded,
              isDark: isDark,
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),

            // Portfolio Website
            _buildTextField(
              controller: _portfolioController,
              label: 'Portfolio/Website (Optional)',
              hint: 'https://yourwebsite.com',
              icon: Icons.language_rounded,
              isDark: isDark,
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),

            // Certifications
            _buildTextField(
              controller: _certificationController,
              label: 'Certifications *',
              hint: 'List your relevant certifications',
              icon: Icons.verified_outlined,
              isDark: isDark,
              maxLines: 3,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please list your certifications';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Education
            _buildTextField(
              controller: _educationController,
              label: 'Education *',
              hint: 'e.g., BSc Computer Science, MIT',
              icon: Icons.school_outlined,
              isDark: isDark,
              maxLines: 2,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your education';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Document Upload
            Text(
              'Upload Documents *',
              style: TextStyle(
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Upload certificates, degrees, or other credentials',
              style: TextStyle(
                color: isDark
                    ? AppTheme.darkTextTertiary
                    : AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),

            // Upload button
            OutlinedButton.icon(
              onPressed: _pickDocument,
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Add Document'),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark
                    ? AppTheme.darkPrimary
                    : AppTheme.primaryColor,
                side: BorderSide(
                  color: isDark ? AppTheme.darkPrimary : AppTheme.primaryColor,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            // Document list
            if (_credentialDocuments.isNotEmpty) ...[
              const SizedBox(height: 16),
              ...List.generate(_credentialDocuments.length, (index) {
                final doc = _credentialDocuments[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? AppTheme.darkBorder
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.description_rounded,
                        color: isDark
                            ? AppTheme.darkPrimary
                            : AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          doc.name,
                          style: TextStyle(
                            color: isDark
                                ? AppTheme.darkTextPrimary
                                : AppTheme.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: isDark ? AppTheme.darkError : AppTheme.error,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _credentialDocuments.removeAt(index);
                          });
                        },
                      ),
                    ],
                  ),
                );
              }),
            ],

            const SizedBox(height: 32),

            // Info box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (isDark ? AppTheme.darkInfo : AppTheme.info).withOpacity(
                  0.1,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (isDark ? AppTheme.darkInfo : AppTheme.info)
                      .withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_rounded,
                    color: isDark ? AppTheme.darkInfo : AppTheme.info,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your application will be reviewed by our team. You\'ll receive an email once verified.',
                      style: TextStyle(
                        color: isDark ? AppTheme.darkInfo : AppTheme.info,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationButtons(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentPage > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousPage,
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.textPrimary,
                  side: BorderSide(
                    color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Previous'),
              ),
            ),
          if (_currentPage > 0) const SizedBox(width: 16),
          Expanded(
            flex: _currentPage == 0 ? 1 : 1,
            child: ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : (_currentPage == 2 ? _submitApplication : _nextPage),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark
                    ? AppTheme.darkPrimary
                    : AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_currentPage == 2 ? 'Submit Application' : 'Continue'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    bool enabled = true,
    bool obscureText = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    String? errorText,
    String? successText,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          obscureText: obscureText,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          onChanged: onChanged,
          style: TextStyle(
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: isDark ? AppTheme.darkTextTertiary : Colors.grey,
            ),
            prefixIcon: Icon(
              icon,
              color: isDark ? AppTheme.darkTextTertiary : Colors.grey,
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: enabled
                ? (isDark ? AppTheme.darkCard : Colors.white)
                : (isDark ? AppTheme.darkBackground : Colors.grey.shade100),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? AppTheme.darkPrimary : AppTheme.primaryColor,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? AppTheme.darkError : AppTheme.error,
              ),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: maxLines > 1 ? 16 : 14,
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 4),
          Text(
            errorText,
            style: TextStyle(
              color: isDark ? AppTheme.darkError : AppTheme.error,
              fontSize: 12,
            ),
          ),
        ],
        if (successText != null) ...[
          const SizedBox(height: 4),
          Text(
            successText,
            style: TextStyle(
              color: isDark ? AppTheme.darkSuccess : AppTheme.success,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  /// Password strength indicator widget
  Widget _buildPasswordStrengthIndicator(bool isDark) {
    final password = _passwordController.text;
    int strength = 0;
    String strengthText = 'Weak';
    Color strengthColor = AppTheme.error;

    // Calculate strength
    if (password.length >= 8) strength++;
    if (password.contains(RegExp(r'[a-z]'))) strength++;
    if (password.contains(RegExp(r'[A-Z]'))) strength++;
    if (password.contains(RegExp(r'[0-9]'))) strength++;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength++;

    // Determine text and color
    if (strength <= 1) {
      strengthText = 'Weak';
      strengthColor = isDark ? AppTheme.darkError : AppTheme.error;
    } else if (strength <= 2) {
      strengthText = 'Fair';
      strengthColor = Colors.orange;
    } else if (strength <= 3) {
      strengthText = 'Good';
      strengthColor = isDark ? AppTheme.darkWarning : AppTheme.warning;
    } else if (strength <= 4) {
      strengthText = 'Strong';
      strengthColor = Colors.lightGreen;
    } else {
      strengthText = 'Very Strong';
      strengthColor = isDark ? AppTheme.darkSuccess : AppTheme.success;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Strength bar
        Row(
          children: List.generate(5, (index) {
            return Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: index < 4 ? 4 : 0),
                decoration: BoxDecoration(
                  color: index < strength
                      ? strengthColor
                      : (isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        // Strength text and requirements
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              strengthText,
              style: TextStyle(
                color: strengthColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${password.length}/8+ chars',
              style: TextStyle(
                color: isDark
                    ? AppTheme.darkTextTertiary
                    : AppTheme.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Requirements checklist
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            _buildRequirementChip(
              'A-Z',
              password.contains(RegExp(r'[A-Z]')),
              isDark,
            ),
            _buildRequirementChip(
              'a-z',
              password.contains(RegExp(r'[a-z]')),
              isDark,
            ),
            _buildRequirementChip(
              '0-9',
              password.contains(RegExp(r'[0-9]')),
              isDark,
            ),
            _buildRequirementChip(
              '!@#',
              password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]')),
              isDark,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRequirementChip(String label, bool isMet, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isMet ? Icons.check_circle : Icons.circle_outlined,
          size: 12,
          color: isMet
              ? (isDark ? AppTheme.darkSuccess : AppTheme.success)
              : (isDark ? AppTheme.darkTextTertiary : Colors.grey),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: isMet
                ? (isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary)
                : (isDark ? AppTheme.darkTextTertiary : Colors.grey),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  // ==================== Actions ====================

  void _previousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _nextPage() {
    bool isValid = false;

    switch (_currentPage) {
      case 0:
        isValid = _personalFormKey.currentState?.validate() ?? false;
        if (isValid && !_isEmailVerified) {
          setState(() => _emailError = 'Please verify your email first');
          return;
        }
        break;
      case 1:
        isValid = _professionalFormKey.currentState?.validate() ?? false;
        break;
      case 2:
        isValid = _credentialsFormKey.currentState?.validate() ?? false;
        break;
    }

    if (isValid) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Build profile image widget with proper error handling
  Widget _buildProfileImageWidget(XFile imageFile, bool isDark) {
    return FutureBuilder<Uint8List>(
      future: imageFile.readAsBytes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: isDark ? AppTheme.darkPrimary : AppTheme.primaryColor,
            ),
          );
        }
        
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: Icon(
              Icons.error_outline,
              color: isDark ? AppTheme.darkError : AppTheme.error,
              size: 32,
            ),
          );
        }

        return Image.memory(
          snapshot.data!,
          fit: BoxFit.cover,
          width: 120,
          height: 120,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Icon(
                Icons.broken_image,
                color: isDark ? AppTheme.darkTextTertiary : Colors.grey,
                size: 32,
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pickProfileImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (image != null && mounted) {
        setState(() => _profileImage = image);
      }
    } catch (e) {
      debugPrint('Error picking profile image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not pick image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickDocument() async {
    try {
      final XFile? file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );
      if (file != null && mounted) {
        setState(() {
          _credentialDocuments.add(file);
        });
      }
    } catch (e) {
      debugPrint('Error picking document: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not pick document: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendVerificationCode() async {
    if (_emailController.text.trim().isEmpty) {
      setState(() => _emailError = 'Please enter your email first');
      return;
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(_emailController.text.trim())) {
      setState(() => _emailError = 'Please enter a valid email');
      return;
    }

    setState(() {
      _isLoading = true;
      _emailError = null;
    });

    try {
      await _emailVerificationService.sendVerificationCode(
        _emailController.text.trim(),
      );

      setState(() {
        _verificationCodeSent = true;
        _verificationSuccess = 'Verification code sent to your email';
        _resendCountdown = 60;
      });

      // Start countdown timer
      _resendTimer?.cancel();
      _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_resendCountdown > 0) {
          setState(() => _resendCountdown--);
        } else {
          timer.cancel();
        }
      });
    } catch (e) {
      setState(() => _emailError = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyCode() async {
    if (_verificationCodeController.text.trim().isEmpty) {
      return;
    }

    setState(() => _isVerifyingCode = true);

    try {
      final isValid = await _emailVerificationService.verifyCode(
        _emailController.text.trim(),
        _verificationCodeController.text.trim(),
      );

      if (isValid) {
        setState(() {
          _isEmailVerified = true;
          _verificationSuccess = 'Email verified successfully!';
          _emailError = null;
        });
      } else {
        setState(() => _emailError = 'Invalid verification code');
      }
    } catch (e) {
      setState(() => _emailError = e.toString());
    } finally {
      setState(() => _isVerifyingCode = false);
    }
  }

  Future<void> _submitApplication() async {
    // Validate credentials page
    if (!(_credentialsFormKey.currentState?.validate() ?? false)) {
      return;
    }

    if (_credentialDocuments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload at least one credential document'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Upload profile image if selected
      if (_profileImage != null) {
        final result = await uploadToCloudinaryFromXFile(_profileImage!);
        if (result != null) {
          _profileImageUrl = result;
        }
      }

      // 2. Upload credential documents
      for (final doc in _credentialDocuments) {
        final result = await uploadToCloudinaryFromXFile(doc);
        if (result != null) {
          _credentialUrls.add(result);
        }
      }

      // 3. Create Firebase Auth account
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      final uid = userCredential.user!.uid;

      // 4. Save teacher data to Firebase with pending status
      await FirebaseDatabase.instance.ref().child('teacher').child(uid).set({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'role': 'teacher',
        'profilePicture': _profileImageUrl,
        'headline': _headlineController.text.trim(),
        'bio': _bioController.text.trim(),
        'yearsOfExperience': _experienceController.text.trim(),
        'expertise': _selectedExpertise,
        'linkedIn': _linkedinController.text.trim(),
        'portfolio': _portfolioController.text.trim(),
        'certifications': _certificationController.text.trim(),
        'education': _educationController.text.trim(),
        'credentialDocuments': _credentialUrls,
        'status': 'pending', // Pending verification
        'isVerified': false,
        'createdAt': ServerValue.timestamp,
      });

      // 5. Register email in lookup table
      final emailKey = _emailController.text
          .toLowerCase()
          .trim()
          .replaceAll('.', '_')
          .replaceAll('@', '_at_');
      await FirebaseDatabase.instance
          .ref()
          .child('registered_emails')
          .child(emailKey)
          .set({
            'email': _emailController.text.toLowerCase().trim(),
            'role': 'teacher',
            'registeredAt': ServerValue.timestamp,
          });

      // 6. Sign out immediately (pending verification)
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      // 7. Show success screen
      _showSuccessScreen();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed: ${e.toString()}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccessScreen() {
    final isDark = AppTheme.isDarkMode(context);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: isDark
              ? AppTheme.darkBackground
              : Colors.grey.shade50,
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color:
                            (isDark ? AppTheme.darkSuccess : AppTheme.success)
                                .withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: 64,
                        color: isDark ? AppTheme.darkSuccess : AppTheme.success,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Application Submitted!',
                      style: TextStyle(
                        color: isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Your application has been submitted for review. You will be notified via email once your account is verified.',
                      style: TextStyle(
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.textSecondary,
                        fontSize: 16,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.popUntil(context, (route) => route.isFirst);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark
                              ? AppTheme.darkPrimary
                              : AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Back to Login'),
                      ),
                    ),
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
