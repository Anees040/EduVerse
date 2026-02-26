import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:eduverse/utils/app_theme.dart';

/// Admin platform settings with direct Firebase save.
class AdminPlatformSettingsScreen extends StatefulWidget {
  const AdminPlatformSettingsScreen({super.key});

  @override
  State<AdminPlatformSettingsScreen> createState() =>
      _AdminPlatformSettingsScreenState();
}

class _AdminPlatformSettingsScreenState
    extends State<AdminPlatformSettingsScreen> {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasChanges = false;

  // Settings
  bool _maintenanceMode = false;
  bool _registrationEnabled = true;
  bool _allowNewCourses = true;
  bool _requireEmailVerification = true;
  bool _enableNotifications = true;
  bool _enableChatSupport = true;
  bool _autoApproveTeachers = false;
  bool _enableStudentReviews = true;
  int _maxUploadSizeMB = 100;
  int _maxCoursesPerTeacher = 20;
  int _maxStudentsPerCourse = 500;
  int _sessionTimeoutMinutes = 60;

  late TextEditingController _platformNameController;
  late TextEditingController _supportEmailController;
  late TextEditingController _welcomeMessageController;
  late TextEditingController _privacyPolicyUrlController;

  @override
  void initState() {
    super.initState();
    _platformNameController = TextEditingController();
    _supportEmailController = TextEditingController();
    _welcomeMessageController = TextEditingController();
    _privacyPolicyUrlController = TextEditingController();
    _loadSettings();
  }

  @override
  void dispose() {
    _platformNameController.dispose();
    _supportEmailController.dispose();
    _welcomeMessageController.dispose();
    _privacyPolicyUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final snap = await _db.child('platform_settings').get();
      Map<String, dynamic> settings = {};
      if (snap.exists && snap.value != null) {
        settings = Map<String, dynamic>.from(snap.value as Map);
      }
      if (mounted) {
        setState(() {
          _maintenanceMode = settings['maintenanceMode'] as bool? ?? false;
          _registrationEnabled =
              settings['registrationEnabled'] as bool? ?? true;
          _allowNewCourses = settings['allowNewCourses'] as bool? ?? true;
          _requireEmailVerification =
              settings['requireEmailVerification'] as bool? ?? true;
          _enableNotifications =
              settings['enableNotifications'] as bool? ?? true;
          _enableChatSupport =
              settings['enableChatSupport'] as bool? ?? true;
          _autoApproveTeachers =
              settings['autoApproveTeachers'] as bool? ?? false;
          _enableStudentReviews =
              settings['enableStudentReviews'] as bool? ?? true;
          _maxUploadSizeMB =
              (settings['maxUploadSizeMB'] as num?)?.toInt() ?? 100;
          _maxCoursesPerTeacher =
              (settings['maxCoursesPerTeacher'] as num?)?.toInt() ?? 20;
          _maxStudentsPerCourse =
              (settings['maxStudentsPerCourse'] as num?)?.toInt() ?? 500;
          _sessionTimeoutMinutes =
              (settings['sessionTimeoutMinutes'] as num?)?.toInt() ?? 60;
          _platformNameController.text =
              settings['platformName'] as String? ?? 'EduVerse';
          _supportEmailController.text =
              settings['supportEmail'] as String? ?? '';
          _welcomeMessageController.text =
              settings['welcomeMessage'] as String? ?? 'Welcome to EduVerse!';
          _privacyPolicyUrlController.text =
              settings['privacyPolicyUrl'] as String? ?? '';
          _isLoading = false;
          _hasChanges = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final settings = {
        'maintenanceMode': _maintenanceMode,
        'registrationEnabled': _registrationEnabled,
        'allowNewCourses': _allowNewCourses,
        'requireEmailVerification': _requireEmailVerification,
        'enableNotifications': _enableNotifications,
        'enableChatSupport': _enableChatSupport,
        'autoApproveTeachers': _autoApproveTeachers,
        'enableStudentReviews': _enableStudentReviews,
        'maxUploadSizeMB': _maxUploadSizeMB,
        'maxCoursesPerTeacher': _maxCoursesPerTeacher,
        'maxStudentsPerCourse': _maxStudentsPerCourse,
        'sessionTimeoutMinutes': _sessionTimeoutMinutes,
        'platformName': _platformNameController.text.trim(),
        'supportEmail': _supportEmailController.text.trim(),
        'welcomeMessage': _welcomeMessageController.text.trim(),
        'privacyPolicyUrl': _privacyPolicyUrlController.text.trim(),
        'lastUpdated': ServerValue.timestamp,
        'updatedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
      };

      await _db.child('platform_settings').update(settings);

      // Log admin action
      final logRef = _db.child('admin_audit_log').push();
      await logRef.set({
        'id': logRef.key,
        'adminUid': FirebaseAuth.instance.currentUser?.uid ?? '',
        'action': 'update_settings',
        'details': 'Updated ${settings.length} platform settings',
        'timestamp': ServerValue.timestamp,
      });

      if (mounted) {
        setState(() {
          _isSaving = false;
          _hasChanges = false;
        });
      }

      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Settings saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Error saving settings: $e');
      if (mounted) setState(() => _isSaving = false);

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _markChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    final accentColor = isDark ? AppTheme.darkAccent : AppTheme.primaryColor;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Row(
            children: [
              Icon(Icons.settings_rounded, color: accentColor, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Platform Settings',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.getTextPrimary(context),
                  ),
                ),
              ),
              if (_hasChanges)
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveSettings,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save, size: 18),
                  label: Text(_isSaving ? 'Saving...' : 'Save'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            children: [
              _buildSectionHeader(
                  'Critical Settings', Icons.warning_amber, Colors.red, isDark),
              const SizedBox(height: 8),
              _buildSwitchTile(
                title: 'Maintenance Mode',
                subtitle: 'When enabled, only admins can access the platform',
                value: _maintenanceMode,
                onChanged: (v) {
                  setState(() => _maintenanceMode = v);
                  _markChanged();
                },
                iconColor: Colors.red,
                icon: Icons.engineering,
                isDark: isDark,
              ),

              const SizedBox(height: 20),

              _buildSectionHeader(
                  'Access Control', Icons.shield, Colors.blue, isDark),
              const SizedBox(height: 8),
              _buildSwitchTile(
                title: 'Allow Registration',
                subtitle: 'New users can sign up on the platform',
                value: _registrationEnabled,
                onChanged: (v) {
                  setState(() => _registrationEnabled = v);
                  _markChanged();
                },
                iconColor: Colors.blue,
                icon: Icons.person_add,
                isDark: isDark,
              ),
              _buildSwitchTile(
                title: 'Require Email Verification',
                subtitle: 'Users must verify email before access',
                value: _requireEmailVerification,
                onChanged: (v) {
                  setState(() => _requireEmailVerification = v);
                  _markChanged();
                },
                iconColor: Colors.orange,
                icon: Icons.mark_email_read,
                isDark: isDark,
              ),
              _buildSwitchTile(
                title: 'Auto-Approve Teachers',
                subtitle: 'Skip verification queue for new teachers',
                value: _autoApproveTeachers,
                onChanged: (v) {
                  setState(() => _autoApproveTeachers = v);
                  _markChanged();
                },
                iconColor: Colors.teal,
                icon: Icons.verified,
                isDark: isDark,
              ),

              const SizedBox(height: 20),

              _buildSectionHeader(
                  'Course Settings', Icons.school, Colors.green, isDark),
              const SizedBox(height: 8),
              _buildSwitchTile(
                title: 'Allow New Courses',
                subtitle: 'Teachers can create new courses',
                value: _allowNewCourses,
                onChanged: (v) {
                  setState(() => _allowNewCourses = v);
                  _markChanged();
                },
                iconColor: Colors.green,
                icon: Icons.add_circle,
                isDark: isDark,
              ),
              _buildSwitchTile(
                title: 'Enable Student Reviews',
                subtitle: 'Students can rate and review courses',
                value: _enableStudentReviews,
                onChanged: (v) {
                  setState(() => _enableStudentReviews = v);
                  _markChanged();
                },
                iconColor: Colors.amber,
                icon: Icons.star_rate,
                isDark: isDark,
              ),

              const SizedBox(height: 20),

              _buildSectionHeader(
                  'Communication', Icons.message, Colors.cyan, isDark),
              const SizedBox(height: 8),
              _buildSwitchTile(
                title: 'Enable Notifications',
                subtitle: 'Send push notifications to users',
                value: _enableNotifications,
                onChanged: (v) {
                  setState(() => _enableNotifications = v);
                  _markChanged();
                },
                iconColor: Colors.cyan,
                icon: Icons.notifications_active,
                isDark: isDark,
              ),
              _buildSwitchTile(
                title: 'Enable Chat Support',
                subtitle: 'Allow users to contact support via chat',
                value: _enableChatSupport,
                onChanged: (v) {
                  setState(() => _enableChatSupport = v);
                  _markChanged();
                },
                iconColor: Colors.indigo,
                icon: Icons.chat_bubble,
                isDark: isDark,
              ),

              const SizedBox(height: 20),

              _buildSectionHeader(
                  'Limits', Icons.tune, Colors.purple, isDark),
              const SizedBox(height: 8),
              _buildSliderTile(
                title: 'Max Upload Size',
                subtitle: '$_maxUploadSizeMB MB',
                value: _maxUploadSizeMB.toDouble(),
                min: 10,
                max: 500,
                divisions: 49,
                onChanged: (v) {
                  setState(() => _maxUploadSizeMB = v.round());
                  _markChanged();
                },
                icon: Icons.cloud_upload,
                iconColor: Colors.indigo,
                isDark: isDark,
              ),
              _buildSliderTile(
                title: 'Max Courses Per Teacher',
                subtitle: '$_maxCoursesPerTeacher courses',
                value: _maxCoursesPerTeacher.toDouble(),
                min: 1,
                max: 100,
                divisions: 99,
                onChanged: (v) {
                  setState(() => _maxCoursesPerTeacher = v.round());
                  _markChanged();
                },
                icon: Icons.school,
                iconColor: Colors.teal,
                isDark: isDark,
              ),
              _buildSliderTile(
                title: 'Max Students Per Course',
                subtitle: '$_maxStudentsPerCourse students',
                value: _maxStudentsPerCourse.toDouble(),
                min: 10,
                max: 2000,
                divisions: 199,
                onChanged: (v) {
                  setState(() => _maxStudentsPerCourse = v.round());
                  _markChanged();
                },
                icon: Icons.people,
                iconColor: Colors.deepPurple,
                isDark: isDark,
              ),
              _buildSliderTile(
                title: 'Session Timeout',
                subtitle: '$_sessionTimeoutMinutes minutes',
                value: _sessionTimeoutMinutes.toDouble(),
                min: 5,
                max: 480,
                divisions: 95,
                onChanged: (v) {
                  setState(() => _sessionTimeoutMinutes = v.round());
                  _markChanged();
                },
                icon: Icons.timer,
                iconColor: Colors.brown,
                isDark: isDark,
              ),

              const SizedBox(height: 20),

              _buildSectionHeader(
                  'Branding', Icons.palette, Colors.deepPurple, isDark),
              const SizedBox(height: 8),
              _buildTextFieldTile(
                title: 'Platform Name',
                controller: _platformNameController,
                icon: Icons.title,
                iconColor: Colors.deepPurple,
                isDark: isDark,
              ),
              const SizedBox(height: 8),
              _buildTextFieldTile(
                title: 'Support Email',
                controller: _supportEmailController,
                icon: Icons.email,
                iconColor: Colors.cyan,
                isDark: isDark,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 8),
              _buildTextFieldTile(
                title: 'Welcome Message',
                controller: _welcomeMessageController,
                icon: Icons.waving_hand,
                iconColor: Colors.amber,
                isDark: isDark,
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              _buildTextFieldTile(
                title: 'Privacy Policy URL',
                controller: _privacyPolicyUrlController,
                icon: Icons.privacy_tip,
                iconColor: Colors.grey,
                isDark: isDark,
                keyboardType: TextInputType.url,
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(
      String title, IconData icon, Color color, bool isDark) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color iconColor,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.darkBorderColor : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                      color: AppTheme.getTextPrimary(context),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    )),
                Text(subtitle,
                    style: TextStyle(
                      color: AppTheme.getTextSecondary(context),
                      fontSize: 12,
                    )),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildSliderTile({
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.darkBorderColor : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title,
                    style: TextStyle(
                      color: AppTheme.getTextPrimary(context),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    )),
              ),
              Text(subtitle,
                  style: TextStyle(
                    color:
                        isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  )),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            activeColor:
                isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildTextFieldTile({
    required String title,
    required TextEditingController controller,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.darkBorderColor : Colors.grey.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: (_) => _markChanged(),
              keyboardType: keyboardType,
              maxLines: maxLines,
              style: TextStyle(
                color: AppTheme.getTextPrimary(context),
                fontSize: 14,
              ),
              decoration: InputDecoration(
                labelText: title,
                labelStyle: TextStyle(
                  color: AppTheme.getTextSecondary(context),
                  fontSize: 13,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
