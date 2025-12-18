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
      final teacherCourses = await CourseService().getTeacherCourses(teacherUid: teacherId);
      
      // Build courseNames map from teacher's courses
      courseNames = {};
      for (final course in teacherCourses) {
        final courseId = course['courseUid'] as String;
        final title = course['title'] as String? ?? 'Untitled';
        courseNames[courseId] = title;
      }

      // Fetch all enrolled students
      final fetchedStudents =
          await CourseService().getAllEnrolledStudentsForTeacher(teacherUid: teacherId);

      setState(() {
        students = fetchedStudents;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to load data: $e')));
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
    if (selectedCourse == 'All') return students;
    
    final courseUid = _getCourseUidByName(selectedCourse);
    if (courseUid == null) return students;
    
    return students.where((student) {
      final enrolledCourses = student['enrolledCourses'] as Map<dynamic, dynamic>?;
      return enrolledCourses != null && enrolledCourses.containsKey(courseUid);
    }).toList();
  }


  @override
  Widget build(BuildContext context) {
    final displayStudents = filteredStudents;
    final isDark = AppTheme.isDarkMode(context);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : Colors.grey[100],
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: isDark ? AppTheme.darkPrimaryLight : AppTheme.primaryColor))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // 🔍 Filter Dropdown
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Filter by Course:",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.darkTextPrimary : const Color.fromARGB(255, 17, 51, 96),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkCard : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: isDark ? Border.all(color: AppTheme.darkBorderColor) : null,
                        ),
                        child: DropdownButton<String>(
                          value: selectedCourse,
                          dropdownColor: isDark ? AppTheme.darkCard : Colors.white,
                          underline: const SizedBox(),
                          icon: Icon(Icons.keyboard_arrow_down, color: isDark ? AppTheme.darkPrimaryLight : AppTheme.primaryColor),
                          items: allCourseOptions.map((course) {
                            return DropdownMenuItem<String>(
                              value: course,
                              child: Text(
                                course.length > 20 ? '${course.substring(0, 20)}...' : course,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : Colors.black87),
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
                                Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                Text(
                                  selectedCourse == 'All'
                                      ? 'No students enrolled yet'
                                      : 'No students in this course',
                                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: displayStudents.length,
                            itemBuilder: (context, index) {
                              final student = displayStudents[index];

                        final studentName = student['name'] ?? 'Unknown';
                        final studentEmail = student['email'] ?? 'Unknown';

                        final enrolledCourses = student['enrolledCourses'] as Map<dynamic, dynamic>?;

                        // Get all enrolled course names for this student
                        List<String> enrolledCourseNames = [];
                        String enrolledAtStr = 'N/A';

                        if (enrolledCourses != null && enrolledCourses.isNotEmpty) {
                          for (final courseId in enrolledCourses.keys) {
                            final courseName = courseNames[courseId.toString()];
                            if (courseName != null) {
                              enrolledCourseNames.add(courseName);
                            }
                          }
                          
                          // Get earliest enrollment date
                          final firstCourseId = enrolledCourses.keys.first.toString();
                          final courseData = enrolledCourses[firstCourseId] as Map<dynamic, dynamic>?;
                          if (courseData != null && courseData['enrolledAt'] != null) {
                            final enrolledAt = courseData['enrolledAt'] as int;
                            enrolledAtStr =
                                DateTime.fromMillisecondsSinceEpoch(enrolledAt).toLocal().toString().split(' ')[0];
                          }
                        }

                        // Vibrant colors for dark mode
                        final avatarColor = isDark 
                            ? const Color(0xFF4ECDC4) // Vibrant teal
                            : const Color.fromARGB(255, 17, 51, 96);
                        final courseTagColor = isDark 
                            ? const Color(0xFF9B7DFF) // Bright purple
                            : const Color.fromARGB(255, 17, 51, 96);

                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.darkCard : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: isDark 
                                ? Border.all(color: avatarColor.withOpacity(0.3))
                                : null,
                            boxShadow: isDark
                                ? [
                                    BoxShadow(
                                      color: avatarColor.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  decoration: isDark 
                                      ? BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: LinearGradient(
                                            colors: [
                                              avatarColor,
                                              avatarColor.withOpacity(0.7),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: avatarColor.withOpacity(0.4),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        )
                                      : null,
                                  child: CircleAvatar(
                                    backgroundColor: isDark ? Colors.transparent : avatarColor,
                                    radius: 26,
                                    child: Text(
                                      studentName[0].toUpperCase(),
                                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        studentName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold, 
                                          fontSize: 17,
                                          color: isDark ? AppTheme.darkTextPrimary : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        studentEmail,
                                        style: TextStyle(
                                          color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600, 
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: enrolledCourseNames.map((name) => Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: isDark 
                                                ? courseTagColor.withOpacity(0.2)
                                                : courseTagColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(20),
                                            border: isDark 
                                                ? Border.all(color: courseTagColor.withOpacity(0.4))
                                                : null,
                                          ),
                                          child: Text(
                                            name,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: courseTagColor,
                                            ),
                                          ),
                                        )).toList(),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_today_outlined,
                                            size: 12,
                                            color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade500,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            "Enrolled: $enrolledAtStr",
                                            style: TextStyle(
                                              color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade500, 
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
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
