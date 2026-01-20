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

/// Simulated progress upload for better UX (estimates progress based on file size)
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

    // Start progress simulation based on file size
    // Estimate: ~1MB per second for typical upload speeds
    final estimatedSeconds = (totalSize / (1024 * 1024)).clamp(2.0, 60.0);
    final updateInterval = Duration(milliseconds: 100);
    final totalUpdates = (estimatedSeconds * 10).toInt();
    int currentUpdate = 0;

    // Start simulated progress timer
    Timer? progressTimer;
    double simulatedProgress = 0.0;

    progressTimer = Timer.periodic(updateInterval, (timer) {
      if (cancellable?.isCancelled ?? false) {
        timer.cancel();
        return;
      }

      currentUpdate++;
      // Use easing function for more realistic progress
      // Progress slows down as it approaches 90%
      simulatedProgress = (currentUpdate / totalUpdates) * 0.9;
      simulatedProgress = simulatedProgress.clamp(0.0, 0.9);
      onProgress?.call(simulatedProgress);

      if (currentUpdate >= totalUpdates) {
        timer.cancel();
      }
    });

    // Create multipart request
    final request = http.MultipartRequest("POST", url);
    request.fields['upload_preset'] = uploadPreset;

    request.files.add(
      http.MultipartFile.fromBytes("file", bytes, filename: file.name),
    );

    // Send request
    final response = await request.send();

    // Cancel progress timer
    progressTimer.cancel();

    // Check if cancelled
    if (cancellable?.isCancelled ?? false) {
      return null;
    }

    // Jump to 95% while processing response
    onProgress?.call(0.95);

    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      final data = jsonDecode(responseBody);
      onProgress?.call(1.0); // Complete
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
