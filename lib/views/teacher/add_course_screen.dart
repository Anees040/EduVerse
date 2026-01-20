import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:eduverse/services/auth_service.dart';
import 'package:eduverse/services/uploadToCloudinary.dart';
import 'package:eduverse/services/user_service.dart';
import 'package:eduverse/utils/app_theme.dart';

class AddCourseScreen extends StatefulWidget {
  const AddCourseScreen({super.key});

  @override
  State<AddCourseScreen> createState() => _AddCourseScreenState();
}

class _AddCourseScreenState extends State<AddCourseScreen> {
  final userService = UserService();
  final authService = AuthService();

  bool _loading = false;
  String _uploadStatus = ''; // Status message for user
  double _uploadProgress = 0.0; // Progress value 0.0 to 1.0
  String _currentStage = 'image'; // 'image', 'video', 'saving'

  final _formKey = GlobalKey<FormState>();
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController videoController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  XFile? selectedVideo;
  XFile? coverImageFile;
  Uint8List? coverImageBytes; // For web display

  String? coverImagePath; // later can be set using image picker

  Future<void> uploadAndSaveCourse() async {
    if (!_formKey.currentState!.validate()) return;
    if (coverImageFile == null || selectedVideo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select cover image and video")),
      );
      return;
    }

    setState(() {
      _loading = true;
      _uploadProgress = 0.0;
      _currentStage = 'image';
      _uploadStatus = 'Uploading cover image...';
    });

    try {
      // Upload cover image with progress (image is fast, so we'll simulate 10% of total)
      String? imageUrl = await uploadToCloudinaryWithSimulatedProgress(
        coverImageFile!,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _uploadProgress = progress * 0.1; // Image is 10% of total
            });
          }
        },
      );

      if (imageUrl == null) {
        throw Exception("Failed to upload cover image");
      }

      setState(() {
        _currentStage = 'video';
        _uploadProgress = 0.1;
        _uploadStatus = 'Uploading video...';
      });

      // Upload video with progress (video is 80% of total)
      String? videoUrl = await uploadToCloudinaryWithSimulatedProgress(
        selectedVideo!,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _uploadProgress = 0.1 + (progress * 0.8); // 10% to 90%
            });
          }
        },
      );

      if (videoUrl == null) {
        throw Exception("Failed to upload video");
      }

      setState(() {
        _currentStage = 'saving';
        _uploadProgress = 0.9;
        _uploadStatus = 'Saving course to database...';
      });

      await userService.saveCourseTofirebase(
        teacherUid: authService.currentUser!.uid,
        imageUrl: imageUrl,
        videoUrl: videoUrl,
        title: titleController.text,
        description: descriptionController.text,
      );

      setState(() {
        _uploadProgress = 1.0;
      });

      // Success is handled in onPressed
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _uploadStatus = '';
          _uploadProgress = 0.0;
        });
      }
    }
  }

  Future<void> pickVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);

    if (video != null) {
      setState(() {
        selectedVideo = video;
      });
    }
  }

  Future<void> pickCoverImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        coverImageFile = image;
        coverImageBytes = bytes;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Add Course", style: TextStyle(color: Colors.white)),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: isDark
                ? AppTheme.darkPrimaryGradient
                : AppTheme.primaryGradient,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Cover Image Section
            GestureDetector(
              onTap: pickCoverImage,
              child: Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard : Colors.grey.shade200,
                  gradient: coverImageBytes == null
                      ? LinearGradient(
                          colors: isDark
                              ? [AppTheme.darkCard, AppTheme.darkSurface]
                              : [Colors.grey.shade300, Colors.grey.shade200],
                        )
                      : null,
                ),
                child: coverImageBytes == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate,
                            size: 60,
                            color:
                                (isDark
                                        ? AppTheme.darkPrimaryLight
                                        : AppTheme.primaryColor)
                                    .withOpacity(0.5),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Tap to add cover image",
                            style: TextStyle(
                              color: AppTheme.getTextSecondary(context),
                            ),
                          ),
                        ],
                      )
                    : Image.memory(
                        coverImageBytes!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
              ),
            ),

            const SizedBox(height: 16),

            /// Form Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Course Details",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.getTextPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 16),

                    /// Title
                    TextFormField(
                      controller: titleController,
                      style: TextStyle(color: AppTheme.getTextPrimary(context)),
                      decoration: InputDecoration(
                        labelText: "Course Title",
                        labelStyle: TextStyle(
                          color: AppTheme.getTextSecondary(context),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppTheme.getBorderColor(context),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppTheme.getBorderColor(context),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark
                                ? AppTheme.darkPrimaryLight
                                : AppTheme.primaryColor,
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: AppTheme.getCardColor(context),
                      ),
                      validator: (value) =>
                          value!.isEmpty ? "Title is required" : null,
                    ),
                    const SizedBox(height: 16),

                    /// Description
                    TextFormField(
                      controller: descriptionController,
                      maxLines: 4,
                      style: TextStyle(color: AppTheme.getTextPrimary(context)),
                      decoration: InputDecoration(
                        labelText: "Course Description",
                        labelStyle: TextStyle(
                          color: AppTheme.getTextSecondary(context),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppTheme.getBorderColor(context),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppTheme.getBorderColor(context),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark
                                ? AppTheme.darkPrimaryLight
                                : AppTheme.primaryColor,
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: AppTheme.getCardColor(context),
                      ),
                      validator: (value) =>
                          value!.isEmpty ? "Description is required" : null,
                    ),
                    const SizedBox(height: 16),

                    /// Video Picker
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Course Video",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.getTextPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 8),

                        GestureDetector(
                          onTap: pickVideo,
                          child: Container(
                            width: double.infinity,
                            height: 120,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: AppTheme.getBorderColor(context),
                              ),
                              borderRadius: BorderRadius.circular(12),
                              color: AppTheme.getCardColor(context),
                            ),
                            child: selectedVideo == null
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.video_library,
                                        size: 40,
                                        color: AppTheme.getTextSecondary(
                                          context,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "Tap to select course video",
                                        style: TextStyle(
                                          color: AppTheme.getTextSecondary(
                                            context,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        color: AppTheme.getSuccessColor(
                                          context,
                                        ),
                                        size: 30,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Video selected",
                                        style: TextStyle(
                                          color: AppTheme.getTextPrimary(
                                            context,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    /// Submit Button
                    Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color:
                                (isDark
                                        ? AppTheme.darkAccent
                                        : const Color.fromARGB(255, 17, 51, 96))
                                    .withOpacity(0.4),
                            blurRadius: 10,
                            spreadRadius: 1,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark
                              ? AppTheme.darkAccent
                              : const Color.fromARGB(255, 17, 51, 96),
                          foregroundColor: const Color(0xFFF0F8FF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _loading
                            ? null
                            : () async {
                                if (!_formKey.currentState!.validate() ||
                                    selectedVideo == null ||
                                    coverImageFile == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Please fill all fields"),
                                    ),
                                  );
                                  return;
                                }
                                try {
                                  await uploadAndSaveCourse();

                                  if (mounted) {
                                    // Show success dialog instead of snackbar
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (ctx) {
                                        final dialogIsDark =
                                            AppTheme.isDarkMode(ctx);
                                        return AlertDialog(
                                          backgroundColor: dialogIsDark
                                              ? AppTheme.darkCard
                                              : Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  16,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.success
                                                      .withOpacity(0.1),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  Icons.check_circle,
                                                  color: AppTheme.success,
                                                  size: 64,
                                                ),
                                              ),
                                              const SizedBox(height: 20),
                                              Text(
                                                'Course Created!',
                                                style: TextStyle(
                                                  fontSize: 24,
                                                  fontWeight: FontWeight.bold,
                                                  color: dialogIsDark
                                                      ? AppTheme.darkTextPrimary
                                                      : Colors.black87,
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              Text(
                                                'Your course "${titleController.text}" has been uploaded successfully.',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: dialogIsDark
                                                      ? AppTheme
                                                            .darkTextSecondary
                                                      : Colors.grey.shade600,
                                                ),
                                              ),
                                              const SizedBox(height: 24),
                                              SizedBox(
                                                width: double.infinity,
                                                child: ElevatedButton(
                                                  onPressed: () {
                                                    Navigator.pop(
                                                      ctx,
                                                    ); // Close dialog
                                                    Navigator.pop(
                                                      context,
                                                      true,
                                                    ); // Go back to courses
                                                  },
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        dialogIsDark
                                                        ? AppTheme.darkAccent
                                                        : AppTheme.primaryColor,
                                                    foregroundColor:
                                                        Colors.white,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 14,
                                                        ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                  ),
                                                  child: const Text(
                                                    'Go to Courses',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    );
                                  }
                                } catch (e) {
                                  // Show error SnackBar
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        "Failed to upload course: $e",
                                      ),
                                      backgroundColor: Colors.red,
                                      duration: const Duration(seconds: 3),
                                    ),
                                  );
                                }
                              },
                        child: _loading
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    "Uploading...",
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              )
                            : const Text(
                                "Add Course",
                                style: TextStyle(fontSize: 16),
                              ),
                      ),
                    ),
                    // Upload status message with progress bar
                    if (_loading && _uploadStatus.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color:
                              (isDark
                                      ? AppTheme.darkPrimaryLight
                                      : AppTheme.primaryColor)
                                  .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                (isDark
                                        ? AppTheme.darkPrimaryLight
                                        : AppTheme.primaryColor)
                                    .withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _currentStage == 'image'
                                      ? Icons.image
                                      : _currentStage == 'video'
                                      ? Icons.videocam
                                      : Icons.save,
                                  color: isDark
                                      ? AppTheme.darkPrimaryLight
                                      : AppTheme.primaryColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _uploadStatus,
                                    style: TextStyle(
                                      color: isDark
                                          ? AppTheme.darkTextPrimary
                                          : Colors.black87,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${(_uploadProgress * 100).toInt()}%',
                                  style: TextStyle(
                                    color: isDark
                                        ? AppTheme.darkAccent
                                        : AppTheme.primaryColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: _uploadProgress,
                                backgroundColor: isDark
                                    ? AppTheme.darkBorder
                                    : Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isDark
                                      ? AppTheme.darkAccent
                                      : AppTheme.primaryColor,
                                ),
                                minHeight: 10,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Please wait, this may take a few minutes...',
                              style: TextStyle(
                                color: isDark
                                    ? AppTheme.darkTextSecondary
                                    : Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
