import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:eduverse/services/auth_service.dart';
import 'package:eduverse/services/course_service.dart';
import 'package:eduverse/services/uploadToCloudinary.dart';
import 'package:eduverse/models/course_model.dart';
import 'package:eduverse/utils/app_theme.dart';
import 'package:eduverse/views/teacher/teacher_course_manage_screen.dart';

/// Professional Course Setup Wizard - Coursera/Udemy Style
/// 3-step process: Identity → Branding → Pricing
class CreateCourseWizard extends StatefulWidget {
  const CreateCourseWizard({super.key});

  @override
  State<CreateCourseWizard> createState() => _CreateCourseWizardState();
}

class _CreateCourseWizardState extends State<CreateCourseWizard>
    with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final CourseService _courseService = CourseService();
  final ImagePicker _picker = ImagePicker();

  // Form keys for each step
  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();
  final _step3FormKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _subtitleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _discountPriceController =
      TextEditingController();

  // Stepper state
  int _currentStep = 0;
  bool _isLoading = false;

  // Step 1: Course Identity
  String _selectedCategory = CourseCategories.categories.first;

  // Step 2: Branding & Media
  XFile? _thumbnailFile;
  Uint8List? _thumbnailBytes;
  XFile? _previewVideoFile;

  // Step 3: Pricing
  bool _isFree = true;
  String _selectedDifficulty = 'beginner';

  // Upload progress
  String _uploadStatus = '';
  double _uploadProgress = 0.0;
  String _currentUploadStage = '';

  // Animation controller
  late AnimationController _progressAnimationController;

  bool get isDark => AppTheme.isDarkMode(context);

  @override
  void initState() {
    super.initState();
    _progressAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _discountPriceController.dispose();
    _progressAnimationController.dispose();
    super.dispose();
  }

  // === STEP NAVIGATION ===

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _step1FormKey.currentState?.validate() ?? false;
      case 1:
        if (_thumbnailFile == null) {
          _showErrorSnackBar('Please upload a course thumbnail');
          return false;
        }
        return true;
      case 2:
        if (!_isFree) {
          return _step3FormKey.currentState?.validate() ?? false;
        }
        return true;
      default:
        return true;
    }
  }

  void _nextStep() {
    if (_validateCurrentStep()) {
      if (_currentStep < 2) {
        setState(() => _currentStep++);
      } else {
        _createCourse();
      }
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  // === MEDIA PICKING ===

  Future<void> _pickThumbnail() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _thumbnailFile = image;
          _thumbnailBytes = bytes;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick image: $e');
    }
  }

  Future<void> _pickPreviewVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );

      if (video != null) {
        setState(() {
          _previewVideoFile = video;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick video: $e');
    }
  }

  // === COURSE CREATION ===

  Future<void> _createCourse() async {
    if (!_validateCurrentStep()) return;

    setState(() {
      _isLoading = true;
      _uploadProgress = 0.0;
      _uploadStatus = 'Preparing upload...';
      _currentUploadStage = 'preparing';
    });

    try {
      String? thumbnailUrl;
      String? previewVideoUrl;

      // Upload thumbnail
      setState(() {
        _currentUploadStage = 'thumbnail';
        _uploadStatus = 'Uploading thumbnail...';
      });

      thumbnailUrl = await uploadToCloudinaryWithSimulatedProgress(
        _thumbnailFile!,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _uploadProgress =
                  progress * (_previewVideoFile != null ? 0.3 : 0.8);
            });
          }
        },
      );

      if (thumbnailUrl == null) {
        throw Exception('Failed to upload thumbnail');
      }

      // Upload preview video (if provided)
      if (_previewVideoFile != null) {
        setState(() {
          _currentUploadStage = 'video';
          _uploadStatus = 'Uploading preview video...';
        });

        previewVideoUrl = await uploadToCloudinaryWithSimulatedProgress(
          _previewVideoFile!,
          onProgress: (progress) {
            if (mounted) {
              setState(() {
                _uploadProgress = 0.3 + (progress * 0.5);
              });
            }
          },
        );

        if (previewVideoUrl == null) {
          throw Exception('Failed to upload preview video');
        }
      }

      // Save course to database
      setState(() {
        _currentUploadStage = 'saving';
        _uploadStatus = 'Saving course...';
        _uploadProgress = _previewVideoFile != null ? 0.8 : 0.9;
      });

      final courseUid = await _courseService.createCourseWithMetadata(
        teacherUid: _authService.currentUser!.uid,
        title: _titleController.text.trim(),
        subtitle: _subtitleController.text.trim().isNotEmpty
            ? _subtitleController.text.trim()
            : null,
        description: _descriptionController.text.trim(),
        imageUrl: thumbnailUrl,
        previewVideoUrl: previewVideoUrl,
        category: _selectedCategory,
        difficulty: _selectedDifficulty,
        isFree: _isFree,
        price: _isFree ? 0.0 : double.tryParse(_priceController.text) ?? 0.0,
        discountedPrice: _isFree || _discountPriceController.text.isEmpty
            ? null
            : double.tryParse(_discountPriceController.text),
      );

      setState(() {
        _uploadProgress = 1.0;
        _uploadStatus = 'Course created successfully!';
      });

      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        _showSuccessDialog(courseUid, thumbnailUrl);
      }
    } catch (e) {
      _showErrorSnackBar('Failed to create course: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _uploadStatus = '';
          _uploadProgress = 0.0;
        });
      }
    }
  }

  void _showSuccessDialog(String courseUid, String imageUrl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final dialogIsDark = AppTheme.isDarkMode(ctx);
        return AlertDialog(
          backgroundColor: dialogIsDark ? AppTheme.darkCard : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: dialogIsDark
                        ? [
                            AppTheme.darkAccent.withOpacity(0.2),
                            AppTheme.darkPrimary.withOpacity(0.2),
                          ]
                        : [
                            AppTheme.success.withOpacity(0.1),
                            AppTheme.accentColor.withOpacity(0.1),
                          ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.celebration_rounded,
                  color: dialogIsDark ? AppTheme.darkAccent : AppTheme.success,
                  size: 64,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Course Created! 🎉',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.getTextPrimary(ctx),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '"${_titleController.text}" is ready!\nNow add lessons to your course.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.getTextSecondary(ctx),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx); // Close dialog
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TeacherCourseManageScreen(
                          courseUid: courseUid,
                          courseTitle: _titleController.text.trim(),
                          imageUrl: imageUrl,
                          description: _descriptionController.text.trim(),
                          enrolledCount: 0,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  label: const Text('Add Lessons'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: dialogIsDark
                        ? AppTheme.darkAccent
                        : AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx); // Close dialog
                  Navigator.pop(context, true); // Go back to courses
                },
                child: Text(
                  'Add Lessons Later',
                  style: TextStyle(
                    color: AppTheme.getTextSecondary(ctx),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // === BUILD METHODS ===

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildProgressIndicator(),
          Expanded(
            child: _isLoading ? _buildUploadProgress() : _buildCurrentStep(),
          ),
          if (!_isLoading) _buildNavigationButtons(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.white),
        onPressed: () => _showExitConfirmation(),
      ),
      title: const Text(
        'Create New Course',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
      centerTitle: true,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? AppTheme.darkPrimaryGradient
              : AppTheme.primaryGradient,
        ),
      ),
      elevation: 0,
    );
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Discard Course?',
          style: TextStyle(color: AppTheme.getTextPrimary(ctx)),
        ),
        content: Text(
          'Your progress will be lost. Are you sure you want to exit?',
          style: TextStyle(color: AppTheme.getTextSecondary(ctx)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.getTextSecondary(ctx)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final steps = ['Identity', 'Branding', 'Pricing'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (index) {
          if (index.isOdd) {
            // Connector line
            final stepIndex = index ~/ 2;
            final isCompleted = stepIndex < _currentStep;
            return Expanded(
              child: Container(
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: isCompleted
                      ? (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                      : AppTheme.getBorderColor(context),
                ),
              ),
            );
          } else {
            // Step circle
            final stepIndex = index ~/ 2;
            final isActive = stepIndex == _currentStep;
            final isCompleted = stepIndex < _currentStep;
            return _buildStepCircle(
              stepIndex + 1,
              steps[stepIndex],
              isActive,
              isCompleted,
            );
          }
        }),
      ),
    );
  }

  Widget _buildStepCircle(
    int number,
    String label,
    bool isActive,
    bool isCompleted,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: (isActive || isCompleted)
                ? LinearGradient(
                    colors: isDark
                        ? [AppTheme.darkAccent, AppTheme.darkPrimary]
                        : [AppTheme.primaryColor, AppTheme.primaryLight],
                  )
                : null,
            color: (isActive || isCompleted)
                ? null
                : AppTheme.getBorderColor(context),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color:
                          (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                              .withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : Text(
                    '$number',
                    style: TextStyle(
                      color: (isActive || isCompleted)
                          ? Colors.white
                          : AppTheme.getTextSecondary(context),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: isActive
                ? (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                : AppTheme.getTextSecondary(context),
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentStep() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: SingleChildScrollView(
        key: ValueKey(_currentStep),
        padding: const EdgeInsets.all(24),
        child: _buildStepContent(),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1CourseIdentity();
      case 1:
        return _buildStep2Branding();
      case 2:
        return _buildStep3Pricing();
      default:
        return const SizedBox();
    }
  }

  // === STEP 1: COURSE IDENTITY ===

  Widget _buildStep1CourseIdentity() {
    return Form(
      key: _step1FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.school_outlined,
            title: 'Course Identity',
            subtitle: 'Give your course a compelling title and description',
          ),
          const SizedBox(height: 24),

          // Title Field
          _buildLabel('Course Title', isRequired: true),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _titleController,
            hint: 'e.g., Complete Flutter Development Bootcamp',
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a course title';
              }
              if (value.trim().length < 10) {
                return 'Title should be at least 10 characters';
              }
              return null;
            },
            maxLength: 100,
          ),
          const SizedBox(height: 20),

          // Subtitle Field
          _buildLabel('Subtitle', isRequired: false),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _subtitleController,
            hint: 'e.g., Build iOS & Android apps from scratch',
            maxLength: 150,
          ),
          const SizedBox(height: 20),

          // Category Dropdown
          _buildLabel('Category', isRequired: true),
          const SizedBox(height: 8),
          _buildDropdown(
            value: _selectedCategory,
            items: CourseCategories.categories,
            onChanged: (value) => setState(() => _selectedCategory = value!),
            icon: Icons.category_outlined,
          ),
          const SizedBox(height: 20),

          // Description Field
          _buildLabel('Description', isRequired: true),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _descriptionController,
            hint: 'Describe what students will learn in this course...',
            maxLines: 6,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a description';
              }
              if (value.trim().length < 50) {
                return 'Description should be at least 50 characters';
              }
              return null;
            },
            maxLength: 2000,
          ),
        ],
      ),
    );
  }

  // === STEP 2: BRANDING & MEDIA ===

  Widget _buildStep2Branding() {
    return Form(
      key: _step2FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.palette_outlined,
            title: 'Branding & Media',
            subtitle: 'Make your course visually appealing',
          ),
          const SizedBox(height: 24),

          // Thumbnail Upload
          _buildLabel('Course Thumbnail', isRequired: true),
          const SizedBox(height: 8),
          _buildThumbnailUpload(),
          const SizedBox(height: 8),
          Text(
            'Recommended: 1280x720 (16:9). High-quality images attract more students.',
            style: TextStyle(
              color: AppTheme.getTextSecondary(context),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 28),

          // Preview Video Upload
          _buildLabel('Preview Video (Optional)', isRequired: false),
          const SizedBox(height: 8),
          _buildVideoUpload(),
          const SizedBox(height: 8),
          Text(
            'A short trailer (2-5 minutes) helps students understand your course better.',
            style: TextStyle(
              color: AppTheme.getTextSecondary(context),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnailUpload() {
    return GestureDetector(
      onTap: _pickThumbnail,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _thumbnailBytes != null
                ? (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                : AppTheme.getBorderColor(context),
            width: _thumbnailBytes != null ? 2 : 1,
          ),
          color: AppTheme.getCardColor(context),
          boxShadow: _thumbnailBytes != null
              ? [
                  BoxShadow(
                    color:
                        (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                            .withOpacity(0.2),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: _thumbnailBytes != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.memory(_thumbnailBytes!, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Row(
                      children: [
                        _buildMediaActionButton(
                          icon: Icons.edit,
                          onTap: _pickThumbnail,
                          tooltip: 'Change',
                        ),
                        const SizedBox(width: 8),
                        _buildMediaActionButton(
                          icon: Icons.delete_outline,
                          onTap: () => setState(() {
                            _thumbnailFile = null;
                            _thumbnailBytes = null;
                          }),
                          tooltip: 'Remove',
                          isDestructive: true,
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : _buildUploadPlaceholder(
                icon: Icons.add_photo_alternate_outlined,
                title: 'Tap to upload thumbnail',
                subtitle: 'PNG, JPG up to 10MB',
              ),
      ),
    );
  }

  Widget _buildVideoUpload() {
    return GestureDetector(
      onTap: _pickPreviewVideo,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _previewVideoFile != null
                ? (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                : AppTheme.getBorderColor(context),
            width: _previewVideoFile != null ? 2 : 1,
          ),
          color: AppTheme.getCardColor(context),
        ),
        child: _previewVideoFile != null
            ? Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                              .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.videocam,
                      color: isDark
                          ? AppTheme.darkAccent
                          : AppTheme.primaryColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Video Selected',
                          style: TextStyle(
                            color: AppTheme.getTextPrimary(context),
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _previewVideoFile!.name,
                          style: TextStyle(
                            color: AppTheme.getTextSecondary(context),
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildMediaActionButton(
                        icon: Icons.edit,
                        onTap: _pickPreviewVideo,
                        tooltip: 'Change',
                      ),
                      const SizedBox(width: 8),
                      _buildMediaActionButton(
                        icon: Icons.delete_outline,
                        onTap: () => setState(() => _previewVideoFile = null),
                        tooltip: 'Remove',
                        isDestructive: true,
                      ),
                    ],
                  ),
                ],
              )
            : _buildUploadPlaceholder(
                icon: Icons.video_library_outlined,
                title: 'Tap to upload preview video',
                subtitle: 'MP4, MOV up to 5 minutes',
              ),
      ),
    );
  }

  Widget _buildMediaActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
    bool isDestructive = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: (isDestructive ? AppTheme.error : AppTheme.getCardColor(context))
            .withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              icon,
              size: 20,
              color: isDestructive
                  ? Colors.white
                  : AppTheme.getTextSecondary(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadPlaceholder({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                .withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 36,
            color: (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                .withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: TextStyle(
            color: AppTheme.getTextPrimary(context),
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(
            color: AppTheme.getTextSecondary(context),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  // === STEP 3: PRICING & ACCESS ===

  Widget _buildStep3Pricing() {
    return Form(
      key: _step3FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.monetization_on_outlined,
            title: 'Pricing & Access',
            subtitle: 'Set your course pricing and difficulty level',
          ),
          const SizedBox(height: 24),

          // Free/Paid Toggle
          _buildLabel('Course Model', isRequired: true),
          const SizedBox(height: 12),
          _buildPricingToggle(),
          const SizedBox(height: 24),

          // Price Fields (conditional)
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: _isFree
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: _buildFreeCourseBanner(),
            secondChild: _buildPriceFields(),
          ),
          const SizedBox(height: 24),

          // Difficulty Level
          _buildLabel('Difficulty Level', isRequired: true),
          const SizedBox(height: 12),
          _buildDifficultySelector(),
        ],
      ),
    );
  }

  Widget _buildPricingToggle() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppTheme.getCardColor(context),
        border: Border.all(color: AppTheme.getBorderColor(context)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildToggleOption(
              icon: Icons.card_giftcard,
              label: 'Free',
              isSelected: _isFree,
              onTap: () => setState(() => _isFree = true),
            ),
          ),
          Expanded(
            child: _buildToggleOption(
              icon: Icons.attach_money,
              label: 'Paid',
              isSelected: !_isFree,
              onTap: () => setState(() => _isFree = false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleOption({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: isSelected
              ? LinearGradient(
                  colors: isDark
                      ? [AppTheme.darkAccent, AppTheme.darkPrimary]
                      : [AppTheme.primaryColor, AppTheme.primaryLight],
                )
              : null,
          color: isSelected ? null : Colors.transparent,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Colors.white
                  : AppTheme.getTextSecondary(context),
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : AppTheme.getTextSecondary(context),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFreeCourseBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: isDark
              ? [
                  AppTheme.darkSuccess.withOpacity(0.2),
                  AppTheme.darkAccent.withOpacity(0.1),
                ]
              : [
                  AppTheme.success.withOpacity(0.1),
                  AppTheme.accentColor.withOpacity(0.05),
                ],
        ),
        border: Border.all(
          color: (isDark ? AppTheme.darkSuccess : AppTheme.success).withOpacity(
            0.3,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isDark ? AppTheme.darkSuccess : AppTheme.success)
                  .withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.celebration,
              color: isDark ? AppTheme.darkSuccess : AppTheme.success,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Free Course',
                  style: TextStyle(
                    color: AppTheme.getTextPrimary(context),
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your course will be accessible to all students at no cost.',
                  style: TextStyle(
                    color: AppTheme.getTextSecondary(context),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Regular Price (\$)', isRequired: true),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _priceController,
          hint: '49.99',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          prefixIcon: Icons.attach_money,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a price';
            }
            final price = double.tryParse(value);
            if (price == null || price <= 0) {
              return 'Please enter a valid price';
            }
            return null;
          },
        ),
        const SizedBox(height: 20),
        _buildLabel('Discounted Price (\$)', isRequired: false),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _discountPriceController,
          hint: '29.99 (optional)',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          prefixIcon: Icons.local_offer_outlined,
        ),
        const SizedBox(height: 8),
        Text(
          'Leave empty if you don\'t want to offer a discount.',
          style: TextStyle(
            color: AppTheme.getTextSecondary(context),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildDifficultySelector() {
    final difficulties = [
      {'value': 'beginner', 'label': 'Beginner', 'icon': Icons.emoji_people},
      {
        'value': 'intermediate',
        'label': 'Intermediate',
        'icon': Icons.trending_up,
      },
      {'value': 'advanced', 'label': 'Advanced', 'icon': Icons.psychology},
    ];

    return Row(
      children: difficulties.map((diff) {
        final isSelected = _selectedDifficulty == diff['value'];
        return Expanded(
          child: GestureDetector(
            onTap: () =>
                setState(() => _selectedDifficulty = diff['value'] as String),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(
                right: diff['value'] != 'advanced' ? 12 : 0,
              ),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: isSelected
                    ? LinearGradient(
                        colors: isDark
                            ? [AppTheme.darkAccent, AppTheme.darkPrimary]
                            : [AppTheme.primaryColor, AppTheme.primaryLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isSelected ? null : AppTheme.getCardColor(context),
                border: Border.all(
                  color: isSelected
                      ? Colors.transparent
                      : AppTheme.getBorderColor(context),
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color:
                              (isDark
                                      ? AppTheme.darkAccent
                                      : AppTheme.primaryColor)
                                  .withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Column(
                children: [
                  Icon(
                    diff['icon'] as IconData,
                    color: isSelected
                        ? Colors.white
                        : AppTheme.getTextSecondary(context),
                    size: 26,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    diff['label'] as String,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : AppTheme.getTextPrimary(context),
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // === UPLOAD PROGRESS ===

  Widget _buildUploadProgress() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated progress circle
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: CircularProgressIndicator(
                    value: _uploadProgress,
                    strokeWidth: 8,
                    backgroundColor: AppTheme.getBorderColor(context),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getUploadStageIcon(),
                      size: 36,
                      color: isDark
                          ? AppTheme.darkAccent
                          : AppTheme.primaryColor,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(_uploadProgress * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.getTextPrimary(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              _uploadStatus,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppTheme.getTextPrimary(context),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Please wait, this may take a few minutes...',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.getTextSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getUploadStageIcon() {
    switch (_currentUploadStage) {
      case 'thumbnail':
        return Icons.image;
      case 'video':
        return Icons.videocam;
      case 'saving':
        return Icons.cloud_upload;
      default:
        return Icons.hourglass_empty;
    }
  }

  // === NAVIGATION BUTTONS ===

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _previousStep,
                  icon: const Icon(Icons.arrow_back, size: 20),
                  label: const Text('Back'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.getTextSecondary(context),
                    side: BorderSide(color: AppTheme.getBorderColor(context)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            if (_currentStep > 0) const SizedBox(width: 16),
            Expanded(
              flex: _currentStep > 0 ? 2 : 1,
              child: ElevatedButton.icon(
                onPressed: _nextStep,
                icon: Icon(
                  _currentStep == 2 ? Icons.check : Icons.arrow_forward,
                  size: 20,
                ),
                label: Text(_currentStep == 2 ? 'Create Course' : 'Continue'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark
                      ? AppTheme.darkAccent
                      : AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // === SHARED UI COMPONENTS ===

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      AppTheme.darkAccent.withOpacity(0.2),
                      AppTheme.darkPrimary.withOpacity(0.2),
                    ]
                  : [
                      AppTheme.primaryColor.withOpacity(0.1),
                      AppTheme.primaryLight.withOpacity(0.1),
                    ],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            size: 28,
            color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 22,
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
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text, {required bool isRequired}) {
    return Row(
      children: [
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.getTextPrimary(context),
          ),
        ),
        if (isRequired)
          Text(
            ' *',
            style: TextStyle(
              color: AppTheme.error,
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    int? maxLength,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    IconData? prefixIcon,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: TextStyle(color: AppTheme.getTextPrimary(context), fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppTheme.getTextHint(context)),
        prefixIcon: prefixIcon != null
            ? Icon(
                prefixIcon,
                color: AppTheme.getTextSecondary(context),
                size: 22,
              )
            : null,
        filled: true,
        fillColor: AppTheme.getCardColor(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppTheme.getBorderColor(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppTheme.getBorderColor(context)),
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
          borderSide: BorderSide(color: AppTheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppTheme.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        counterStyle: TextStyle(color: AppTheme.getTextSecondary(context)),
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.getBorderColor(context)),
        color: AppTheme.getCardColor(context),
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        onChanged: onChanged,
        isExpanded: true,
        decoration: InputDecoration(
          prefixIcon: Icon(
            icon,
            color: AppTheme.getTextSecondary(context),
            size: 22,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
        ),
        dropdownColor: AppTheme.getCardColor(context),
        style: TextStyle(color: AppTheme.getTextPrimary(context), fontSize: 15),
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: AppTheme.getTextSecondary(context),
        ),
        items: items.map((item) {
          return DropdownMenuItem(value: item, child: Text(item));
        }).toList(),
      ),
    );
  }
}
