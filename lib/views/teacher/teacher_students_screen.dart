import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:eduverse/services/course_service.dart';
import 'package:eduverse/services/cache_service.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:eduverse/utils/app_theme.dart';
import 'package:eduverse/widgets/engaging_loading_indicator.dart';

class TeacherStudentsScreen extends StatefulWidget {
  const TeacherStudentsScreen({super.key});

  @override
  State<TeacherStudentsScreen> createState() => _TeacherStudentsScreenState();
}

class _TeacherStudentsScreenState extends State<TeacherStudentsScreen>
    with AutomaticKeepAliveClientMixin {
  final CacheService _cacheService = CacheService();
  bool isLoading = true;
  List<Map<String, dynamic>> students = [];
  Map<String, String> courseNames = {}; // courseId -> courseName

  // Filter state
  String? _selectedCourseFilter;
  String _selectedDateFilter = 'all'; // all, week, month, year
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _showFilters = false;

  // Keep tab alive
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final teacherId = FirebaseAuth.instance.currentUser!.uid;
    final cacheKeyStudents = 'teacher_enrolled_students_$teacherId';
    final cacheKeyCourseNames = 'teacher_course_names_$teacherId';

    // Check cache first for instant display
    final cachedStudents = _cacheService.get<List<Map<String, dynamic>>>(
      cacheKeyStudents,
    );
    final cachedCourseNames = _cacheService.get<Map<String, String>>(
      cacheKeyCourseNames,
    );

    if (cachedStudents != null && cachedCourseNames != null) {
      if (mounted) {
        setState(() {
          students = cachedStudents;
          courseNames = cachedCourseNames;
          isLoading = false;
        });
      }
      // Refresh in background
      _refreshDataInBackground(
        teacherId,
        cacheKeyStudents,
        cacheKeyCourseNames,
      );
      return;
    }

    try {
      if (!mounted) return;
      setState(() => isLoading = true);

      // First fetch teacher's courses to populate dropdown
      final teacherCourses = await CourseService().getTeacherCourses(
        teacherUid: teacherId,
      );

      // Build courseNames map from teacher's courses
      courseNames = {};
      for (final course in teacherCourses) {
        final courseId = course['courseUid'] as String;
        final title = course['title'] as String? ?? 'Untitled';
        courseNames[courseId] = title;
      }

      // Fetch all enrolled students (primary method)
      final fetchedStudents = await CourseService()
          .getAllEnrolledStudentsForTeacher(teacherUid: teacherId);

      // If primary fetch returned no students, attempt a robust fallback
      // by scanning the teacher's course data for enrolledStudents and
      // fetching student profiles directly.
      if (fetchedStudents.isEmpty && courseNames.isNotEmpty) {
        final Set<String> studentUids = {};

        // Try to collect student UIDs from teacher's courses (teacherCourses)
        // Note: we have `teacherCourses` variable above in this scope
        for (final course in teacherCourses) {
          if (course['enrolledStudents'] != null) {
            final Map<dynamic, dynamic> enrolled =
                course['enrolledStudents'] as Map<dynamic, dynamic>;
            studentUids.addAll(enrolled.keys.map((e) => e.toString()));
          }
        }

        if (studentUids.isNotEmpty) {
          final db = FirebaseDatabase.instance.ref();
          final futures = studentUids.map((uid) async {
            final snap = await db.child('student').child(uid).get();
            if (!snap.exists) return null;
            final data = Map<String, dynamic>.from(
              snap.value as Map<dynamic, dynamic>,
            );
            data['uid'] = uid;

            // Build enrolledCourses map limited to teacher's courses
            final Map<String, dynamic> enrolledCourses = {};
            for (final course in teacherCourses) {
              final cid = course['courseUid']?.toString();
              if (cid == null) continue;
              final enrolledMap =
                  course['enrolledStudents'] as Map<dynamic, dynamic>?;
              if (enrolledMap != null && enrolledMap.containsKey(uid)) {
                final entry = enrolledMap[uid];
                enrolledCourses[cid] = {
                  'enrolledAt': (entry is Map && entry['enrolledAt'] != null)
                      ? entry['enrolledAt']
                      : DateTime.now().millisecondsSinceEpoch,
                };
              }
            }
            data['enrolledCourses'] = enrolledCourses;
            return data;
          }).toList();

          final results = (await Future.wait(
            futures,
          )).whereType<Map<String, dynamic>>().toList();

          // Cache results
          _cacheService.set(cacheKeyStudents, results);
          _cacheService.set(cacheKeyCourseNames, courseNames);

          if (mounted) {
            setState(() {
              students = results;
              isLoading = false;
            });
          }
        } else if (kDebugMode) {
          // Debug-only mock so designers can preview the UI
          final sampleCourseId = courseNames.keys.first;
          final mock = [
            {
              'uid': 'debug_student_1',
              'name': 'Sam Developer',
              'email': 'sam.dev@example.com',
              'enrolledCourses': {
                sampleCourseId: {
                  'enrolledAt': DateTime.now().millisecondsSinceEpoch,
                },
              },
            },
          ];
          if (mounted) {
            setState(() {
              students = mock;
              isLoading = false;
            });
          }
        } else {
          // Cache results
          _cacheService.set(cacheKeyStudents, fetchedStudents);
          _cacheService.set(cacheKeyCourseNames, courseNames);

          if (mounted) {
            setState(() {
              students = fetchedStudents;
              isLoading = false;
            });
          }
        }
      } else {
        // Cache results
        _cacheService.set(cacheKeyStudents, fetchedStudents);
        _cacheService.set(cacheKeyCourseNames, courseNames);

        if (mounted) {
          setState(() {
            students = fetchedStudents;
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load data: $e')));
      }
    }
  }

  Future<void> _refreshDataInBackground(
    String teacherId,
    String cacheKeyStudents,
    String cacheKeyCourseNames,
  ) async {
    try {
      final teacherCourses = await CourseService().getTeacherCourses(
        teacherUid: teacherId,
      );

      final Map<String, String> newCourseNames = {};
      for (final course in teacherCourses) {
        final courseId = course['courseUid'] as String;
        final title = course['title'] as String? ?? 'Untitled';
        newCourseNames[courseId] = title;
      }

      final fetchedStudents = await CourseService()
          .getAllEnrolledStudentsForTeacher(teacherUid: teacherId);

      // Cache results
      _cacheService.set(cacheKeyStudents, fetchedStudents);
      _cacheService.set(cacheKeyCourseNames, newCourseNames);

      if (mounted) {
        setState(() {
          students = fetchedStudents;
          courseNames = newCourseNames;
        });
      }
    } catch (_) {
      // Silent fail for background refresh
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Filter students based on selected criteria
  List<Map<String, dynamic>> get filteredStudents {
    List<Map<String, dynamic>> result = students;

    // Filter by search query (name or email)
    if (_searchQuery.isNotEmpty) {
      result = result.where((student) {
        final name = (student['name'] ?? '').toString().toLowerCase();
        final email = (student['email'] ?? '').toString().toLowerCase();
        final query = _searchQuery.toLowerCase();
        return name.contains(query) || email.contains(query);
      }).toList();
    }

    // Filter by course
    if (_selectedCourseFilter != null) {
      result = result.where((student) {
        final enrolledCourses =
            student['enrolledCourses'] as Map<dynamic, dynamic>?;
        if (enrolledCourses == null) return false;
        return enrolledCourses.containsKey(_selectedCourseFilter);
      }).toList();
    }

    // Filter by enrollment date
    if (_selectedDateFilter != 'all') {
      final now = DateTime.now();
      DateTime? cutoffDate;

      switch (_selectedDateFilter) {
        case 'week':
          cutoffDate = now.subtract(const Duration(days: 7));
          break;
        case 'month':
          cutoffDate = now.subtract(const Duration(days: 30));
          break;
        case 'year':
          cutoffDate = now.subtract(const Duration(days: 365));
          break;
      }

      if (cutoffDate != null) {
        result = result.where((student) {
          final enrolledCourses =
              student['enrolledCourses'] as Map<dynamic, dynamic>?;
          if (enrolledCourses == null || enrolledCourses.isEmpty) return false;

          // Check if any enrollment is after cutoff date
          for (final courseData in enrolledCourses.values) {
            if (courseData is Map && courseData['enrolledAt'] != null) {
              final enrolledAt = DateTime.fromMillisecondsSinceEpoch(
                courseData['enrolledAt'] as int,
              );
              if (enrolledAt.isAfter(cutoffDate!)) return true;
            }
          }
          return false;
        }).toList();
      }
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final displayStudents = filteredStudents;
    final isDark = AppTheme.isDarkMode(context);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : Colors.grey[100],
      body: isLoading
          ? const Center(
              child: EngagingLoadingIndicator(
                message: 'Loading students...',
                size: 70,
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Header with filter toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Students',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.textPrimary,
                        ),
                      ),
                      Row(
                        children: [
                          // Active filters indicator
                          if (_selectedCourseFilter != null ||
                              _selectedDateFilter != 'all' ||
                              _searchQuery.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color:
                                    (isDark
                                            ? AppTheme.darkAccent
                                            : AppTheme.primaryColor)
                                        .withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${displayStudents.length}/${students.length}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppTheme.darkAccent
                                      : AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          // Filter toggle button
                          InkWell(
                            onTap: () =>
                                setState(() => _showFilters = !_showFilters),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _showFilters
                                    ? (isDark
                                          ? AppTheme.darkAccent
                                          : AppTheme.primaryColor)
                                    : (isDark
                                          ? AppTheme.darkCard
                                          : Colors.white),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark
                                      ? AppTheme.darkAccent.withOpacity(0.3)
                                      : AppTheme.primaryColor.withOpacity(0.2),
                                ),
                              ),
                              child: Icon(
                                _showFilters
                                    ? Icons.filter_list_off
                                    : Icons.filter_list,
                                color: _showFilters
                                    ? Colors.white
                                    : (isDark
                                          ? AppTheme.darkAccent
                                          : AppTheme.primaryColor),
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Search bar
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? AppTheme.darkBorder
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                      style: TextStyle(
                        color: isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search students by name or email...',
                        hintStyle: TextStyle(
                          color: isDark
                              ? AppTheme.darkTextSecondary
                              : Colors.grey,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: isDark
                              ? AppTheme.darkAccent
                              : AppTheme.primaryColor,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  color: isDark
                                      ? AppTheme.darkTextSecondary
                                      : Colors.grey,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: isDark ? AppTheme.darkCard : Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Filter chips (visible when _showFilters is true)
                  if (_showFilters) ...[
                    _buildFilterSection(isDark),
                    const SizedBox(height: 12),
                  ],

                  // Student List
                  Expanded(
                    child: displayStudents.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 64,
                                  color: AppTheme.getTextSecondary(context),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No students enrolled yet',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: AppTheme.getTextSecondary(context),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: displayStudents.length,
                            itemBuilder: (context, index) {
                              final student = displayStudents[index];

                              final studentName = student['name'] ?? 'Unknown';
                              final studentEmail =
                                  student['email'] ?? 'Unknown';

                              final enrolledCourses =
                                  student['enrolledCourses']
                                      as Map<dynamic, dynamic>?;

                              // Get all enrolled course names for this student
                              List<String> enrolledCourseNames = [];
                              String enrolledAtStr = 'N/A';

                              if (enrolledCourses != null &&
                                  enrolledCourses.isNotEmpty) {
                                for (final courseId in enrolledCourses.keys) {
                                  final courseName =
                                      courseNames[courseId.toString()];
                                  if (courseName != null) {
                                    enrolledCourseNames.add(courseName);
                                  }
                                }

                                // Get earliest enrollment date
                                final firstCourseId = enrolledCourses.keys.first
                                    .toString();
                                final courseData =
                                    enrolledCourses[firstCourseId]
                                        as Map<dynamic, dynamic>?;
                                if (courseData != null &&
                                    courseData['enrolledAt'] != null) {
                                  final enrolledAt =
                                      courseData['enrolledAt'] as int;
                                  enrolledAtStr =
                                      DateTime.fromMillisecondsSinceEpoch(
                                        enrolledAt,
                                      ).toLocal().toString().split(' ')[0];
                                }
                              }

                              // Vibrant colors for dark mode
                              final avatarColor = isDark
                                  ? const Color(0xFF4ECDC4) // Vibrant teal
                                  : const Color.fromARGB(255, 17, 51, 96);
                              final courseTagColor = isDark
                                  ? AppTheme
                                        .darkPrimaryLight // Teal accent for consistency
                                  : const Color.fromARGB(255, 17, 51, 96);

                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppTheme.darkCard
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isDark
                                        ? AppTheme.darkAccent.withOpacity(0.2)
                                        : Colors.grey.shade200,
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isDark
                                          ? AppTheme.darkAccent.withOpacity(0.1)
                                          : Colors.black.withOpacity(0.06),
                                      blurRadius: 12,
                                      spreadRadius: 0,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () {
                                      // Show simple student details dialog
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          backgroundColor: isDark
                                              ? AppTheme.darkCard
                                              : Colors.white,
                                          title: Text(studentName),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text('Email: $studentEmail'),
                                              const SizedBox(height: 8),
                                              Text('Courses:'),
                                              const SizedBox(height: 6),
                                              ...enrolledCourseNames.map(
                                                (c) => Text('• $c'),
                                              ),
                                            ],
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              child: const Text('Close'),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Avatar with gradient and glow
                                          Container(
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient: LinearGradient(
                                                colors: isDark
                                                    ? [
                                                        AppTheme.darkAccent,
                                                        AppTheme.darkAccent
                                                            .withOpacity(0.7),
                                                      ]
                                                    : [
                                                        avatarColor,
                                                        avatarColor.withOpacity(
                                                          0.8,
                                                        ),
                                                      ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: isDark
                                                      ? AppTheme.darkAccent
                                                            .withOpacity(0.4)
                                                      : avatarColor.withOpacity(
                                                          0.3,
                                                        ),
                                                  blurRadius: 10,
                                                  spreadRadius: 1,
                                                  offset: const Offset(0, 3),
                                                ),
                                              ],
                                            ),
                                            child: CircleAvatar(
                                              backgroundColor:
                                                  Colors.transparent,
                                              radius: 28,
                                              child: Text(
                                                studentName[0].toUpperCase(),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 24,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          // Student info
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                // Name with icon
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        studentName,
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          fontSize: 18,
                                                          color: isDark
                                                              ? Colors.white
                                                              : Colors.black87,
                                                          letterSpacing: 0.3,
                                                        ),
                                                      ),
                                                    ),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            6,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: isDark
                                                            ? AppTheme
                                                                  .darkAccent
                                                                  .withOpacity(
                                                                    0.15,
                                                                  )
                                                            : AppTheme
                                                                  .primaryColor
                                                                  .withOpacity(
                                                                    0.1,
                                                                  ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                      child: Icon(
                                                        Icons.person,
                                                        size: 16,
                                                        color: isDark
                                                            ? AppTheme
                                                                  .darkAccent
                                                            : AppTheme
                                                                  .primaryColor,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
                                                // Email with icon
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.email_outlined,
                                                      size: 14,
                                                      color: isDark
                                                          ? AppTheme
                                                                .darkTextSecondary
                                                          : Colors
                                                                .grey
                                                                .shade500,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        studentEmail,
                                                        style: TextStyle(
                                                          color: isDark
                                                              ? AppTheme
                                                                    .darkTextSecondary
                                                              : Colors
                                                                    .grey
                                                                    .shade600,
                                                          fontSize: 13,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 12),
                                                // Course tags
                                                Wrap(
                                                  spacing: 8,
                                                  runSpacing: 8,
                                                  children: enrolledCourseNames
                                                      .map(
                                                        (name) => Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 12,
                                                                vertical: 6,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            gradient: LinearGradient(
                                                              colors: isDark
                                                                  ? [
                                                                      AppTheme
                                                                          .darkAccent
                                                                          .withOpacity(
                                                                            0.2,
                                                                          ),
                                                                      AppTheme
                                                                          .darkPrimaryLight
                                                                          .withOpacity(
                                                                            0.15,
                                                                          ),
                                                                    ]
                                                                  : [
                                                                      courseTagColor
                                                                          .withOpacity(
                                                                            0.12,
                                                                          ),
                                                                      courseTagColor
                                                                          .withOpacity(
                                                                            0.08,
                                                                          ),
                                                                    ],
                                                              begin: Alignment
                                                                  .topLeft,
                                                              end: Alignment
                                                                  .bottomRight,
                                                            ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  12,
                                                                ),
                                                            border: Border.all(
                                                              color: isDark
                                                                  ? AppTheme
                                                                        .darkAccent
                                                                        .withOpacity(
                                                                          0.4,
                                                                        )
                                                                  : courseTagColor
                                                                        .withOpacity(
                                                                          0.3,
                                                                        ),
                                                              width: 1,
                                                            ),
                                                          ),
                                                          child: Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              Icon(
                                                                Icons
                                                                    .book_outlined,
                                                                size: 12,
                                                                color: isDark
                                                                    ? AppTheme
                                                                          .darkAccent
                                                                    : courseTagColor,
                                                              ),
                                                              const SizedBox(
                                                                width: 4,
                                                              ),
                                                              Text(
                                                                name,
                                                                style: TextStyle(
                                                                  fontSize: 11,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  color: isDark
                                                                      ? AppTheme
                                                                            .darkAccent
                                                                      : courseTagColor,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      )
                                                      .toList(),
                                                ),
                                                const SizedBox(height: 10),
                                                // Enrollment date
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 5,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: isDark
                                                        ? Colors.white
                                                              .withOpacity(0.05)
                                                        : Colors.grey.shade100,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .calendar_today_outlined,
                                                        size: 12,
                                                        color: isDark
                                                            ? AppTheme
                                                                  .darkTextSecondary
                                                            : Colors
                                                                  .grey
                                                                  .shade600,
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        "Enrolled: $enrolledAtStr",
                                                        style: TextStyle(
                                                          color: isDark
                                                              ? AppTheme
                                                                    .darkTextSecondary
                                                              : Colors
                                                                    .grey
                                                                    .shade600,
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildFilterSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? AppTheme.darkAccent.withOpacity(0.05)
                : Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter by Course
          Row(
            children: [
              Icon(
                Icons.book_outlined,
                size: 16,
                color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Filter by Course',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              if (_selectedCourseFilter != null)
                GestureDetector(
                  onTap: () => setState(() => _selectedCourseFilter = null),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: (isDark ? AppTheme.darkError : AppTheme.error)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Clear',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppTheme.darkError : AppTheme.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCourseFilterChip(null, 'All Courses', isDark),
                ...courseNames.entries.map(
                  (entry) =>
                      _buildCourseFilterChip(entry.key, entry.value, isDark),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Filter by Enrollment Date
          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 16,
                color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Filter by Enrollment Date',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppTheme.darkTextPrimary
                      : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildDateFilterChip('all', 'All Time', isDark),
                _buildDateFilterChip('week', 'Last Week', isDark),
                _buildDateFilterChip('month', 'Last Month', isDark),
                _buildDateFilterChip('year', 'Last Year', isDark),
              ],
            ),
          ),

          // Clear All Filters Button
          if (_selectedCourseFilter != null ||
              _selectedDateFilter != 'all' ||
              _searchQuery.isNotEmpty) ...[
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedCourseFilter = null;
                    _selectedDateFilter = 'all';
                    _searchQuery = '';
                    _searchController.clear();
                  });
                },
                icon: Icon(
                  Icons.clear_all,
                  size: 18,
                  color: isDark ? AppTheme.darkError : AppTheme.error,
                ),
                label: Text(
                  'Clear All Filters',
                  style: TextStyle(
                    color: isDark ? AppTheme.darkError : AppTheme.error,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCourseFilterChip(String? courseId, String label, bool isDark) {
    final isSelected = _selectedCourseFilter == courseId;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => setState(() => _selectedCourseFilter = courseId),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                : (isDark ? AppTheme.darkElevated : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                  : (isDark ? AppTheme.darkBorder : Colors.grey.shade300),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected
                  ? Colors.white
                  : (isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.textSecondary),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateFilterChip(String value, String label, bool isDark) {
    final isSelected = _selectedDateFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => setState(() => _selectedDateFilter = value),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                : (isDark ? AppTheme.darkElevated : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                  : (isDark ? AppTheme.darkBorder : Colors.grey.shade300),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected
                  ? Colors.white
                  : (isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}
