import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:eduverse/services/uploadToCloudinary.dart';
import 'package:eduverse/services/course_service.dart';
import 'package:eduverse/services/notification_service.dart';
import 'package:eduverse/services/cache_service.dart';

/// Model for tracking upload status
class UploadTask {
  final String id;
  final String courseUid;
  final String courseTitle;
  final String videoTitle;
  final String videoDescription;
  final XFile videoFile;
  double progress;
  UploadStatus status;
  String? errorMessage;
  CancellableUpload? cancellable;

  UploadTask({
    required this.id,
    required this.courseUid,
    required this.courseTitle,
    required this.videoTitle,
    required this.videoDescription,
    required this.videoFile,
    this.progress = 0.0,
    this.status = UploadStatus.pending,
    this.errorMessage,
    this.cancellable,
  });
}

enum UploadStatus {
  pending,
  uploading,
  processing,
  completed,
  failed,
  cancelled,
}

/// Singleton service to manage background video uploads
class BackgroundUploadService extends ChangeNotifier {
  static final BackgroundUploadService _instance =
      BackgroundUploadService._internal();
  factory BackgroundUploadService() => _instance;
  BackgroundUploadService._internal();

  final CourseService _courseService = CourseService();
  final NotificationService _notificationService = NotificationService();
  final CacheService _cacheService = CacheService();

  final List<UploadTask> _uploadTasks = [];
  List<UploadTask> get uploadTasks => List.unmodifiable(_uploadTasks);

  /// Get active uploads count
  int get activeUploadsCount => _uploadTasks
      .where(
        (t) =>
            t.status == UploadStatus.uploading ||
            t.status == UploadStatus.processing,
      )
      .length;

  /// Check if there are any active uploads
  bool get hasActiveUploads => activeUploadsCount > 0;

  /// Get current upload progress for a course
  UploadTask? getUploadForCourse(String courseUid) {
    try {
      return _uploadTasks.firstWhere(
        (t) =>
            t.courseUid == courseUid &&
            (t.status == UploadStatus.uploading ||
                t.status == UploadStatus.processing),
      );
    } catch (_) {
      return null;
    }
  }

  /// Start a background upload
  Future<void> startUpload({
    required String courseUid,
    required String courseTitle,
    required String videoTitle,
    required String videoDescription,
    required XFile videoFile,
  }) async {
    final taskId = DateTime.now().millisecondsSinceEpoch.toString();
    final task = UploadTask(
      id: taskId,
      courseUid: courseUid,
      courseTitle: courseTitle,
      videoTitle: videoTitle,
      videoDescription: videoDescription,
      videoFile: videoFile,
      cancellable: CancellableUpload(),
    );

    _uploadTasks.add(task);
    notifyListeners();

    // Start upload in background
    _processUpload(task);
  }

  /// Process the upload
  Future<void> _processUpload(UploadTask task) async {
    try {
      task.status = UploadStatus.uploading;
      notifyListeners();

      // Upload to Cloudinary with progress
      final videoUrl = await uploadToCloudinaryWithSimulatedProgress(
        task.videoFile,
        onProgress: (progress) {
          task.progress = progress;
          notifyListeners();
        },
        cancellable: task.cancellable,
      );

      // Check if cancelled
      if (task.cancellable?.isCancelled ?? false) {
        task.status = UploadStatus.cancelled;
        notifyListeners();
        _removeTaskAfterDelay(task);
        return;
      }

      if (videoUrl == null) {
        throw Exception('Failed to upload video to cloud');
      }

      // Processing phase - saving to Firebase
      task.status = UploadStatus.processing;
      task.progress = 0.95;
      notifyListeners();

      // Save to Firebase
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      await _courseService.addVideoToCourse(
        teacherUid: currentUser.uid,
        courseUid: task.courseUid,
        videoUrl: videoUrl,
        videoTitle: task.videoTitle,
        videoDescription: task.videoDescription,
      );

      // Clear caches
      _cacheService.clearPrefix('course_videos_${task.courseUid}');
      _cacheService.clearPrefix('course_detail_${task.courseUid}');
      _cacheService.clearPrefix('course_progress_');

      // Mark as completed
      task.status = UploadStatus.completed;
      task.progress = 1.0;
      notifyListeners();

      // Send notification to self about successful upload
      await _notificationService.sendNotification(
        toUid: currentUser.uid,
        title: 'Video Uploaded Successfully! 🎉',
        message: '"${task.videoTitle}" has been added to ${task.courseTitle}',
        type: 'course_update',
        relatedCourseId: task.courseUid,
      );

      // Send notifications to all enrolled students
      try {
        final enrolledStudents = await _courseService.getEnrolledStudents(
          courseUid: task.courseUid,
        );
        for (final student in enrolledStudents) {
          final studentUid = student['uid'] ?? student['studentUid'];
          if (studentUid != null && studentUid != currentUser.uid) {
            await _notificationService.notifyStudentOfNewVideo(
              studentUid: studentUid,
              courseName: task.courseTitle,
              videoTitle: task.videoTitle,
              courseId: task.courseUid,
              teacherUid: currentUser.uid,
            );
          }
        }
      } catch (e) {
        // Silent fail - don't block upload completion
        debugPrint('Failed to notify students: $e');
      }

      // Remove task from list after a delay
      _removeTaskAfterDelay(task);
    } catch (e) {
      if (task.cancellable?.isCancelled ?? false) {
        task.status = UploadStatus.cancelled;
      } else {
        task.status = UploadStatus.failed;
        task.errorMessage = e.toString();

        // Send failure notification
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          await _notificationService.sendNotification(
            toUid: currentUser.uid,
            title: 'Video Upload Failed ❌',
            message: 'Failed to upload "${task.videoTitle}". Please try again.',
            type: 'general',
            relatedCourseId: task.courseUid,
          );
        }
      }
      notifyListeners();
      _removeTaskAfterDelay(task, delay: const Duration(seconds: 10));
    }
  }

  /// Cancel an upload
  void cancelUpload(String taskId) {
    try {
      final task = _uploadTasks.firstWhere((t) => t.id == taskId);
      task.cancellable?.cancel();
      task.status = UploadStatus.cancelled;
      notifyListeners();
      _removeTaskAfterDelay(task);
    } catch (_) {}
  }

  /// Remove task after delay
  void _removeTaskAfterDelay(
    UploadTask task, {
    Duration delay = const Duration(seconds: 3),
  }) {
    Future.delayed(delay, () {
      _uploadTasks.remove(task);
      notifyListeners();
    });
  }

  /// Retry failed upload
  Future<void> retryUpload(String taskId) async {
    try {
      final task = _uploadTasks.firstWhere((t) => t.id == taskId);
      task.status = UploadStatus.pending;
      task.progress = 0.0;
      task.errorMessage = null;
      task.cancellable = CancellableUpload();
      notifyListeners();
      _processUpload(task);
    } catch (_) {}
  }
}
