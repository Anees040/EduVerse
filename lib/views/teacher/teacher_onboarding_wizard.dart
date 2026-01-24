import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:eduverse/utils/app_theme.dart';
import 'package:eduverse/services/user_service.dart';
import 'package:eduverse/services/uploadToCloudinary.dart';

/// Teacher Onboarding Wizard - Multi-step profile completion
/// Collects professional bio, credentials, and profile picture
class TeacherOnboardingWizard extends StatefulWidget {
  final bool isFirstTime; // True if showing after registration
  final VoidCallback? onComplete;

  const TeacherOnboardingWizard({
    super.key,
    this.isFirstTime = true,
    this.onComplete,
  });

  @override
  State<TeacherOnboardingWizard> createState() =>
      _TeacherOnboardingWizardState();
}

class _TeacherOnboardingWizardState extends State<TeacherOnboardingWizard>
    with TickerProviderStateMixin {
  final _userService = UserService();

  // Page controller
  late PageController _pageController;
  int _currentStep = 0;
  final int _totalSteps = 4;

  // Animation controller
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  // Form keys
  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();
  final _step3FormKey = GlobalKey<FormState>();

  // Controllers for Step 1: Professional Profile
  final _headlineController = TextEditingController();
  final _bioController = TextEditingController();
  final _yearsExpController = TextEditingController();
  String _selectedExpertise = 'Technology';

  // Controllers for Step 2: Education & Credentials
  final _educationController = TextEditingController();
  final _institutionController = TextEditingController();
  final _certificationsController = TextEditingController();
  final List<Map<String, dynamic>> _credentials =
      []; // Changed to dynamic to support image URLs

  // Controllers for Step 3: Achievements & Links
  final _achievementsController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _websiteController = TextEditingController();

  // Profile picture state
  XFile? _selectedImage;
  Uint8List? _imageBytes;
  String? _uploadedImageUrl;
  bool _isUploadingImage = false;
  double _uploadProgress = 0;

  // Loading state
  bool _isSaving = false;

  // Expertise options
  final List<String> _expertiseOptions = [
    'Technology',
    'Business',
    'Science',
    'Mathematics',
    'Arts & Design',
    'Language',
    'Health & Fitness',
    'Music',
    'Personal Development',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _progressAnimation = Tween<double>(begin: 0, end: 1 / _totalSteps).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );
    _progressController.forward();
    _loadExistingData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _progressController.dispose();
    _headlineController.dispose();
    _bioController.dispose();
    _yearsExpController.dispose();
    _educationController.dispose();
    _institutionController.dispose();
    _certificationsController.dispose();
    _achievementsController.dispose();
    _linkedinController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingData() async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final userData = await _userService.getUser(uid: uid, role: 'teacher');

      if (userData != null && mounted) {
        setState(() {
          _headlineController.text = userData['headline'] ?? '';
          _bioController.text = userData['bio'] ?? '';
          _yearsExpController.text =
              userData['yearsOfExperience']?.toString() ?? '';
          if (userData['subjectExpertise'] != null &&
              _expertiseOptions.contains(userData['subjectExpertise'])) {
            _selectedExpertise = userData['subjectExpertise'];
          }
          _educationController.text = userData['education'] ?? '';
          _institutionController.text = userData['institution'] ?? '';
          _certificationsController.text = userData['certifications'] ?? '';
          _achievementsController.text = userData['achievements'] ?? '';
          _linkedinController.text = userData['linkedin'] ?? '';
          _websiteController.text = userData['website'] ?? '';
          _uploadedImageUrl = userData['profilePicture'];

          // Load credentials if available
          if (userData['credentialsList'] is List) {
            for (var cred in userData['credentialsList']) {
              if (cred is Map) {
                _credentials.add({
                  'title': cred['title'] ?? '',
                  'issuer': cred['issuer'] ?? '',
                });
              }
            }
          }
        });
      }
    } catch (_) {
      // Ignore errors, use empty fields
    }
  }

  void _nextStep() {
    bool isValid = true;

    switch (_currentStep) {
      case 0:
        isValid = _step1FormKey.currentState?.validate() ?? false;
        break;
      case 1:
        isValid = _step2FormKey.currentState?.validate() ?? false;
        break;
      case 2:
        isValid = _step3FormKey.currentState?.validate() ?? false;
        break;
    }

    if (!isValid && _currentStep < 3) {
      return;
    }

    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _updateProgressAnimation();
    } else {
      _saveProfile();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _updateProgressAnimation();
    }
  }

  void _updateProgressAnimation() {
    _progressAnimation =
        Tween<double>(
          begin: _progressAnimation.value,
          end: (_currentStep + 1) / _totalSteps,
        ).animate(
          CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
        );
    _progressController.forward(from: 0);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );

    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _selectedImage = picked;
        _imageBytes = bytes;
      });
    }
  }

  Future<void> _uploadImage() async {
    if (_selectedImage == null) return;

    setState(() {
      _isUploadingImage = true;
      _uploadProgress = 0;
    });

    try {
      final url = await uploadToCloudinaryWithSimulatedProgress(
        _selectedImage!,
        onProgress: (progress) {
          if (mounted) {
            setState(() => _uploadProgress = progress);
          }
        },
      );

      if (mounted) {
        setState(() {
          _uploadedImageUrl = url;
          _isUploadingImage = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingImage = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to upload image: $e')));
      }
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);

    try {
      // Upload image first if selected but not uploaded
      if (_imageBytes != null && _uploadedImageUrl == null) {
        await _uploadImage();
      }

      final uid = FirebaseAuth.instance.currentUser!.uid;

      // Prepare profile data
      final profileData = {
        'headline': _headlineController.text.trim(),
        'bio': _bioController.text.trim(),
        'yearsOfExperience': int.tryParse(_yearsExpController.text) ?? 0,
        'subjectExpertise': _selectedExpertise,
        'education': _educationController.text.trim(),
        'institution': _institutionController.text.trim(),
        'certifications': _certificationsController.text.trim(),
        'achievements': _achievementsController.text.trim(),
        'linkedin': _linkedinController.text.trim(),
        'website': _websiteController.text.trim(),
        'profilePicture': _uploadedImageUrl,
        'credentialsList': _credentials,
        'profileCompleted': true,
        'profileCompletedAt': DateTime.now().millisecondsSinceEpoch,
      };

      await _userService.updateTeacherProfile(uid: uid, data: profileData);

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save profile: $e')));
      }
    }
  }

  void _showSuccessDialog() {
    final isDark = AppTheme.isDarkMode(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.getCardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: (isDark ? AppTheme.darkSuccess : AppTheme.success)
                    .withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.celebration,
                size: 60,
                color: isDark ? AppTheme.darkSuccess : AppTheme.success,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Profile Complete! 🎉',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: AppTheme.getTextPrimary(context),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.isFirstTime
                  ? 'Welcome to EduVerse! Your professional profile is ready. Start creating amazing courses!'
                  : 'Your profile has been updated successfully!',
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
                  if (widget.onComplete != null) {
                    widget.onComplete!();
                  } else {
                    Navigator.of(context).pop();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark
                      ? AppTheme.darkAccent
                      : AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  widget.isFirstTime ? 'Start Teaching!' : 'Done',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _currentStep > 0
            ? IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: AppTheme.getTextPrimary(context),
                ),
                onPressed: _previousStep,
              )
            : (!widget.isFirstTime
                  ? IconButton(
                      icon: Icon(
                        Icons.close,
                        color: AppTheme.getTextPrimary(context),
                      ),
                      onPressed: () => Navigator.pop(context),
                    )
                  : null),
        title: Text(
          widget.isFirstTime ? 'Complete Your Profile' : 'Edit Profile',
          style: TextStyle(
            color: AppTheme.getTextPrimary(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (!widget.isFirstTime)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Skip',
                style: TextStyle(color: AppTheme.getTextSecondary(context)),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Progress indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Step ${_currentStep + 1} of $_totalSteps',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppTheme.darkAccent
                            : AppTheme.primaryColor,
                      ),
                    ),
                    Text(
                      _getStepTitle(_currentStep),
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                AnimatedBuilder(
                  animation: _progressAnimation,
                  builder: (context, child) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _progressAnimation.value,
                        backgroundColor: isDark
                            ? AppTheme.darkBorder
                            : Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
                        ),
                        minHeight: 6,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Page content
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1ProfessionalProfile(isDark),
                _buildStep2Credentials(isDark),
                _buildStep3Achievements(isDark),
                _buildStep4ProfilePicture(isDark),
              ],
            ),
          ),

          // Bottom buttons
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.getCardColor(context),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _previousStep,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(
                            color: isDark
                                ? AppTheme.darkBorder
                                : Colors.grey.shade300,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Back',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.getTextPrimary(context),
                          ),
                        ),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _nextStep,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark
                            ? AppTheme.darkAccent
                            : AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _currentStep == _totalSteps - 1
                                      ? 'Complete Profile'
                                      : 'Continue',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  _currentStep == _totalSteps - 1
                                      ? Icons.check_circle
                                      : Icons.arrow_forward,
                                  size: 18,
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return 'Professional Profile';
      case 1:
        return 'Credentials';
      case 2:
        return 'Achievements';
      case 3:
        return 'Profile Picture';
      default:
        return '';
    }
  }

  Widget _buildStep1ProfessionalProfile(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _step1FormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              icon: Icons.person_outline,
              title: 'Tell us about yourself',
              subtitle: 'Help students know who you are',
              isDark: isDark,
            ),
            const SizedBox(height: 24),

            // Headline
            _buildInputLabel('Professional Headline', isDark),
            const SizedBox(height: 8),
            TextFormField(
              controller: _headlineController,
              decoration: _buildInputDecoration(
                hint: 'e.g., "Senior Software Engineer with 10+ years"',
                icon: Icons.title,
                isDark: isDark,
              ),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Please enter a headline'
                  : null,
            ),
            const SizedBox(height: 20),

            // Bio
            _buildInputLabel('Bio', isDark),
            const SizedBox(height: 8),
            TextFormField(
              controller: _bioController,
              maxLines: 4,
              maxLength: 500,
              decoration: _buildInputDecoration(
                hint:
                    'Tell students about your background, teaching style, and what makes you passionate about teaching...',
                icon: Icons.description,
                isDark: isDark,
              ),
              validator: (v) => v == null || v.trim().length < 50
                  ? 'Please write at least 50 characters'
                  : null,
            ),
            const SizedBox(height: 20),

            // Years of experience
            _buildInputLabel('Years of Experience', isDark),
            const SizedBox(height: 8),
            TextFormField(
              controller: _yearsExpController,
              keyboardType: TextInputType.number,
              decoration: _buildInputDecoration(
                hint: 'e.g., 5',
                icon: Icons.work_history,
                isDark: isDark,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Please enter years of experience';
                }
                final years = int.tryParse(v);
                if (years == null || years < 0 || years > 60) {
                  return 'Please enter a valid number';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Subject expertise
            _buildInputLabel('Primary Expertise', isDark),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkElevated : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
                ),
              ),
              child: DropdownButtonFormField<String>(
                value: _selectedExpertise,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: InputBorder.none,
                  prefixIcon: Icon(
                    Icons.category,
                    color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
                dropdownColor: AppTheme.getCardColor(context),
                items: _expertiseOptions
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(
                          e,
                          style: TextStyle(
                            color: AppTheme.getTextPrimary(context),
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) =>
                    setState(() => _selectedExpertise = v ?? 'Technology'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2Credentials(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _step2FormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              icon: Icons.school_outlined,
              title: 'Your Credentials',
              subtitle: 'Build trust with your qualifications',
              isDark: isDark,
            ),
            const SizedBox(height: 24),

            // Highest Education
            _buildInputLabel('Highest Education', isDark),
            const SizedBox(height: 8),
            TextFormField(
              controller: _educationController,
              decoration: _buildInputDecoration(
                hint: 'e.g., Master\'s in Computer Science',
                icon: Icons.school,
                isDark: isDark,
              ),
            ),
            const SizedBox(height: 20),

            // Institution
            _buildInputLabel('Institution', isDark),
            const SizedBox(height: 8),
            TextFormField(
              controller: _institutionController,
              decoration: _buildInputDecoration(
                hint: 'e.g., Stanford University',
                icon: Icons.account_balance,
                isDark: isDark,
              ),
            ),
            const SizedBox(height: 20),

            // Certifications
            _buildInputLabel('Certifications (Optional)', isDark),
            const SizedBox(height: 8),
            TextFormField(
              controller: _certificationsController,
              maxLines: 3,
              decoration: _buildInputDecoration(
                hint: 'List relevant certifications, one per line...',
                icon: Icons.verified,
                isDark: isDark,
              ),
            ),
            const SizedBox(height: 24),

            // Add credentials section
            Row(
              children: [
                Icon(
                  Icons.add_circle_outline,
                  size: 20,
                  color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Additional Credentials',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppTheme.getTextPrimary(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Credentials list
            ..._credentials.asMap().entries.map(
              (entry) => _buildCredentialTile(entry.key, entry.value, isDark),
            ),

            // Add credential button
            TextButton.icon(
              onPressed: () => _showAddCredentialDialog(isDark),
              icon: Icon(
                Icons.add,
                color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
              ),
              label: Text(
                'Add Credential',
                style: TextStyle(
                  color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCredentialTile(
    int index,
    Map<String, dynamic> credential,
    bool isDark,
  ) {
    final imageUrl = credential['imageUrl']?.toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkElevated : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          // Show certificate image thumbnail if available
          imageUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 44,
                      height: 44,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color:
                            (isDark
                                    ? AppTheme.darkAccent
                                    : AppTheme.primaryColor)
                                .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.badge,
                        size: 20,
                        color: isDark
                            ? AppTheme.darkAccent
                            : AppTheme.primaryColor,
                      ),
                    ),
                  ),
                )
              : Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                            .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.badge,
                    size: 20,
                    color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
                  ),
                ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  credential['title']?.toString() ?? '',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.getTextPrimary(context),
                  ),
                ),
                Text(
                  credential['issuer']?.toString() ?? '',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.getTextSecondary(context),
                  ),
                ),
                if (imageUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        Icon(Icons.verified, size: 12, color: AppTheme.success),
                        const SizedBox(width: 4),
                        Text(
                          'Certificate attached',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.success,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              size: 18,
              color: AppTheme.getTextSecondary(context),
            ),
            onPressed: () => setState(() => _credentials.removeAt(index)),
          ),
        ],
      ),
    );
  }

  void _showAddCredentialDialog(bool isDark) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _CredentialDialog(
        isDark: isDark,
        onAdd: (title, issuer, imageUrl) {
          setState(() {
            _credentials.add({
              'title': title,
              'issuer': issuer,
              'imageUrl': imageUrl,
            });
          });
        },
      ),
    );
  }

  Widget _buildStep3Achievements(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _step3FormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              icon: Icons.emoji_events_outlined,
              title: 'Achievements & Links',
              subtitle: 'Showcase your accomplishments',
              isDark: isDark,
            ),
            const SizedBox(height: 24),

            // Achievements
            _buildInputLabel('Notable Achievements (Optional)', isDark),
            const SizedBox(height: 8),
            TextFormField(
              controller: _achievementsController,
              maxLines: 4,
              decoration: _buildInputDecoration(
                hint:
                    'Share awards, recognitions, publications, or notable projects...',
                icon: Icons.military_tech,
                isDark: isDark,
              ),
            ),
            const SizedBox(height: 20),

            // LinkedIn
            _buildInputLabel('LinkedIn Profile (Optional)', isDark),
            const SizedBox(height: 8),
            TextFormField(
              controller: _linkedinController,
              keyboardType: TextInputType.url,
              decoration: _buildInputDecoration(
                hint: 'https://linkedin.com/in/yourprofile',
                icon: Icons.link,
                isDark: isDark,
              ),
            ),
            const SizedBox(height: 20),

            // Website
            _buildInputLabel('Personal Website (Optional)', isDark),
            const SizedBox(height: 8),
            TextFormField(
              controller: _websiteController,
              keyboardType: TextInputType.url,
              decoration: _buildInputDecoration(
                hint: 'https://yourwebsite.com',
                icon: Icons.language,
                isDark: isDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep4ProfilePicture(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.camera_alt_outlined,
            title: 'Profile Picture',
            subtitle: 'Add a professional photo',
            isDark: isDark,
          ),
          const SizedBox(height: 32),

          // Profile picture preview
          Center(
            child: Stack(
              children: [
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.darkElevated
                        : Colors.grey.shade100,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark
                          ? AppTheme.darkBorder
                          : Colors.grey.shade300,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            (isDark
                                    ? AppTheme.darkAccent
                                    : AppTheme.primaryColor)
                                .withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: _imageBytes != null
                        ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                        : _uploadedImageUrl != null
                        ? Image.network(_uploadedImageUrl!, fit: BoxFit.cover)
                        : Icon(
                            Icons.person,
                            size: 80,
                            color: AppTheme.getTextSecondary(context),
                          ),
                  ),
                ),
                if (_isUploadingImage)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(
                              color: Colors.white,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${(_uploadProgress * 100).round()}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.darkAccent
                            : AppTheme.primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.getBackgroundColor(context),
                          width: 3,
                        ),
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Tips
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 20,
                      color: isDark
                          ? AppTheme.darkAccent
                          : AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Photo Tips',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.getTextPrimary(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTip('Use a clear, professional headshot', isDark),
                _buildTip('Good lighting makes a difference', isDark),
                _buildTip('Smile! It builds trust with students', isDark),
                _buildTip('Neutral background is preferred', isDark),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Skip option
          Center(
            child: TextButton(
              onPressed: () {
                setState(() {
                  _selectedImage = null;
                  _imageBytes = null;
                });
              },
              child: Text(
                'Skip for now',
                style: TextStyle(color: AppTheme.getTextSecondary(context)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTip(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            size: 16,
            color: isDark ? AppTheme.darkSuccess : AppTheme.success,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.getTextSecondary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                .withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            size: 28,
            color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.getTextPrimary(context),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.getTextSecondary(context),
          ),
        ),
      ],
    );
  }

  Widget _buildInputLabel(String label, bool isDark) {
    return Text(
      label,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: AppTheme.getTextPrimary(context),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hint,
    required IconData icon,
    required bool isDark,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: AppTheme.getTextSecondary(context).withOpacity(0.6),
        fontSize: 14,
      ),
      prefixIcon: Icon(
        icon,
        color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
        size: 20,
      ),
      filled: true,
      fillColor: isDark ? AppTheme.darkElevated : Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark ? AppTheme.darkError : AppTheme.error,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

/// Separate StatefulWidget for Credential Dialog to handle image picker properly
class _CredentialDialog extends StatefulWidget {
  final bool isDark;
  final Function(String title, String issuer, String? imageUrl) onAdd;

  const _CredentialDialog({
    required this.isDark,
    required this.onAdd,
  });

  @override
  State<_CredentialDialog> createState() => _CredentialDialogState();
}

class _CredentialDialogState extends State<_CredentialDialog> {
  final _titleController = TextEditingController();
  final _issuerController = TextEditingController();
  Uint8List? _credentialImageBytes;
  String? _uploadedCredentialUrl;
  bool _isUploading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _issuerController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    if (_isUploading) return;
    
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      
      if (picked != null && mounted) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _credentialImageBytes = bytes;
          _isUploading = true;
        });

        try {
          final url = await uploadToCloudinaryFromXFile(picked);
          if (mounted) {
            setState(() {
              _uploadedCredentialUrl = url;
              _isUploading = false;
            });
          }
        } catch (e) {
          if (mounted) {
            setState(() => _isUploading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Upload failed: $e')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    
    return AlertDialog(
      backgroundColor: AppTheme.getCardColor(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Text(
        'Add Credential',
        style: TextStyle(color: AppTheme.getTextPrimary(context)),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'Credential Title (e.g., AWS Certified)',
                prefixIcon: Icon(
                  Icons.badge,
                  color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
                ),
                filled: true,
                fillColor: isDark ? AppTheme.darkElevated : Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _issuerController,
              decoration: InputDecoration(
                hintText: 'Issuing Organization (e.g., Amazon)',
                prefixIcon: Icon(
                  Icons.business,
                  color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
                ),
                filled: true,
                fillColor: isDark ? AppTheme.darkElevated : Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Certificate Image (Optional)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.getTextSecondary(context),
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickAndUploadImage,
              child: Container(
                width: double.infinity,
                height: 120,
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkElevated : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
                  ),
                ),
                child: _credentialImageBytes != null
                    ? Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: Image.memory(
                              _credentialImageBytes!,
                              width: double.infinity,
                              height: 120,
                              fit: BoxFit.cover,
                            ),
                          ),
                          if (_isUploading)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          if (_uploadedCredentialUrl != null)
                            Positioned(
                              right: 8,
                              top: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppTheme.success,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 32,
                            color: AppTheme.getTextSecondary(context),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap to add certificate image',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.getTextSecondary(context),
                            ),
                          ),
                          Text(
                            'Builds trust with students',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.getTextSecondary(context).withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: AppTheme.getTextSecondary(context)),
          ),
        ),
        ElevatedButton(
          onPressed: _isUploading
              ? null
              : () {
                  if (_titleController.text.isNotEmpty) {
                    widget.onAdd(
                      _titleController.text.trim(),
                      _issuerController.text.trim(),
                      _uploadedCredentialUrl,
                    );
                    Navigator.pop(context);
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
          ),
          child: _isUploading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Add'),
        ),
      ],
    );
  }
}
