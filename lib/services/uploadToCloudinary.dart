import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

Future<String?> uploadToCloudinary(File file) async {
  const cloudName = "dy5pafu2s";
  const uploadPreset = "eduverse_uploads";

  final url = Uri.parse(
    "https://api.cloudinary.com/v1_1/$cloudName/auto/upload",
  );

  final request = http.MultipartRequest("POST", url);

  request.fields['upload_preset'] = uploadPreset;
  request.files.add(
    await http.MultipartFile.fromPath("file", file.path),
  );

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
      http.MultipartFile.fromBytes(
        "file",
        bytes,
        filename: file.name,
      ),
    );
  } else {
    // For mobile, use file path
    request.files.add(
      await http.MultipartFile.fromPath("file", file.path),
    );
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
