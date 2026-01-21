import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Callback for upload progress (0.0 to 1.0)
typedef UploadProgressCallback = void Function(double progress);

/// Class to manage cancellable uploads
class CancellableUpload {
  bool _isCancelled = false;
  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }
}

Future<String?> uploadToCloudinary(File file) async {
  const cloudName = "dy5pafu2s";
  const uploadPreset = "eduverse_uploads";

  final url = Uri.parse(
    "https://api.cloudinary.com/v1_1/$cloudName/auto/upload",
  );

  final request = http.MultipartRequest("POST", url);

  request.fields['upload_preset'] = uploadPreset;
  request.files.add(await http.MultipartFile.fromPath("file", file.path));

  final response = await request.send();
  final responseBody = await response.stream.bytesToString();

  if (response.statusCode == 200) {
    final data = jsonDecode(responseBody);
    return data['secure_url']; // ✅ final URL
  } else {
    return null;
  }
}

/// Upload from XFile (works on both web and mobile)
Future<String?> uploadToCloudinaryFromXFile(XFile file) async {
  const cloudName = "dy5pafu2s";
  const uploadPreset = "eduverse_uploads";

  final url = Uri.parse(
    "https://api.cloudinary.com/v1_1/$cloudName/auto/upload",
  );

  final request = http.MultipartRequest("POST", url);
  request.fields['upload_preset'] = uploadPreset;

  if (kIsWeb) {
    // For web, read bytes directly
    final bytes = await file.readAsBytes();
    request.files.add(
      http.MultipartFile.fromBytes("file", bytes, filename: file.name),
    );
  } else {
    // For mobile, use file path
    request.files.add(await http.MultipartFile.fromPath("file", file.path));
  }

  final response = await request.send();
  final responseBody = await response.stream.bytesToString();

  if (response.statusCode == 200) {
    final data = jsonDecode(responseBody);
    return data['secure_url'];
  } else {
    return null;
  }
}

/// Upload from XFile with progress tracking and cancellation support
Future<String?> uploadToCloudinaryWithProgress(
  XFile file, {
  UploadProgressCallback? onProgress,
  CancellableUpload? cancellable,
}) async {
  const cloudName = "dy5pafu2s";
  const uploadPreset = "eduverse_uploads";

  final url = Uri.parse(
    "https://api.cloudinary.com/v1_1/$cloudName/auto/upload",
  );

  try {
    // Read file bytes first to calculate size
    final bytes = await file.readAsBytes();
    final totalSize = bytes.length;

    // Check if cancelled before starting
    if (cancellable?.isCancelled ?? false) {
      return null;
    }

    // Create multipart request
    final request = http.MultipartRequest("POST", url);
    request.fields['upload_preset'] = uploadPreset;

    request.files.add(
      http.MultipartFile.fromBytes("file", bytes, filename: file.name),
    );

    // Send request
    final streamedResponse = await request.send();

    // Check if cancelled after sending
    if (cancellable?.isCancelled ?? false) {
      return null;
    }

    // Track response download progress
    final List<int> responseBytes = [];
    int received = 0;
    final contentLength = streamedResponse.contentLength ?? totalSize;

    await for (final chunk in streamedResponse.stream) {
      // Check for cancellation during download
      if (cancellable?.isCancelled ?? false) {
        return null;
      }

      responseBytes.addAll(chunk);
      received += chunk.length;

      // Report progress (upload is complete, now downloading response)
      // We consider upload as 90% and response parsing as 10%
      final progress = 0.9 + (received / contentLength) * 0.1;
      onProgress?.call(progress.clamp(0.0, 1.0));
    }

    final responseBody = utf8.decode(responseBytes);

    if (streamedResponse.statusCode == 200) {
      final data = jsonDecode(responseBody);
      onProgress?.call(1.0); // Complete
      return data['secure_url'];
    } else {
      return null;
    }
  } catch (e) {
    if (cancellable?.isCancelled ?? false) {
      return null; // Cancelled, not an error
    }
    rethrow;
  }
}

/// Realistic progress upload with smooth progression from 0-100%
/// Uses chunked upload simulation for realistic progress tracking
Future<String?> uploadToCloudinaryWithSimulatedProgress(
  XFile file, {
  UploadProgressCallback? onProgress,
  CancellableUpload? cancellable,
}) async {
  const cloudName = "dy5pafu2s";
  const uploadPreset = "eduverse_uploads";

  final url = Uri.parse(
    "https://api.cloudinary.com/v1_1/$cloudName/auto/upload",
  );

  try {
    // Read file bytes first
    final bytes = await file.readAsBytes();
    final totalSize = bytes.length;

    // Check if cancelled before starting
    if (cancellable?.isCancelled ?? false) {
      return null;
    }

    // Initial progress: 0% - starting upload
    onProgress?.call(0.0);

    // Create multipart request
    final request = http.MultipartRequest("POST", url);
    request.fields['upload_preset'] = uploadPreset;

    request.files.add(
      http.MultipartFile.fromBytes("file", bytes, filename: file.name),
    );

    // Track actual upload progress using a completer
    double currentProgress = 0.0;
    bool uploadComplete = false;

    // Start realistic progress simulation that tracks actual network activity
    // This creates smoother progress instead of jumping to 90%
    Timer? progressTimer;

    // Calculate estimated time based on file size (assume 500KB/s average)
    final estimatedMs = ((totalSize / (500 * 1024)) * 1000).clamp(
      3000.0,
      120000.0,
    );
    final progressIncrement =
        0.85 / (estimatedMs / 50); // 85% for upload, updates every 50ms

    progressTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (cancellable?.isCancelled ?? false || uploadComplete) {
        timer.cancel();
        return;
      }

      // Smooth progress using easing - slows down as it approaches 85%
      if (currentProgress < 0.85) {
        // Progress faster at start, slower near end (easing)
        final remaining = 0.85 - currentProgress;
        final increment = progressIncrement * (0.5 + remaining * 0.6);
        currentProgress = (currentProgress + increment).clamp(0.0, 0.85);
        onProgress?.call(currentProgress);
      }
    });

    // Send request
    final response = await request.send();

    // Mark upload as complete to stop timer
    uploadComplete = true;
    progressTimer.cancel();

    // Check if cancelled
    if (cancellable?.isCancelled ?? false) {
      return null;
    }

    // Now at 85% - processing response (15% remaining)
    onProgress?.call(0.85);
    await Future.delayed(const Duration(milliseconds: 100));

    if (cancellable?.isCancelled ?? false) {
      return null;
    }

    onProgress?.call(0.90);

    // Read response with progress updates
    final List<int> responseBytes = [];
    int received = 0;
    final contentLength = response.contentLength ?? 1000;

    await for (final chunk in response.stream) {
      if (cancellable?.isCancelled ?? false) {
        return null;
      }

      responseBytes.addAll(chunk);
      received += chunk.length;

      // Progress from 90% to 98% during response parsing
      final responseProgress = 0.90 + (received / contentLength) * 0.08;
      onProgress?.call(responseProgress.clamp(0.90, 0.98));
    }

    final responseBody = utf8.decode(responseBytes);

    // 98% - parsing JSON
    onProgress?.call(0.98);

    if (response.statusCode == 200) {
      final data = jsonDecode(responseBody);
      // Small delay for visual feedback before 100%
      await Future.delayed(const Duration(milliseconds: 150));
      onProgress?.call(1.0); // Complete!
      return data['secure_url'];
    } else {
      return null;
    }
  } catch (e) {
    if (cancellable?.isCancelled ?? false) {
      return null;
    }
    rethrow;
  }
}
