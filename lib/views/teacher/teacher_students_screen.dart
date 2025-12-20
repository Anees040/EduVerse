import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:eduverse/services/course_service.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:eduverse/utils/app_theme.dart';

class TeacherStudentsScreen extends StatefulWidget {
  const TeacherStudentsScreen({super.key});

  @override
  State<TeacherStudentsScreen> createState() => _TeacherStudentsScreenState();
}

class _TeacherStudentsScreenState extends State<TeacherStudentsScreen> {
  bool isLoading = true;
  List<Map<String, dynamic>> students = [];
  Map<String, String> courseNames = {}; // courseId -> courseName

  // For now no filtering; show all students the teacher has

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() => isLoading = true);

      final teacherId = FirebaseAuth.instance.currentUser!.uid;

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
            final Map<dynamic, dynamic> enrolled = course['enrolledStudents'] as Map<dynamic, dynamic>;
            studentUids.addAll(enrolled.keys.map((e) => e.toString()));
          }
        }

        if (studentUids.isNotEmpty) {
          final db = FirebaseDatabase.instance.ref();
          final futures = studentUids.map((uid) async {
            final snap = await db.child('student').child(uid).get();
            if (!snap.exists) return null;
            final data = Map<String, dynamic>.from(snap.value as Map<dynamic, dynamic>);
            data['uid'] = uid;

            // Build enrolledCourses map limited to teacher's courses
            final Map<String, dynamic> enrolledCourses = {};
            for (final course in teacherCourses) {
              final cid = course['courseUid']?.toString();
              if (cid == null) continue;
              final enrolledMap = course['enrolledStudents'] as Map<dynamic, dynamic>?;
              if (enrolledMap != null && enrolledMap.containsKey(uid)) {
                final entry = enrolledMap[uid];
                enrolledCourses[cid] = {
                  'enrolledAt': (entry is Map && entry['enrolledAt'] != null) ? entry['enrolledAt'] : DateTime.now().millisecondsSinceEpoch,
                };
              }
            }
            data['enrolledCourses'] = enrolledCourses;
            return data;
          }).toList();

          final results = (await Future.wait(futures)).whereType<Map<String, dynamic>>().toList();
          setState(() {
            students = results;
            isLoading = false;
          });
        } else if (kDebugMode) {
          // Debug-only mock so designers can preview the UI
          final sampleCourseId = courseNames.keys.first;
          final mock = [
            {
              'uid': 'debug_student_1',
              'name': 'Sam Developer',
              'email': 'sam.dev@example.com',
              'enrolledCourses': {sampleCourseId: {'enrolledAt': DateTime.now().millisecondsSinceEpoch}}
            }
          ];
          setState(() {
            students = mock;
            isLoading = false;
          });
        } else {
          setState(() {
            students = fetchedStudents;
            isLoading = false;
          });
        }
      } else {
        setState(() {
          students = fetchedStudents;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load data: $e')));
      }
    }
  }

  // For now return all students (no filtering)
  List<Map<String, dynamic>> get filteredStudents => students;

  @override
  Widget build(BuildContext context) {
    final displayStudents = filteredStudents;
    final isDark = AppTheme.isDarkMode(context);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : Colors.grey[100],
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: isDark
                    ? AppTheme.darkPrimaryLight
                    : AppTheme.primaryColor,
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Students list header
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Students',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

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
                                          backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
                                          title: Text(studentName),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Email: $studentEmail'),
                                              const SizedBox(height: 8),
                                              Text('Courses:'),
                                              const SizedBox(height: 6),
                                              ...enrolledCourseNames.map((c) => Text('• $c')),
                                            ],
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context),
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
                                                          padding: const EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                            vertical: 6,
                                                          ),
                                                          decoration: BoxDecoration(
                                                            gradient: LinearGradient(
                                                              colors: isDark
                                                                  ? [
                                                                      AppTheme.darkAccent.withOpacity(0.2),
                                                                      AppTheme.darkPrimaryLight.withOpacity(0.15),
                                                                    ]
                                                                  : [
                                                                      courseTagColor.withOpacity(0.12),
                                                                      courseTagColor.withOpacity(0.08),
                                                                    ],
                                                              begin: Alignment.topLeft,
                                                              end: Alignment.bottomRight,
                                                            ),
                                                            borderRadius: BorderRadius.circular(12),
                                                            border: Border.all(
                                                              color: isDark
                                                                  ? AppTheme.darkAccent.withOpacity(0.4)
                                                                  : courseTagColor.withOpacity(0.3),
                                                              width: 1,
                                                            ),
                                                          ),
                                                          child: Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              Icon(
                                                                Icons.book_outlined,
                                                                size: 12,
                                                                color: isDark ? AppTheme.darkAccent : courseTagColor,
                                                              ),
                                                              const SizedBox(width: 4),
                                                              Text(
                                                                name,
                                                                style: TextStyle(
                                                                  fontSize: 11,
                                                                  fontWeight: FontWeight.w600,
                                                                  color: isDark ? AppTheme.darkAccent : courseTagColor,
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
}
