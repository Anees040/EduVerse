import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:eduverse/utils/app_theme.dart';

/// Singleton service to check and enforce maintenance mode across the app.
/// Caches maintenance state and provides dialogs/banners for users.
class MaintenanceService {
  MaintenanceService._();
  static final MaintenanceService _instance = MaintenanceService._();
  static MaintenanceService get instance => _instance;

  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  bool _isMaintenanceMode = false;
  String? _maintenanceMessage;
  int? _maintenanceStartTime;
  int? _maintenanceEndTime;
  DateTime? _lastChecked;

  bool get isMaintenanceMode => _isMaintenanceMode;
  String get maintenanceMessage =>
      _maintenanceMessage ?? 'The platform is currently under maintenance.';

  String get maintenanceTimeFrame {
    if (_maintenanceStartTime == null && _maintenanceEndTime == null) {
      return 'No estimated time frame available.';
    }
    final fmt = DateFormat('MMM dd, yyyy hh:mm a');
    final start = _maintenanceStartTime != null
        ? fmt.format(DateTime.fromMillisecondsSinceEpoch(_maintenanceStartTime!))
        : 'Now';
    final end = _maintenanceEndTime != null
        ? fmt.format(DateTime.fromMillisecondsSinceEpoch(_maintenanceEndTime!))
        : 'Until further notice';
    return '$start  →  $end';
  }

  /// Fetch latest maintenance status from Firebase.
  Future<bool> checkMaintenanceMode() async {
    // Cache for 30 seconds to avoid spamming Firebase
    if (_lastChecked != null &&
        DateTime.now().difference(_lastChecked!).inSeconds < 30) {
      return _isMaintenanceMode;
    }

    try {
      final snapshot = await _db.child('platform_settings').get();
      if (snapshot.exists && snapshot.value != null) {
        final settings = Map<String, dynamic>.from(snapshot.value as Map);
        _isMaintenanceMode = settings['maintenanceMode'] == true;
        _maintenanceMessage = settings['maintenanceMessage'] as String?;
        _maintenanceStartTime = settings['maintenanceStartTime'] as int?;
        _maintenanceEndTime = settings['maintenanceEndTime'] as int?;
      } else {
        _isMaintenanceMode = false;
      }
      _lastChecked = DateTime.now();
    } catch (e) {
      debugPrint('Error checking maintenance mode: $e');
    }
    return _isMaintenanceMode;
  }

  /// Force refresh — ignores cache.
  Future<bool> forceCheck() async {
    _lastChecked = null;
    return checkMaintenanceMode();
  }

  /// Show a blocking dialog for maintenance mode.
  /// Returns true if user dismissed it (they can still view but not act).
  Future<void> showMaintenanceDialog(BuildContext context) async {
    final isDark = AppTheme.isDarkMode(context);
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.engineering_rounded,
                color: Colors.orange,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Maintenance Mode',
                style: TextStyle(
                  color: AppTheme.getTextPrimary(ctx),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              maintenanceMessage,
              style: TextStyle(
                color: AppTheme.getTextPrimary(ctx),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            // Time frame card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.schedule, color: Colors.orange, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Scheduled Time',
                        style: TextStyle(
                          color: AppTheme.getTextPrimary(ctx),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    maintenanceTimeFrame,
                    style: TextStyle(
                      color: AppTheme.getTextSecondary(ctx),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Some features may be temporarily unavailable. You can still browse but actions are restricted.',
                      style: TextStyle(
                        color: AppTheme.getTextSecondary(ctx),
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'I Understand',
              style: TextStyle(
                color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build a persistent banner widget for maintenance mode.
  Widget buildMaintenanceBanner(BuildContext context) {
    if (!_isMaintenanceMode) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.shade700,
            Colors.orange.shade500,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            const Icon(Icons.engineering_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Maintenance Mode Active',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    maintenanceTimeFrame,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => showMaintenanceDialog(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Details',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Check maintenance and show dialog if trying to use a blocking feature.
  /// Returns true if maintenance is active (caller should abort the action).
  Future<bool> guardAction(BuildContext context) async {
    await checkMaintenanceMode();
    if (_isMaintenanceMode) {
      if (context.mounted) {
        await showMaintenanceDialog(context);
      }
      return true;
    }
    return false;
  }
}
