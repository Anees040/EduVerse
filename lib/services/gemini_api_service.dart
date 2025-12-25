import 'dart:convert';
import 'package:http/http.dart' as http;

/// Gemini API service for calling Google Generative Language (Gemini).
///
/// Note: keep the API key out of public repos. The code reads the key
/// from environment via `flutter_dotenv` in the caller (ai_service.dart).
class GeminiApiService {
  final String apiKey;
  final String projectId;
  final String location;

  GeminiApiService({required this.apiKey, required this.projectId, this.location = 'us-central1'});

  /// Sends a text prompt to Gemini and returns the generated content.
  Future<String> sendMessage(String prompt) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey',
    );

    final body = {
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
    };

    final resp = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      // Flexible extraction tolerant to missing fields
      try {
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        if (text is String && text.isNotEmpty) return text;
      } catch (_) {}
      return 'No response from AI';
    }

    throw Exception('Failed to call Gemini API: ${resp.statusCode} ${resp.body}');
  }
}
