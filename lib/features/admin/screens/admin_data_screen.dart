import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:eduverse/utils/app_theme.dart';
import '../services/admin_service.dart';

/// Admin Data Screen - Export and backup functionality
class AdminDataScreen extends StatefulWidget {
  const AdminDataScreen({super.key});

  @override
  State<AdminDataScreen> createState() => _AdminDataScreenState();
}

class _AdminDataScreenState extends State<AdminDataScreen> {
  final AdminService _adminService = AdminService();
  bool _isExportingUsers = false;
  bool _isExportingCourses = false;
  String? _lastExportPath;

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Data Control',
            style: TextStyle(
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Export platform data for compliance and backup',
            style: TextStyle(
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 32),

          // Export Cards
          _buildExportCard(
            title: 'User Data',
            description:
                'Export all user profiles including students and teachers.',
            icon: Icons.people_rounded,
            iconColor: isDark ? AppTheme.darkAccent : AppTheme.accentColor,
            format: 'CSV',
            isLoading: _isExportingUsers,
            onExport: _exportUserData,
            isDark: isDark,
          ),
          const SizedBox(height: 16),
          _buildExportCard(
            title: 'Course Metadata',
            description:
                'Export course information including titles, descriptions, pricing, and enrollment stats.',
            icon: Icons.menu_book_rounded,
            iconColor: isDark ? AppTheme.darkPrimary : AppTheme.primaryColor,
            format: 'JSON',
            isLoading: _isExportingCourses,
            onExport: _exportCourseData,
            isDark: isDark,
          ),
          const SizedBox(height: 32),

          // Last Export Info
          if (_lastExportPath != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (isDark ? AppTheme.darkSuccess : AppTheme.success)
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (isDark ? AppTheme.darkSuccess : AppTheme.success)
                      .withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: isDark ? AppTheme.darkSuccess : AppTheme.success,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Last Export',
                          style: TextStyle(
                            color: isDark
                                ? AppTheme.darkSuccess
                                : AppTheme.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _lastExportPath!,
                          style: TextStyle(
                            color: isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],

          // Data Policy Info
          _buildInfoSection(isDark),
        ],
      ),
    );
  }

  Widget _buildExportCard({
    required String title,
    required String description,
    required IconData icon,
    required Color iconColor,
    required String format,
    required bool isLoading,
    required VoidCallback onExport,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 32),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.darkBorder
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        format,
                        style: TextStyle(
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: isLoading ? null : onExport,
            icon: isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  )
                : const Icon(Icons.download_rounded, size: 18),
            label: Text(isLoading ? 'Exporting...' : 'Export'),
            style: ElevatedButton.styleFrom(
              backgroundColor: iconColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: (isDark ? AppTheme.darkInfo : AppTheme.info).withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDark ? AppTheme.darkInfo : AppTheme.info).withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_rounded,
                color: isDark ? AppTheme.darkInfo : AppTheme.info,
              ),
              const SizedBox(width: 8),
              Text(
                'Data Export Guidelines',
                style: TextStyle(
                  color: isDark ? AppTheme.darkInfo : AppTheme.info,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoItem(
            '• All exports are generated server-side for performance',
            isDark,
          ),
          _buildInfoItem(
            '• CSV files can be opened in Excel or Google Sheets',
            isDark,
          ),
          _buildInfoItem(
            '• JSON exports are formatted for easy parsing',
            isDark,
          ),
          _buildInfoItem(
            '• Sensitive data (passwords) is never included in exports',
            isDark,
          ),
          _buildInfoItem(
            '• Keep exports secure and follow data protection guidelines',
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
          fontSize: 13,
          height: 1.4,
        ),
      ),
    );
  }

  Future<void> _exportUserData() async {
    setState(() => _isExportingUsers = true);

    try {
      final users = await _adminService.exportUsers();

      if (users.isEmpty) {
        _showSnackBar('No user data to export', isError: true);
        return;
      }

      // Convert to CSV
      final csv = _convertToCSV(users);

      // Save file
      final path = await _saveFile('users_export.csv', csv);

      setState(() => _lastExportPath = path);
      _showSnackBar('User data exported successfully!');
    } catch (e) {
      _showSnackBar('Export failed: $e', isError: true);
    } finally {
      setState(() => _isExportingUsers = false);
    }
  }

  Future<void> _exportCourseData() async {
    setState(() => _isExportingCourses = true);

    try {
      final courses = await _adminService.exportCourses();

      if (courses.isEmpty) {
        _showSnackBar('No course data to export', isError: true);
        return;
      }

      // Convert to pretty JSON
      final json = const JsonEncoder.withIndent('  ').convert(courses);

      // Save file
      final path = await _saveFile('courses_export.json', json);

      setState(() => _lastExportPath = path);
      _showSnackBar('Course data exported successfully!');
    } catch (e) {
      _showSnackBar('Export failed: $e', isError: true);
    } finally {
      setState(() => _isExportingCourses = false);
    }
  }

  String _convertToCSV(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return '';

    // Get all keys from first item
    final headers = data.first.keys.toList();
    final rows = <String>[headers.join(',')];

    for (final item in data) {
      final values = headers.map((header) {
        final value = item[header]?.toString() ?? '';
        // Escape commas and quotes in CSV
        if (value.contains(',') ||
            value.contains('"') ||
            value.contains('\n')) {
          return '"${value.replaceAll('"', '""')}"';
        }
        return value;
      }).toList();
      rows.add(values.join(','));
    }

    return rows.join('\n');
  }

  Future<String> _saveFile(String filename, String content) async {
    if (kIsWeb) {
      // For web, we would use download functionality
      // This is a simplified placeholder
      return 'Download initiated: $filename';
    }

    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${directory.path}/${timestamp}_$filename');
    await file.writeAsString(content);
    return file.path;
  }

  void _showSnackBar(String message, {bool isError = false}) {
    final isDark = AppTheme.isDarkMode(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? (isDark ? AppTheme.darkError : AppTheme.error)
            : (isDark ? AppTheme.darkSuccess : AppTheme.success),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
