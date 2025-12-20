import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:eduverse/services/course_service.dart';
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
  String selectedCourse = 'All';
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

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

      // Fetch all enrolled students
      final fetchedStudents = await CourseService()
          .getAllEnrolledStudentsForTeacher(teacherUid: teacherId);

      setState(() {
        students = fetchedStudents;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load data: $e')));
      }
    }
  }

  List<String> get allCourseOptions {
    // Return 'All' plus course names from teacher's courses
    return ['All', ...courseNames.values];
  }

  String? _getCourseUidByName(String name) {
    if (name == 'All') return null;
    for (final entry in courseNames.entries) {
      if (entry.value == name) return entry.key;
    }
    return null;
  }

  // Filter students by selected course
  List<Map<String, dynamic>> get filteredStudents {
    // Start with all students
    var list = students;

    // Filter by course selection
    if (selectedCourse != 'All') {
      final courseUid = _getCourseUidByName(selectedCourse);
      if (courseUid != null) {
        list = list.where((student) {
          final enrolledCourses =
              student['enrolledCourses'] as Map<dynamic, dynamic>?;
          return enrolledCourses != null && enrolledCourses.containsKey(courseUid);
        }).toList();
      }
    }

    // Filter by search query (name or email)
    if (searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase();
      list = list.where((student) {
        final name = (student['name'] ?? '').toString().toLowerCase();
        final email = (student['email'] ?? '').toString().toLowerCase();
        return name.contains(q) || email.contains(q);
      }).toList();
    }

    return list;
  }

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
                  // Search + Filter Row
                  Row(
                    children: [
                      // Search field
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.darkCard : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? AppTheme.darkBorder.withOpacity(0.6)
                                  : Colors.grey.shade200,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.search,
                                color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    hintText: 'Search students by name or email',
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                  onChanged: (val) {
                                    setState(() {
                                      searchQuery = val;
                                    });
                                  },
                                ),
                              ),
                              if (searchQuery.isNotEmpty)
                                GestureDetector(
                                  onTap: () {
                                    _searchController.clear();
                                    setState(() {
                                      searchQuery = '';
                                    });
                                  },
                                  child: Icon(
                                    Icons.close,
                                    size: 18,
                                    color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Dropdown filter
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkCard : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark
                                ? AppTheme.darkAccent.withOpacity(0.3)
                                : AppTheme.primaryColor.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedCourse,
                            dropdownColor: isDark ? AppTheme.darkCard : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            icon: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
                              size: 24,
                            ),
                            style: TextStyle(
                              color: isDark ? AppTheme.darkTextPrimary : Colors.black87,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            items: allCourseOptions.map((course) {
                              return DropdownMenuItem<String>(
                                value: course,
                                child: Text(
                                  course.length > 24 ? '${course.substring(0, 24)}...' : course,
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedCourse = value!;
                              });
                            },
                          ),
                        ),
                      ),
                    ],
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
                                  selectedCourse == 'All'
                                      ? 'No students enrolled yet'
                                      : 'No students in this course',
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
                                      // Could show student details in future
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
                                                        (name) => InkWell(
                                                          onTap: () {
                                                            // Quick filter by tapped course
                                                            setState(() {
                                                              selectedCourse = name;
                                                            });
                                                          },
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                  12),
                                                          child: Container(
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
                                                                begin: Alignment.topLeft,
                                                                end: Alignment.bottomRight,
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
                                                                  MainAxisSize.min,
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
                                          // Make entire student tile tappable to show details
                                          GestureDetector(
                                            behavior: HitTestBehavior.translucent,
                                            onTap: () {
                                              // Show student detail dialog
                                              showDialog(
                                                context: context,
                                                builder: (context) {
                                                  return AlertDialog(
                                                    backgroundColor: isDark
                                                        ? AppTheme.darkCard
                                                        : Colors.white,
                                                    title: Text(studentName),
                                                    content: Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment.start,
                                                      children: [
                                                        Text('Email: $studentEmail'),
                                                        const SizedBox(height: 8),
                                                        Text('Courses:'),
                                                        const SizedBox(height: 6),
                                                        ...enrolledCourseNames.map((c) => Padding(
                                                              padding: const EdgeInsets.symmetric(vertical: 2),
                                                              child: Text('• $c'),
                                                            )),
                                                      ],
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () => Navigator.pop(context),
                                                        child: const Text('Close'),
                                                      ),
                                                    ],
                                                  );
                                                },
                                              );
                                            },
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
