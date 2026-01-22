import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:http/http.dart' as http;

import '../services/ai_service.dart';

/// Minimal OpenRouter implementation of `AiService`.
///
/// This class sends simple chat completion requests to OpenRouter's
/// API and returns the assistant reply as a string. Errors are returned
/// as user-friendly strings instead of throwing typed exceptions to
/// keep integration with existing app code simple.
class OpenRouterAiService implements AiService {
  final String apiKey;
  static const String _endpoint = 'https://openrouter.ai/v1/chat/completions';
  static const String _model = 'gpt-4o-mini';

  OpenRouterAiService({required this.apiKey});

  @override
  Future<String> sendMessage(String prompt, {String? systemPrompt}) async {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) return '⚠️ Please enter a question or message.';

    if (apiKey.isEmpty) return '🔑 OpenRouter API key not configured.';

    final url = Uri.parse(_endpoint);

    final system =
        systemPrompt ??
        'You are EduVerse AI, a helpful educational assistant. Provide clear, concise, and educational responses.';

    final body = {
      'model': _model,
      'messages': [
        {'role': 'system', 'content': system},
        {'role': 'user', 'content': trimmed},
      ],
      'temperature': 0.7,
      'max_tokens': 1024,
    };

    if (kDebugMode) {
      debugPrint('[OpenRouter] Sending request to $_model');
    }

    try {
      final resp = await http
          .post(
            url,
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 60));

      if (kDebugMode) debugPrint('[OpenRouter] status: ${resp.statusCode}');

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final data = jsonDecode(resp.body);
        // Expecting OpenAI-like response: choices[0].message.content
        try {
          final content = data['choices']?[0]?['message']?['content'];
          if (content is String && content.trim().isNotEmpty) {
            return content.trim();
          }
        } catch (_) {}

        // Fallback: try choices[0].text
        try {
          final text = data['choices']?[0]?['text'];
          if (text is String && text.trim().isNotEmpty) return text.trim();
        } catch (_) {}

        return '❌ Unexpected response format from OpenRouter.';
      }

      if (resp.statusCode == 429) {
        return '⏳ AI service is busy right now. Please wait a moment and try again.';
      }

      if (resp.statusCode == 401 || resp.statusCode == 403) {
        return '🔑 Invalid OpenRouter API key. Please check your configuration.';
      }

      // Try extracting error message from body
      try {
        final err = jsonDecode(resp.body);
        if (err is Map && err['error'] != null) {
          return '❌ ${err['error'].toString()}';
        }
      } catch (_) {}

      return '❌ OpenRouter API error ${resp.statusCode}';
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('timeout')) {
        return '⏱️ Request timed out. Please try again.';
      }
      if (msg.contains('socket') || msg.contains('connection')) {
        return '🌐 Network error. Please check your internet connection.';
      }
      return '❌ Error contacting OpenRouter: ${e.toString()}';
    }
  }

  @override
  Future<String> analyzeImage(String base64Image, {String? prompt}) async {
    return '📷 Image analysis is not available with the current AI provider.';
  }
}
