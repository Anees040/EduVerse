import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:eduverse/services/gemini_api_service.dart';
import 'package:eduverse/utils/app_theme.dart';

class MathwayHelpScreen extends StatefulWidget {
  const MathwayHelpScreen({super.key});

  @override
  State<MathwayHelpScreen> createState() => _MathwayHelpScreenState();
}

class _MathwayHelpScreenState extends State<MathwayHelpScreen> {
  Uint8List? _imageBytes;
  // ignore: unused_field
  XFile? _imageFile;
  bool isLoading = false;
  String aiResponse = "";

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImageFromGallery() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _imageFile = pickedFile;
          _imageBytes = bytes;
        });
        await _analyzeImage(bytes);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error picking image: $e")));
    }
  }

  Future<void> _pickImageFromCamera() async {
    if (kIsWeb) {
      // On web, camera opens file picker - inform user
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Camera not available on web. Please use Gallery instead.",
          ),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _imageFile = pickedFile;
          _imageBytes = bytes;
        });
        await _analyzeImage(bytes);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  /// Analyze image using the AI service (via Cloud Function)
  /// This ensures CORS compliance and keeps API keys secure
  Future<void> _analyzeImage(Uint8List imageBytes) async {
    setState(() {
      isLoading = true;
      aiResponse = "";
    });

    try {
      final base64Image = base64Encode(imageBytes);

      // Use the centralized AI service which calls Cloud Function
      final result = await aiService.analyzeImage(
        base64Image,
        prompt:
            "Please help me solve this homework problem. Explain step by step. If it's a math problem, show all work clearly.",
      );

      setState(() {
        aiResponse = result;
      });
    } catch (e) {
      setState(() {
        aiResponse = "Error: Unable to analyze image. Please try again.";
      });
    } finally {
      setState(() {
        isLoading = false;
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
        title: const Text(
          "Homework Help",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: isDark
                ? AppTheme.darkPrimaryGradient
                : AppTheme.primaryGradient,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: isDark
                    ? AppTheme.darkPrimaryGradient
                    : AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withOpacity(0.4)
                        : AppTheme.primaryColor.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(Icons.camera_alt, color: Colors.white, size: 40),
                  const SizedBox(height: 12),
                  const Text(
                    "Snap & Solve",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Take a photo of your homework and get instant help!",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Image Preview Area
            Container(
              width: double.infinity,
              height: 220,
              decoration: BoxDecoration(
                color: AppTheme.getCardColor(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.getBorderColor(context),
                  width: isDark ? 1 : 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withOpacity(0.3)
                        : Colors.grey.shade200,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _imageBytes != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.memory(
                        _imageBytes!,
                        fit: BoxFit.contain,
                        width: double.infinity,
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_outlined,
                          size: 60,
                          color: AppTheme.getTextSecondary(context),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "No image selected",
                          style: TextStyle(
                            color: AppTheme.getTextSecondary(context),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Use the buttons below to capture or select",
                          style: TextStyle(
                            color: AppTheme.getTextHint(context),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
            ),

            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    context: context,
                    icon: Icons.photo_library,
                    label: "Gallery",
                    onTap: _pickImageFromGallery,
                    isPrimary: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildActionButton(
                    context: context,
                    icon: Icons.camera_alt,
                    label: "Camera",
                    onTap: _pickImageFromCamera,
                    isPrimary: false,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Loading or Response
            if (isLoading)
              Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(
                      color: AppTheme.getPrimaryColor(context),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Analyzing your homework...",
                      style: TextStyle(
                        color: AppTheme.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              )
            else if (aiResponse.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.getCardColor(context),
                  borderRadius: BorderRadius.circular(16),
                  border: isDark
                      ? Border.all(color: AppTheme.getBorderColor(context))
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withOpacity(0.3)
                          : Colors.grey.shade200,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.getPrimaryColor(
                              context,
                            ).withOpacity(isDark ? 0.2 : 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.auto_awesome,
                            color: AppTheme.getPrimaryColor(context),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "Solution",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.getTextPrimary(context),
                          ),
                        ),
                      ],
                    ),
                    Divider(
                      height: 24,
                      color: AppTheme.getBorderColor(context),
                    ),
                    SelectableText(
                      aiResponse,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        color: AppTheme.getTextPrimary(context),
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

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isPrimary,
  }) {
    final isDark = AppTheme.isDarkMode(context);
    final primaryColor = AppTheme.getPrimaryColor(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: isPrimary
              ? (isDark
                    ? AppTheme.darkPrimaryGradient
                    : AppTheme.primaryGradient)
              : null,
          color: isPrimary ? null : AppTheme.getCardColor(context),
          borderRadius: BorderRadius.circular(14),
          border: isPrimary ? null : Border.all(color: primaryColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: isPrimary
                  ? (isDark
                        ? Colors.black.withOpacity(0.4)
                        : AppTheme.primaryColor.withOpacity(0.3))
                  : (isDark
                        ? Colors.black.withOpacity(0.3)
                        : Colors.grey.shade200),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isPrimary ? Colors.white : primaryColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isPrimary ? Colors.white : primaryColor,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
