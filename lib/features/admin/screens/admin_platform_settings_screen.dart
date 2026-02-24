import 'package:flutter/material.dart';
import 'package:eduverse/features/admin/services/admin_feature_service.dart';
import 'package:eduverse/utils/app_theme.dart';

/// Admin platform settings — maintenance mode, registration, branding, limits.
class AdminPlatformSettingsScreen extends StatefulWidget {
  const AdminPlatformSettingsScreen({super.key});

  @override
  State<AdminPlatformSettingsScreen> createState() =>
      _AdminPlatformSettingsScreenState();
}

class _AdminPlatformSettingsScreenState
    extends State<AdminPlatformSettingsScreen> {
  final _service = AdminFeatureService();
  // Settings loaded from Firebase
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasChanges = false;

  // Local copies for editing
  late bool _maintenanceMode;
  late bool _registrationEnabled;
  late bool _allowNewCourses;
  late bool _requireEmailVerification;
  late int _maxUploadSizeMB;
  late int _maxCoursesPerTeacher;
  late String _platformName;
  late String _supportEmail;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    final settings = await _service.getPlatformSettings();
    if (mounted) {
      setState(() {
        // Settings loaded successfully
        _maintenanceMode = settings['maintenanceMode'] as bool? ?? false;
        _registrationEnabled = settings['registrationEnabled'] as bool? ?? true;
        _allowNewCourses = settings['allowNewCourses'] as bool? ?? true;
        _requireEmailVerification =
            settings['requireEmailVerification'] as bool? ?? true;
        _maxUploadSizeMB = (settings['maxUploadSizeMB'] as num?)?.toInt() ?? 100;
        _maxCoursesPerTeacher =
            (settings['maxCoursesPerTeacher'] as num?)?.toInt() ?? 20;
        _platformName = settings['platformName'] as String? ?? 'EduVerse';
        _supportEmail = settings['supportEmail'] as String? ?? '';
        _isLoading = false;
        _hasChanges = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final success = await _service.updatePlatformSettings({
      'maintenanceMode': _maintenanceMode,
      'registrationEnabled': _registrationEnabled,
      'allowNewCourses': _allowNewCourses,
      'requireEmailVerification': _requireEmailVerification,
      'maxUploadSizeMB': _maxUploadSizeMB,
      'maxCoursesPerTeacher': _maxCoursesPerTeacher,
      'platformName': _platformName,
      'supportEmail': _supportEmail,
    });

    if (mounted) {
      setState(() {
        _isSaving = false;
        if (success) _hasChanges = false;
      });
    }

    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(success ? 'Settings saved!' : 'Failed to save settings'),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
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
        // Header
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
              // ── Critical Settings ──
              _buildSectionHeader('Critical Settings', Icons.warning_amber,
                  Colors.red, isDark),
              const SizedBox(height: 8),
              _buildSwitchTile(
                title: 'Maintenance Mode',
                subtitle:
                    'When enabled, only admins can access the platform',
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

              // ── Access Control ──
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

              const SizedBox(height: 20),

              // ── Limits ──
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

              const SizedBox(height: 20),

              // ── Branding ──
              _buildSectionHeader(
                  'Branding', Icons.palette, Colors.deepPurple, isDark),
              const SizedBox(height: 8),
              _buildTextFieldTile(
                title: 'Platform Name',
                value: _platformName,
                onChanged: (v) {
                  _platformName = v;
                  _markChanged();
                },
                icon: Icons.title,
                iconColor: Colors.deepPurple,
                isDark: isDark,
              ),
              const SizedBox(height: 8),
              _buildTextFieldTile(
                title: 'Support Email',
                value: _supportEmail,
                onChanged: (v) {
                  _supportEmail = v;
                  _markChanged();
                },
                icon: Icons.email,
                iconColor: Colors.cyan,
                isDark: isDark,
                keyboardType: TextInputType.emailAddress,
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
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
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
                Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.getTextPrimary(context),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppTheme.getTextSecondary(context),
                    fontSize: 12,
                  ),
                ),
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
                child: Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.getTextPrimary(context),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            activeColor: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildTextFieldTile({
    required String title,
    required String value,
    required ValueChanged<String> onChanged,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
    TextInputType keyboardType = TextInputType.text,
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
              controller: TextEditingController(text: value),
              onChanged: onChanged,
              keyboardType: keyboardType,
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
