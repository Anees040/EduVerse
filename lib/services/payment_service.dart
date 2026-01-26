import 'package:firebase_database/firebase_database.dart';

/// Payment Service - Handles mock payments for paid courses
/// 20% of each payment goes to platform revenue
class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  
  // Platform commission rate (20%)
  static const double platformCommission = 0.20;

  /// Process a mock payment for course enrollment
  /// Returns true if payment was successful
  Future<PaymentResult> processCoursePayment({
    required String studentUid,
    required String studentName,
    required String courseId,
    required String courseName,
    required String teacherUid,
    required String teacherName,
    required double coursePrice,
  }) async {
    try {
      final paymentId = _db.child('payments').push().key!;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // Calculate amounts
      final totalAmount = coursePrice;
      final platformFee = totalAmount * platformCommission;
      final teacherEarnings = totalAmount - platformFee;

      // Create payment record
      final paymentData = {
        'paymentId': paymentId,
        'studentUid': studentUid,
        'studentName': studentName,
        'courseId': courseId,
        'courseName': courseName,
        'teacherUid': teacherUid,
        'teacherName': teacherName,
        'totalAmount': totalAmount,
        'platformFee': platformFee,
        'teacherEarnings': teacherEarnings,
        'currency': 'USD',
        'status': 'completed',
        'paymentMethod': 'mock_payment',
        'timestamp': timestamp,
        'createdAt': ServerValue.timestamp,
      };

      // Save payment record
      await _db.child('payments/$paymentId').set(paymentData);

      // Update platform revenue
      await _updatePlatformRevenue(platformFee, timestamp);

      // Update teacher earnings
      await _updateTeacherEarnings(teacherUid, teacherEarnings, timestamp);

      // Update course revenue stats
      await _updateCourseRevenue(courseId, totalAmount, timestamp);

      // Update student's payment history
      await _db.child('student/$studentUid/payments/$paymentId').set({
        'courseId': courseId,
        'courseName': courseName,
        'amount': totalAmount,
        'timestamp': ServerValue.timestamp,
      });

      return PaymentResult(
        success: true,
        paymentId: paymentId,
        totalAmount: totalAmount,
        platformFee: platformFee,
        teacherEarnings: teacherEarnings,
      );
    } catch (e) {
      return PaymentResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Update platform revenue tracking
  Future<void> _updatePlatformRevenue(double amount, int timestamp) async {
    try {
      // Add to revenue transactions
      await _db.child('revenue').push().set({
        'amount': amount,
        'type': 'platform_commission',
        'timestamp': timestamp,
        'createdAt': ServerValue.timestamp,
      });

      // Update daily revenue
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      
      final dailyRef = _db.child('revenue_daily/$dateKey');
      final snapshot = await dailyRef.get();
      
      double currentDaily = 0;
      if (snapshot.exists && snapshot.value != null) {
        final data = snapshot.value;
        if (data is Map) {
          currentDaily = (data['amount'] ?? 0).toDouble();
        } else if (data is num) {
          currentDaily = data.toDouble();
        }
      }
      
      await dailyRef.set({
        'amount': currentDaily + amount,
        'date': dateKey,
        'updatedAt': ServerValue.timestamp,
      });

      // Update monthly revenue
      final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      final monthlyRef = _db.child('revenue_monthly/$monthKey');
      final monthSnapshot = await monthlyRef.get();
      
      double currentMonthly = 0;
      if (monthSnapshot.exists && monthSnapshot.value != null) {
        final data = monthSnapshot.value;
        if (data is Map) {
          currentMonthly = (data['amount'] ?? 0).toDouble();
        } else if (data is num) {
          currentMonthly = data.toDouble();
        }
      }
      
      await monthlyRef.set({
        'amount': currentMonthly + amount,
        'month': monthKey,
        'updatedAt': ServerValue.timestamp,
      });

      // Update total revenue
      final totalRef = _db.child('revenue_total');
      final totalSnapshot = await totalRef.get();
      
      double currentTotal = 0;
      if (totalSnapshot.exists && totalSnapshot.value != null) {
        currentTotal = (totalSnapshot.value as num).toDouble();
      }
      
      await totalRef.set(currentTotal + amount);
    } catch (e) {
      // Silent fail for revenue tracking
    }
  }

  /// Update teacher earnings
  Future<void> _updateTeacherEarnings(String teacherUid, double amount, int timestamp) async {
    try {
      // Add to teacher's earnings history
      await _db.child('teacher/$teacherUid/earnings').push().set({
        'amount': amount,
        'timestamp': timestamp,
        'createdAt': ServerValue.timestamp,
      });

      // Update teacher's total earnings
      final totalRef = _db.child('teacher/$teacherUid/totalEarnings');
      final snapshot = await totalRef.get();
      
      double currentTotal = 0;
      if (snapshot.exists && snapshot.value != null) {
        currentTotal = (snapshot.value as num).toDouble();
      }
      
      await totalRef.set(currentTotal + amount);
    } catch (e) {
      // Silent fail
    }
  }

  /// Update course revenue stats
  Future<void> _updateCourseRevenue(String courseId, double amount, int timestamp) async {
    try {
      final revenueRef = _db.child('courses/$courseId/totalRevenue');
      final snapshot = await revenueRef.get();
      
      double currentRevenue = 0;
      if (snapshot.exists && snapshot.value != null) {
        currentRevenue = (snapshot.value as num).toDouble();
      }
      
      await revenueRef.set(currentRevenue + amount);
    } catch (e) {
      // Silent fail
    }
  }

  /// Get platform revenue statistics
  Future<RevenueStats> getPlatformRevenueStats({
    String filter = 'all', // all, year, month, week, today
  }) async {
    try {
      final now = DateTime.now();
      double totalRevenue = 0;
      List<RevenueDataPoint> dataPoints = [];

      if (filter == 'all') {
        // Get all-time revenue
        final totalSnapshot = await _db.child('revenue_total').get();
        if (totalSnapshot.exists && totalSnapshot.value != null) {
          totalRevenue = (totalSnapshot.value as num).toDouble();
        }

        // Get monthly data for chart
        final monthlySnapshot = await _db.child('revenue_monthly').orderByKey().limitToLast(12).get();
        if (monthlySnapshot.exists && monthlySnapshot.value != null) {
          final data = Map<String, dynamic>.from(monthlySnapshot.value as Map);
          data.forEach((key, value) {
            final amount = value is Map ? (value['amount'] ?? 0).toDouble() : (value as num).toDouble();
            dataPoints.add(RevenueDataPoint(
              label: key,
              amount: amount,
              timestamp: DateTime.parse('$key-01').millisecondsSinceEpoch,
            ));
          });
        }
      } else if (filter == 'year') {
        // Get current year revenue
        final yearKey = now.year.toString();
        final yearlySnapshot = await _db.child('revenue_monthly')
            .orderByKey()
            .startAt('$yearKey-01')
            .endAt('$yearKey-12')
            .get();
        
        if (yearlySnapshot.exists && yearlySnapshot.value != null) {
          final data = Map<String, dynamic>.from(yearlySnapshot.value as Map);
          data.forEach((key, value) {
            final amount = value is Map ? (value['amount'] ?? 0).toDouble() : (value as num).toDouble();
            totalRevenue += amount;
            dataPoints.add(RevenueDataPoint(
              label: key,
              amount: amount,
              timestamp: DateTime.parse('$key-01').millisecondsSinceEpoch,
            ));
          });
        }
      } else if (filter == 'month') {
        // Get current month revenue
        final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
        
        // Get daily data for current month
        final startKey = '$monthKey-01';
        final endKey = '$monthKey-31';
        final dailySnapshot = await _db.child('revenue_daily')
            .orderByKey()
            .startAt(startKey)
            .endAt(endKey)
            .get();
        
        if (dailySnapshot.exists && dailySnapshot.value != null) {
          final data = Map<String, dynamic>.from(dailySnapshot.value as Map);
          data.forEach((key, value) {
            final amount = value is Map ? (value['amount'] ?? 0).toDouble() : (value as num).toDouble();
            totalRevenue += amount;
            dataPoints.add(RevenueDataPoint(
              label: key.split('-').last, // Just day number
              amount: amount,
              timestamp: DateTime.parse(key).millisecondsSinceEpoch,
            ));
          });
        }
      } else if (filter == 'week') {
        // Get last 7 days revenue
        for (int i = 6; i >= 0; i--) {
          final date = now.subtract(Duration(days: i));
          final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          
          final snapshot = await _db.child('revenue_daily/$dateKey').get();
          double amount = 0;
          if (snapshot.exists && snapshot.value != null) {
            final data = snapshot.value;
            if (data is Map) {
              amount = (data['amount'] ?? 0).toDouble();
            } else if (data is num) {
              amount = data.toDouble();
            }
          }
          
          totalRevenue += amount;
          dataPoints.add(RevenueDataPoint(
            label: _getDayLabel(date),
            amount: amount,
            timestamp: date.millisecondsSinceEpoch,
          ));
        }
      } else if (filter == 'today') {
        // Get today's revenue
        final dateKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        final snapshot = await _db.child('revenue_daily/$dateKey').get();
        
        if (snapshot.exists && snapshot.value != null) {
          final data = snapshot.value;
          if (data is Map) {
            totalRevenue = (data['amount'] ?? 0).toDouble();
          } else if (data is num) {
            totalRevenue = data.toDouble();
          }
        }
        
        dataPoints.add(RevenueDataPoint(
          label: 'Today',
          amount: totalRevenue,
          timestamp: now.millisecondsSinceEpoch,
        ));
      }

      // Sort data points by timestamp
      dataPoints.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      return RevenueStats(
        totalRevenue: totalRevenue,
        dataPoints: dataPoints,
        filter: filter,
      );
    } catch (e) {
      return RevenueStats(
        totalRevenue: 0,
        dataPoints: [],
        filter: filter,
      );
    }
  }

  String _getDayLabel(DateTime date) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }

  /// Get recent payments
  Future<List<Map<String, dynamic>>> getRecentPayments({int limit = 10}) async {
    try {
      final snapshot = await _db.child('payments')
          .orderByChild('timestamp')
          .limitToLast(limit)
          .get();
      
      if (snapshot.exists && snapshot.value != null) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        final payments = data.entries.map((e) {
          final payment = Map<String, dynamic>.from(e.value as Map);
          payment['id'] = e.key;
          return payment;
        }).toList();
        
        // Sort by timestamp descending
        payments.sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));
        return payments;
      }
    } catch (e) {
      // Silent fail
    }
    return [];
  }

  /// Check if student has already purchased a course
  Future<bool> hasStudentPurchasedCourse(String studentUid, String courseId) async {
    try {
      final snapshot = await _db.child('student/$studentUid/payments')
          .orderByChild('courseId')
          .equalTo(courseId)
          .get();
      
      return snapshot.exists && snapshot.value != null;
    } catch (e) {
      return false;
    }
  }
}

/// Result of a payment transaction
class PaymentResult {
  final bool success;
  final String? paymentId;
  final double? totalAmount;
  final double? platformFee;
  final double? teacherEarnings;
  final String? error;

  PaymentResult({
    required this.success,
    this.paymentId,
    this.totalAmount,
    this.platformFee,
    this.teacherEarnings,
    this.error,
  });
}

/// Revenue statistics
class RevenueStats {
  final double totalRevenue;
  final List<RevenueDataPoint> dataPoints;
  final String filter;

  RevenueStats({
    required this.totalRevenue,
    required this.dataPoints,
    required this.filter,
  });
}

/// Single data point for revenue chart
class RevenueDataPoint {
  final String label;
  final double amount;
  final int timestamp;

  RevenueDataPoint({
    required this.label,
    required this.amount,
    required this.timestamp,
  });
}
