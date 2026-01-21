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

    // Track upload progress
    double currentProgress = 0.0;
    bool uploadComplete = false;

    // Calculate estimated time based on file size
    // Assume ~300KB/s average mobile speed, adjust based on size
    final estimatedSeconds = (totalSize / (300 * 1024)).clamp(2.0, 60.0);
    final totalSteps = (estimatedSeconds * 20).round(); // 20 updates per second
    final progressPerStep = 0.80 / totalSteps; // Upload phase is 0-80%

    // Start progress simulation timer
    Timer? progressTimer;
    int stepCount = 0;

    progressTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (cancellable?.isCancelled ?? false || uploadComplete) {
        timer.cancel();
        return;
      }

      stepCount++;
      if (currentProgress < 0.80) {
        // Smooth progression with slight randomness for realism
        final jitter = (stepCount % 5 == 0) ? 0.005 : 0.0;
        currentProgress = (currentProgress + progressPerStep + jitter).clamp(
          0.0,
          0.80,
        );
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

    // Progress 80% -> 85%: Server received file
    for (double p = 0.80; p <= 0.85; p += 0.01) {
      await Future.delayed(const Duration(milliseconds: 30));
      onProgress?.call(p);
    }

    if (cancellable?.isCancelled ?? false) {
      return null;
    }

    // Read response with progress updates (85% -> 95%)
    final List<int> responseBytes = [];
    int received = 0;
    final contentLength = response.contentLength ?? 1000;

    await for (final chunk in response.stream) {
      if (cancellable?.isCancelled ?? false) {
        return null;
      }

      responseBytes.addAll(chunk);
      received += chunk.length;

      // Progress from 85% to 95% during response reading
      final responseProgress = 0.85 + (received / contentLength) * 0.10;
      onProgress?.call(responseProgress.clamp(0.85, 0.95));
    }

    final responseBody = utf8.decode(responseBytes);

    // 95% -> 98%: Parsing response
    onProgress?.call(0.96);
    await Future.delayed(const Duration(milliseconds: 50));
    onProgress?.call(0.98);

    if (response.statusCode == 200) {
      final data = jsonDecode(responseBody);
      // Final progress to 100%
      await Future.delayed(const Duration(milliseconds: 100));
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
