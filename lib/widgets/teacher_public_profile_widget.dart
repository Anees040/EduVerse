import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:eduverse/utils/app_theme.dart';
import 'package:eduverse/services/user_service.dart';
import 'package:eduverse/services/course_service.dart';

/// Teacher Public Profile Widget
/// Shows "Meet Your Instructor" modal with teacher details
class TeacherPublicProfileWidget {
  /// Show the teacher profile modal
  static Future<void> showProfile({
    required BuildContext context,
    required String teacherUid,
    String? teacherName,
  }) async {
    final isDark = AppTheme.isDarkMode(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TeacherProfileContent(
        teacherUid: teacherUid,
        initialName: teacherName,
        isDark: isDark,
      ),
    );
  }
}

class _TeacherProfileContent extends StatefulWidget {
  final String teacherUid;
  final String? initialName;
  final bool isDark;

  const _TeacherProfileContent({
    required this.teacherUid,
    this.initialName,
    required this.isDark,
  });

  @override
  State<_TeacherProfileContent> createState() => _TeacherProfileContentState();
}

class _TeacherProfileContentState extends State<_TeacherProfileContent> {
  final _userService = UserService();
  final _courseService = CourseService();

  bool _isLoading = true;
  Map<String, dynamic>? _profile;
  double? _rating;
  int _reviewCount = 0;
  int _courseCount = 0;
  int _studentCount = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      // Load profile and stats in parallel
      final results = await Future.wait([
        _userService.getTeacherPublicProfile(uid: widget.teacherUid),
        _courseService.getTeacherRatingStats(teacherUid: widget.teacherUid),
        _courseService.getTeacherCourses(teacherUid: widget.teacherUid),
        _courseService.getUniqueStudentCount(teacherUid: widget.teacherUid),
      ]);

      final profile = results[0] as Map<String, dynamic>?;
      final ratingStats = results[1] as Map<String, dynamic>?;
      final courses = results[2] as List<Map<String, dynamic>>?;
      final studentCount = results[3] as int?;

      if (mounted) {
        setState(() {
          _profile = profile;
          _rating = ratingStats?['averageRating'] != null
              ? (ratingStats!['averageRating'] as num).toDouble()
              : null;
          _reviewCount = ratingStats?['reviewCount'] ?? 0;
          _courseCount = courses?.length ?? 0;
          _studentCount = studentCount ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.getTextSecondary(context).withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color:
                        (widget.isDark
                                ? AppTheme.darkAccent
                                : AppTheme.primaryColor)
                            .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.school,
                    color: widget.isDark
                        ? AppTheme.darkAccent
                        : AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Meet Your Instructor',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: AppTheme.getTextPrimary(context),
                        ),
                      ),
                      Text(
                        'Learn more about your teacher',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.getTextSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close,
                    color: AppTheme.getTextSecondary(context),
                  ),
                ),
              ],
            ),
          ),

          Divider(
            color: widget.isDark ? AppTheme.darkBorder : Colors.grey.shade200,
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _profile == null
                ? _buildEmptyState()
                : _buildProfileContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_outline,
            size: 64,
            color: AppTheme.getTextSecondary(context).withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Profile not available',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.getTextSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent() {
    final name = _profile!['name'] ?? widget.initialName ?? 'Instructor';
    final headline = _profile!['headline'];
    final bio = _profile!['bio'];
    // Handle yearsOfExperience that might be stored as String or int
    final yearsExpRaw = _profile!['yearsOfExperience'];
    final yearsExp = yearsExpRaw is int
        ? yearsExpRaw
        : (yearsExpRaw is String ? int.tryParse(yearsExpRaw) : null);
    final expertise = _profile!['subjectExpertise'];
    final education = _profile!['education'];
    final institution = _profile!['institution'];
    // Handle certifications - ensure it's a String
    final rawCertifications = _profile!['certifications'];
    final certifications = rawCertifications is String
        ? rawCertifications
        : null;
    // Handle achievements - ensure it's a String
    final rawAchievements = _profile!['achievements'];
    final achievements = rawAchievements is String ? rawAchievements : null;
    final linkedin = _profile!['linkedin'];
    final website = _profile!['website'];
    final profilePicture = _profile!['profilePicture'];

    // Handle credentialsList that might be stored as List or Map
    List<Map<String, dynamic>>? credentials;
    final rawCredentials = _profile!['credentialsList'];
    if (rawCredentials != null) {
      if (rawCredentials is List) {
        credentials = rawCredentials
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } else if (rawCredentials is Map) {
        credentials = rawCredentials.values
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile header with picture
          Center(
            child: Column(
              children: [
                // Profile picture
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.isDark
                          ? AppTheme.darkAccent
                          : AppTheme.primaryColor,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            (widget.isDark
                                    ? AppTheme.darkAccent
                                    : AppTheme.primaryColor)
                                .withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: profilePicture != null && profilePicture.isNotEmpty
                        ? Image.network(
                            profilePicture,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _buildAvatarPlaceholder(name),
                          )
                        : _buildAvatarPlaceholder(name),
                  ),
                ),
                const SizedBox(height: 16),

                // Name
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.getTextPrimary(context),
                  ),
                ),

                // Headline
                if (headline != null && headline.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    headline,
                    style: TextStyle(
                      fontSize: 14,
                      color: widget.isDark
                          ? AppTheme.darkAccent
                          : AppTheme.primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Stats row
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: widget.isDark
                  ? AppTheme.darkElevated
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  icon: Icons.school,
                  value: _courseCount.toString(),
                  label: 'Courses',
                ),
                _buildStatDivider(),
                _buildStatItem(
                  icon: Icons.people,
                  value: _studentCount > 1000
                      ? '${(_studentCount / 1000).toStringAsFixed(1)}K'
                      : _studentCount.toString(),
                  label: 'Students',
                ),
                _buildStatDivider(),
                _buildStatItem(
                  icon: Icons.star,
                  value: _rating != null ? _rating!.toStringAsFixed(1) : 'N/A',
                  label: '$_reviewCount Reviews',
                ),
              ],
            ),
          ),

          // Bio section
          if (bio != null && bio.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildSectionHeader('About', Icons.person_outline),
            const SizedBox(height: 12),
            Text(
              bio,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.getTextSecondary(context),
                height: 1.6,
              ),
            ),
          ],

          // Expertise section
          if (expertise != null || yearsExp != null) ...[
            const SizedBox(height: 24),
            _buildSectionHeader('Expertise', Icons.auto_awesome),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (expertise != null)
                  _buildInfoChip(expertise, Icons.category),
                if (yearsExp != null && yearsExp > 0)
                  _buildInfoChip('$yearsExp+ years', Icons.work_history),
              ],
            ),
          ],

          // Education section
          if (education != null && education.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildSectionHeader('Education', Icons.school_outlined),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: widget.isDark
                    ? AppTheme.darkElevated
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          (widget.isDark
                                  ? AppTheme.darkAccent
                                  : AppTheme.primaryColor)
                              .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.school,
                      color: widget.isDark
                          ? AppTheme.darkAccent
                          : AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          education,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.getTextPrimary(context),
                          ),
                        ),
                        if (institution != null && institution.isNotEmpty)
                          Text(
                            institution,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.getTextSecondary(context),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Certifications section
          if (certifications != null && certifications.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildSectionHeader('Certifications', Icons.verified),
            const SizedBox(height: 12),
            ...certifications
                .split('\n')
                .where((c) => c.trim().isNotEmpty)
                .map(
                  (cert) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 18,
                          color: widget.isDark
                              ? AppTheme.darkSuccess
                              : AppTheme.success,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            cert.trim(),
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.getTextPrimary(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],

          // Credentials list with certificate images
          if (credentials != null && credentials.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildSectionHeader('Verified Credentials', Icons.verified_user),
            const SizedBox(height: 12),
            ...credentials.map(
              (cred) => GestureDetector(
                onTap: cred['imageUrl'] != null
                    ? () => _showCertificateImage(
                        context,
                        cred['imageUrl'],
                        cred['title'] ?? 'Certificate',
                      )
                    : null,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.isDark
                        ? AppTheme.darkElevated
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: cred['imageUrl'] != null
                        ? Border.all(
                            color: widget.isDark
                                ? AppTheme.darkSuccess.withOpacity(0.3)
                                : AppTheme.success.withOpacity(0.3),
                            width: 1,
                          )
                        : null,
                  ),
                  child: Row(
                    children: [
                      // Certificate thumbnail or icon
                      cred['imageUrl'] != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                cred['imageUrl'],
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color:
                                        (widget.isDark
                                                ? AppTheme.darkWarning
                                                : AppTheme.warning)
                                            .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.workspace_premium,
                                    size: 24,
                                    color: widget.isDark
                                        ? AppTheme.darkWarning
                                        : AppTheme.warning,
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color:
                                    (widget.isDark
                                            ? AppTheme.darkWarning
                                            : AppTheme.warning)
                                        .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.workspace_premium,
                                size: 24,
                                color: widget.isDark
                                    ? AppTheme.darkWarning
                                    : AppTheme.warning,
                              ),
                            ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cred['title'] ?? '',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: AppTheme.getTextPrimary(context),
                              ),
                            ),
                            if (cred['issuer'] != null &&
                                cred['issuer'].toString().isNotEmpty)
                              Text(
                                cred['issuer'].toString(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.getTextSecondary(context),
                                ),
                              ),
                            if (cred['imageUrl'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.verified,
                                      size: 14,
                                      color: widget.isDark
                                          ? AppTheme.darkSuccess
                                          : AppTheme.success,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Tap to view certificate',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: widget.isDark
                                            ? AppTheme.darkSuccess
                                            : AppTheme.success,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (cred['imageUrl'] != null)
                        Icon(
                          Icons.chevron_right,
                          color: AppTheme.getTextSecondary(context),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],

          // Achievements section
          if (achievements != null && achievements.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildSectionHeader('Achievements', Icons.emoji_events),
            const SizedBox(height: 12),
            Text(
              achievements,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.getTextSecondary(context),
                height: 1.6,
              ),
            ),
          ],

          // Social links
          if ((linkedin != null && linkedin.isNotEmpty) ||
              (website != null && website.isNotEmpty)) ...[
            const SizedBox(height: 24),
            _buildSectionHeader('Connect', Icons.link),
            const SizedBox(height: 12),
            Row(
              children: [
                if (linkedin != null && linkedin.isNotEmpty)
                  Expanded(
                    child: _buildSocialButton(
                      'LinkedIn',
                      Icons.link,
                      linkedin,
                      const Color(0xFF0077B5),
                    ),
                  ),
                if (linkedin != null &&
                    linkedin.isNotEmpty &&
                    website != null &&
                    website.isNotEmpty)
                  const SizedBox(width: 12),
                if (website != null && website.isNotEmpty)
                  Expanded(
                    child: _buildSocialButton(
                      'Website',
                      Icons.language,
                      website,
                      widget.isDark
                          ? AppTheme.darkAccent
                          : AppTheme.primaryColor,
                    ),
                  ),
              ],
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildAvatarPlaceholder(String name) {
    return Container(
      color: widget.isDark ? AppTheme.darkElevated : Colors.grey.shade200,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'T',
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: widget.isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          size: 24,
          color: widget.isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.getTextPrimary(context),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.getTextSecondary(context),
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 40,
      color: widget.isDark ? AppTheme.darkBorder : Colors.grey.shade300,
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: widget.isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.getTextPrimary(context),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: (widget.isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
            .withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: widget.isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: widget.isDark
                  ? AppTheme.darkAccent
                  : AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialButton(
    String label,
    IconData icon,
    String url,
    Color color,
  ) {
    return OutlinedButton.icon(
      onPressed: () => _copyToClipboard(url, label),
      icon: Icon(icon, size: 18, color: color),
      label: Text(label, style: TextStyle(color: color)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }

  void _copyToClipboard(String url, String label) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label URL copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Show full-screen certificate image viewer
  void _showCertificateImage(
    BuildContext context,
    String imageUrl,
    String title,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.getCardColor(context),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.verified,
                    color: widget.isDark
                        ? AppTheme.darkSuccess
                        : AppTheme.success,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppTheme.getTextPrimary(context),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: Icon(
                      Icons.close,
                      color: AppTheme.getTextSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            // Certificate image
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              decoration: BoxDecoration(
                color: AppTheme.getCardColor(context),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 3.0,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 300,
                        color: widget.isDark
                            ? AppTheme.darkElevated
                            : Colors.grey.shade100,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => Container(
                      height: 200,
                      color: widget.isDark
                          ? AppTheme.darkElevated
                          : Colors.grey.shade100,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image,
                            size: 48,
                            color: AppTheme.getTextSecondary(context),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Could not load certificate image',
                            style: TextStyle(
                              color: AppTheme.getTextSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
