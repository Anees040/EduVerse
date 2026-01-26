import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:eduverse/utils/app_theme.dart';

class StudentEditProfileScreen extends StatefulWidget {
  final String uid;
  final String currentName;
  final String? currentPhotoUrl;
  final String? currentHeadline;
  final String? currentBio;
  final List<String>? currentInterests;
  final String? currentLinkedIn;
  final String? currentGitHub;

  const StudentEditProfileScreen({
    super.key,
    required this.uid,
    required this.currentName,
    this.currentPhotoUrl,
    this.currentHeadline,
    this.currentBio,
    this.currentInterests,
    this.currentLinkedIn,
    this.currentGitHub,
  });

  @override
  State<StudentEditProfileScreen> createState() => _StudentEditProfileScreenState();
}

class _StudentEditProfileScreenState extends State<StudentEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _headlineController = TextEditingController();
  final _bioController = TextEditingController();
  final _linkedInController = TextEditingController();
  final _gitHubController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  bool _isUploading = false;
  String? _photoUrl;

  final List<String> _availableInterests = [
    'Web Development',
    'Mobile Development',
    'AI & Machine Learning',
    'Data Science',
    'Cloud Computing',
    'Cybersecurity',
    'UI/UX Design',
    'Blockchain',
    'Game Development',
    'DevOps',
    'Backend Development',
    'Frontend Development',
  ];

  Set<String> _selectedInterests = {};

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.currentName;
    _headlineController.text = widget.currentHeadline ?? '';
    _bioController.text = widget.currentBio ?? '';
    _linkedInController.text = widget.currentLinkedIn ?? '';
    _gitHubController.text = widget.currentGitHub ?? '';
    _photoUrl = widget.currentPhotoUrl;
    _selectedInterests = Set<String>.from(widget.currentInterests ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _headlineController.dispose();
    _bioController.dispose();
    _linkedInController.dispose();
    _gitHubController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = pickedFile;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _uploadImage() async {
    if (_selectedImage == null) return _photoUrl;

    try {
      final bytes = await _selectedImage!.readAsBytes();
      // Convert to base64 data URL for storage in Realtime Database
      final base64Image = base64Encode(bytes);
      return 'data:image/jpeg;base64,$base64Image';
    } catch (e) {
      debugPrint('Error processing image: $e');
      return _photoUrl;
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isUploading = true);

    try {
      // Upload image if selected
      String? uploadedPhotoUrl = await _uploadImage();

      // Prepare update data
      final updateData = <String, dynamic>{
        'name': _nameController.text.trim(),
        'headline': _headlineController.text.trim(),
        'bio': _bioController.text.trim(),
        'interests': _selectedInterests.toList(),
        'linkedIn': _linkedInController.text.trim(),
        'gitHub': _gitHubController.text.trim(),
      };

      if (uploadedPhotoUrl != null && uploadedPhotoUrl.isNotEmpty) {
        updateData['photoUrl'] = uploadedPhotoUrl;
      }

      // Update Firebase
      await FirebaseDatabase.instance
          .ref()
          .child('student')
          .child(widget.uid)
          .update(updateData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate update
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Widget _buildProfilePicture() {
    final isDark = AppTheme.isDarkMode(context);
    
    return Center(
      child: Stack(
        children: [
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? AppTheme.darkPrimaryLight : AppTheme.primaryColor,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isDark ? AppTheme.darkPrimaryLight : AppTheme.primaryColor)
                        .withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipOval(
                child: _selectedImage != null
                    ? (kIsWeb
                        ? Image.network(
                            _selectedImage!.path,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildPlaceholder(isDark),
                          )
                        : Image.file(
                            File(_selectedImage!.path),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildPlaceholder(isDark),
                          ))
                    : _photoUrl != null && _photoUrl!.isNotEmpty
                        ? Image.network(
                            _photoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildPlaceholder(isDark),
                          )
                        : _buildPlaceholder(isDark),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkPrimaryLight : AppTheme.primaryColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(bool isDark) {
    return Container(
      color: isDark ? AppTheme.darkCardColor : Colors.grey[200],
      child: Icon(
        Icons.person,
        size: 60,
        color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
      ),
    );
  }

  Widget _buildInterestChips() {
    final isDark = AppTheme.isDarkMode(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Interests (Select up to 5)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.getTextPrimary(context),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availableInterests.map((interest) {
            final isSelected = _selectedInterests.contains(interest);
            return FilterChip(
              label: Text(interest),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected && _selectedInterests.length < 5) {
                    _selectedInterests.add(interest);
                  } else if (!selected) {
                    _selectedInterests.remove(interest);
                  }
                });
              },
              backgroundColor: isDark ? AppTheme.darkCardColor : Colors.grey[200],
              selectedColor: (isDark ? AppTheme.darkPrimaryLight : AppTheme.primaryColor)
                  .withOpacity(0.2),
              checkmarkColor: isDark ? AppTheme.darkPrimaryLight : AppTheme.primaryColor,
              labelStyle: TextStyle(
                color: isSelected
                    ? (isDark ? AppTheme.darkPrimaryLight : AppTheme.primaryColor)
                    : AppTheme.getTextSecondary(context),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              side: BorderSide(
                color: isSelected
                    ? (isDark ? AppTheme.darkPrimaryLight : AppTheme.primaryColor)
                    : AppTheme.getBorderColor(context),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        title: Text(
          'Edit Profile',
          style: TextStyle(
            color: AppTheme.getTextPrimary(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.getCardColor(context),
        iconTheme: IconThemeData(
          color: AppTheme.getTextPrimary(context),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildProfilePicture(),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.edit),
                  label: const Text('Change Photo'),
                  style: TextButton.styleFrom(
                    foregroundColor: isDark ? AppTheme.darkPrimaryLight : AppTheme.primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Full Name
              TextFormField(
                controller: _nameController,
                style: TextStyle(color: AppTheme.getTextPrimary(context)),
                decoration: InputDecoration(
                  labelText: 'Full Name *',
                  labelStyle: TextStyle(color: AppTheme.getTextSecondary(context)),
                  prefixIcon: Icon(
                    Icons.person_outline,
                    color: AppTheme.getTextSecondary(context),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.getBorderColor(context)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? AppTheme.darkPrimaryLight : AppTheme.primaryColor,
                      width: 2,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Headline
              TextFormField(
                controller: _headlineController,
                style: TextStyle(color: AppTheme.getTextPrimary(context)),
                decoration: InputDecoration(
                  labelText: 'Headline',
                  labelStyle: TextStyle(color: AppTheme.getTextSecondary(context)),
                  hintText: 'e.g., Computer Science Student',
                  hintStyle: TextStyle(color: AppTheme.getTextSecondary(context).withOpacity(0.5)),
                  prefixIcon: Icon(
                    Icons.work_outline,
                    color: AppTheme.getTextSecondary(context),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.getBorderColor(context)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? AppTheme.darkPrimaryLight : AppTheme.primaryColor,
                      width: 2,
                    ),
                  ),
                ),
                maxLength: 60,
              ),
              const SizedBox(height: 16),

              // Bio
              TextFormField(
                controller: _bioController,
                style: TextStyle(color: AppTheme.getTextPrimary(context)),
                decoration: InputDecoration(
                  labelText: 'Bio',
                  labelStyle: TextStyle(color: AppTheme.getTextSecondary(context)),
                  hintText: 'Tell us about yourself...',
                  hintStyle: TextStyle(color: AppTheme.getTextSecondary(context).withOpacity(0.5)),
                  prefixIcon: Icon(
                    Icons.description_outlined,
                    color: AppTheme.getTextSecondary(context),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.getBorderColor(context)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? AppTheme.darkPrimaryLight : AppTheme.primaryColor,
                      width: 2,
                    ),
                  ),
                ),
                maxLines: 4,
                maxLength: 200,
              ),
              const SizedBox(height: 24),

              // Interests
              _buildInterestChips(),
              const SizedBox(height: 24),

              // LinkedIn
              TextFormField(
                controller: _linkedInController,
                style: TextStyle(color: AppTheme.getTextPrimary(context)),
                decoration: InputDecoration(
                  labelText: 'LinkedIn Profile',
                  labelStyle: TextStyle(color: AppTheme.getTextSecondary(context)),
                  hintText: 'https://linkedin.com/in/yourprofile',
                  hintStyle: TextStyle(color: AppTheme.getTextSecondary(context).withOpacity(0.5)),
                  prefixIcon: Icon(
                    Icons.business,
                    color: AppTheme.getTextSecondary(context),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.getBorderColor(context)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? AppTheme.darkPrimaryLight : AppTheme.primaryColor,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // GitHub
              TextFormField(
                controller: _gitHubController,
                style: TextStyle(color: AppTheme.getTextPrimary(context)),
                decoration: InputDecoration(
                  labelText: 'GitHub Profile',
                  labelStyle: TextStyle(color: AppTheme.getTextSecondary(context)),
                  hintText: 'https://github.com/yourusername',
                  hintStyle: TextStyle(color: AppTheme.getTextSecondary(context).withOpacity(0.5)),
                  prefixIcon: Icon(
                    Icons.code,
                    color: AppTheme.getTextSecondary(context),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.getBorderColor(context)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? AppTheme.darkPrimaryLight : AppTheme.primaryColor,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Save Button
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                          .withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isUploading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
