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
      _uploadStatus = 'Uploading cover image...';
    });
    
    try {
      String? imageUrl = await uploadToCloudinaryFromXFile(coverImageFile!);
      
      if (imageUrl == null) {
        throw Exception("Failed to upload cover image");
      }
      
      setState(() {
        _uploadStatus = 'Uploading video... (this may take a while)';
      });
      
      String? videoUrl = await uploadToCloudinaryFromXFile(selectedVideo!);

      if (videoUrl == null) {
        throw Exception("Failed to upload video");
      }
      
      setState(() {
        _uploadStatus = 'Saving course to database...';
      });

      await userService.saveCourseTofirebase(
        teacherUid: authService.currentUser!.uid,
        imageUrl : imageUrl,
        videoUrl : videoUrl,
        title : titleController.text,
        description : descriptionController.text, 
      );
      
      // Success is handled in onPressed
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _uploadStatus = '';
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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Add Course", style: TextStyle(color: Colors.white)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
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
                  color: Colors.grey.shade200,
                  gradient: coverImageBytes == null ? LinearGradient(
                    colors: [Colors.grey.shade300, Colors.grey.shade200],
                  ) : null,
                ),
                child: coverImageBytes == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate, size: 60, color: AppTheme.primaryColor.withOpacity(0.5)),
                          const SizedBox(height: 8),
                          Text("Tap to add cover image", style: TextStyle(color: Colors.grey.shade600)),
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
                    const Text(
                      "Course Details",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),

                    /// Title
                    TextFormField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: "Course Title",
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value!.isEmpty ? "Title is required" : null,
                    ),
                    const SizedBox(height: 16),

                    /// Description
                    TextFormField(
                      controller: descriptionController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: "Course Description",
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value!.isEmpty ? "Description is required" : null,
                    ),
                    const SizedBox(height: 16),

                    /// Video Picker
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Course Video",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),

                        GestureDetector(
                          onTap: pickVideo,
                          child: Container(
                            width: double.infinity,
                            height: 120,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey.shade100,
                            ),
                            child: selectedVideo == null
                                ? const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.video_library,
                                          size: 40, color: Colors.grey),
                                      SizedBox(height: 8),
                                      Text("Tap to select course video"),
                                    ],
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.check_circle,
                                          color: Colors.green, size: 30),
                                      SizedBox(width: 8),
                                      Text("Video selected"),
                                    ],
                                  ),
                          ),
                        ),

                      ],
                    ),
                    const SizedBox(height: 14),
                    /// Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color.fromARGB(255, 17, 51, 96),
                        ),
                        onPressed: _loading ? null : () async {
                          if (!_formKey.currentState!.validate() || selectedVideo == null || coverImageFile == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text("Please fill all fields")),
                            );
                            return; 
                          }
                          try {
                            await uploadAndSaveCourse();

                            // Show success SnackBar
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Course uploaded successfully!"),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 2),
                              ),
                            );

                            // Optional: reset form & clear selected files
                            _formKey.currentState!.reset();
                            setState(() {
                              selectedVideo = null;
                              coverImageFile = null;
                              coverImageBytes = null;
                            });

                          } catch (e) {
                            // Show error SnackBar
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Failed to upload course: $e"),
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
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    "Uploading...",
                                    style: TextStyle(fontSize: 16, color: Colors.white),
                                  ),
                                ],
                              )
                            : const Text(
                                "Add Course",
                                style: TextStyle(fontSize: 16, color: Colors.white),
                              ),
                      ),
                    ),
                    // Upload status message
                    if (_loading && _uploadStatus.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                _uploadStatus,
                                style: TextStyle(
                                  color: Colors.blue.shade800,
                                  fontWeight: FontWeight.w500,
                                ),
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