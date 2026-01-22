import 'dart:math';

/// Mock data provider for the Teacher Analytics Dashboard
/// This class provides realistic dummy data for charts and metrics
class AnalyticsMockData {
  static final _random = Random(42); // Fixed seed for consistent data

  /// Get active students count with trend
  static Map<String, dynamic> getActiveStudentsData() {
    return {
      'count': 247,
      'trend': 5.2,
      'isPositive': true,
      'previousCount': 235,
    };
  }

  /// Get average watch time data
  static Map<String, dynamic> getWatchTimeData() {
    return {
      'minutes': 45,
      'hours': 2.3,
      'trend': -2.1,
      'isPositive': false,
      'formattedTime': '2h 18m',
    };
  }

  /// Get completion rate data
  static Map<String, dynamic> getCompletionRateData() {
    return {
      'rate': 0.73,
      'percentage': 73,
      'trend': 8.5,
      'isPositive': true,
      'completedStudents': 180,
      'totalStudents': 247,
    };
  }

  /// Get enrollment stats
  static Map<String, dynamic> getEnrollmentStats() {
    return {
      'totalEnrolled': 247,
      'newThisWeek': 18,
      'newThisMonth': 52,
      'trend': 12.3,
      'isPositive': true,
    };
  }

  /// Get popular watch times data for line chart
  /// Returns hourly viewer data (24 data points)
  static List<Map<String, dynamic>> getWatchTimesData() {
    // Simulating watch patterns - peak at 10am, 2pm, and 8pm
    final List<Map<String, dynamic>> data = [];
    final hourLabels = [
      '12am',
      '1am',
      '2am',
      '3am',
      '4am',
      '5am',
      '6am',
      '7am',
      '8am',
      '9am',
      '10am',
      '11am',
      '12pm',
      '1pm',
      '2pm',
      '3pm',
      '4pm',
      '5pm',
      '6pm',
      '7pm',
      '8pm',
      '9pm',
      '10pm',
      '11pm',
    ];

    final basePattern = [
      5, 3, 2, 1, 2, 5, // 12am - 5am (low activity)
      15, 35, 55, 75, 85, 70, // 6am - 11am (morning peak)
      65, 72, 88, 75, 60, 50, // 12pm - 5pm (afternoon)
      55, 70, 92, 80, 45, 20, // 6pm - 11pm (evening peak)
    ];

    for (int i = 0; i < 24; i++) {
      data.add({
        'hour': i,
        'label': hourLabels[i],
        'viewers': basePattern[i] + _random.nextInt(10) - 5,
      });
    }

    return data;
  }

  /// Get last 7 days activity data for line chart
  static List<Map<String, dynamic>> getWeeklyActivityData() {
    final List<Map<String, dynamic>> data = [];
    final dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final baseValues = [145, 168, 172, 155, 180, 120, 95];

    for (int i = 0; i < 7; i++) {
      data.add({
        'day': dayLabels[i],
        'dayIndex': i,
        'activeStudents': baseValues[i] + _random.nextInt(20) - 10,
        'watchMinutes': (baseValues[i] * 2.5 + _random.nextInt(50)).toInt(),
      });
    }

    return data;
  }

  /// Get course completion rates for bar chart
  static List<Map<String, dynamic>> getCourseCompletionData() {
    return [
      {
        'courseId': '1',
        'courseName': 'Flutter Basics',
        'shortName': 'Flutter',
        'completionRate': 0.85,
        'enrolledCount': 89,
        'completedCount': 76,
      },
      {
        'courseId': '2',
        'courseName': 'Advanced Dart',
        'shortName': 'Dart',
        'completionRate': 0.72,
        'enrolledCount': 65,
        'completedCount': 47,
      },
      {
        'courseId': '3',
        'courseName': 'UI/UX Design',
        'shortName': 'UI/UX',
        'completionRate': 0.68,
        'enrolledCount': 48,
        'completedCount': 33,
      },
      {
        'courseId': '4',
        'courseName': 'Firebase',
        'shortName': 'Firebase',
        'completionRate': 0.58,
        'enrolledCount': 45,
        'completedCount': 26,
      },
    ];
  }

  /// Get most replayed sections data
  static List<Map<String, dynamic>> getMostReplayedSections() {
    return [
      {
        'sectionName': 'State Management',
        'courseName': 'Flutter Basics',
        'replayCount': 342,
        'avgReplayTime': '3:45',
      },
      {
        'sectionName': 'Async/Await',
        'courseName': 'Advanced Dart',
        'replayCount': 287,
        'avgReplayTime': '4:12',
      },
      {
        'sectionName': 'Widget Lifecycle',
        'courseName': 'Flutter Basics',
        'replayCount': 256,
        'avgReplayTime': '2:58',
      },
      {
        'sectionName': 'Firestore Rules',
        'courseName': 'Firebase',
        'replayCount': 198,
        'avgReplayTime': '5:21',
      },
      {
        'sectionName': 'Responsive Design',
        'courseName': 'UI/UX Design',
        'replayCount': 175,
        'avgReplayTime': '3:15',
      },
    ];
  }

  /// Get student engagement breakdown
  static Map<String, dynamic> getEngagementBreakdown() {
    return {
      'highlyEngaged': 85, // Students with >80% progress
      'moderatelyEngaged': 102, // Students with 40-80% progress
      'lowEngaged': 42, // Students with 10-40% progress
      'inactive': 18, // Students with <10% progress
      'total': 247,
    };
  }

  /// Get video engagement data (for showing which videos are most watched)
  static List<Map<String, dynamic>> getVideoEngagementData() {
    return [
      {
        'videoTitle': 'Introduction to Widgets',
        'views': 1250,
        'avgWatchPercentage': 92,
        'likes': 156,
      },
      {
        'videoTitle': 'Building Layouts',
        'views': 1180,
        'avgWatchPercentage': 88,
        'likes': 143,
      },
      {
        'videoTitle': 'Navigation & Routing',
        'views': 980,
        'avgWatchPercentage': 85,
        'likes': 121,
      },
      {
        'videoTitle': 'State Management Deep Dive',
        'views': 850,
        'avgWatchPercentage': 78,
        'likes': 98,
      },
      {
        'videoTitle': 'Testing Flutter Apps',
        'views': 620,
        'avgWatchPercentage': 65,
        'likes': 72,
      },
    ];
  }

  /// Get date range options
  static List<Map<String, dynamic>> getDateRangeOptions() {
    return [
      {'value': '7d', 'label': 'Last 7 Days'},
      {'value': '30d', 'label': 'Last 30 Days'},
      {'value': '90d', 'label': 'Last 90 Days'},
      {'value': 'all', 'label': 'All Time'},
    ];
  }

  /// Get summary stats for quick overview
  static Map<String, dynamic> getSummaryStats() {
    return {
      'totalCourses': 4,
      'totalStudents': 247,
      'totalVideos': 48,
      'totalWatchHours': 1250,
      'avgRating': 4.7,
      'totalReviews': 189,
    };
  }
}
