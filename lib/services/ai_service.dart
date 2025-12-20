import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Abstract AI Service interface for EduVerse
/// 
/// This abstraction allows easy swapping of AI providers without
/// touching the UI code. Implementations should handle:
/// - Text-based message responses
/// - Image analysis (optional - can return unsupported message)
/// - Error handling and user-friendly messages
abstract class AiService {
  /// Send a text message to the AI and get a response
  /// 
  /// [prompt] - The user's question or message
  /// [systemPrompt] - Optional system instruction for the AI
  /// 
  /// Returns the AI's response as a string, or an error message
  Future<String> sendMessage(String prompt, {String? systemPrompt});

  /// Analyze an image using AI vision capabilities
  /// 
  /// [base64Image] - The image encoded as base64 string
  /// [prompt] - Optional prompt describing what to analyze
  /// 
  /// Returns the AI's analysis as a string, or an error/unsupported message
  Future<String> analyzeImage(String base64Image, {String? prompt});
}

/// Hugging Face Inference API implementation of AiService
/// 
/// Uses the Mistral-7B-Instruct-v0.2 model for text generation.
/// API Key must be set in HF_API_KEY environment variable.
/// 
/// Features:
/// - Text-based responses only (image analysis not supported)
/// - Graceful error handling
/// - Rate limit detection with user-friendly message
/// - No retries, no streaming
class HuggingFaceAiService implements AiService {
  // ============== CONFIGURATION ==============
  
  /// Model: Mistral-7B-Instruct-v0.2
  static const String _modelId = 'mistralai/Mistral-7B-Instruct-v0.2';
  
  /// Hugging Face Inference API endpoint
  static const String _baseUrl = 'https://api-inference.huggingface.co/models';
  
  /// Request timeout
  static const Duration _timeout = Duration(seconds: 60);

  // ============== STATE ==============
  
  final String? apiKey;

  HuggingFaceAiService({this.apiKey});

  // ============== MAIN API METHODS ==============

  @override
  Future<String> sendMessage(String prompt, {String? systemPrompt}) async {
    // Validate input
    final trimmedPrompt = prompt.trim();
    if (trimmedPrompt.isEmpty) {
      return '⚠️ Please enter a question or message.';
    }

    // Check API key
    if (apiKey == null || apiKey!.isEmpty) {
      return '🔑 API key not configured. Please add HF_API_KEY to your .env file.';
    }

    try {
      final response = await _callHuggingFaceApi(trimmedPrompt, systemPrompt: systemPrompt);
      return response;
    } catch (e) {
      return _getErrorMessage(e);
    }
  }

  @override
  Future<String> analyzeImage(String base64Image, {String? prompt}) async {
    // Hugging Face Mistral model doesn't support image analysis
    // Return a user-friendly message
    return '📷 Image analysis is not available with the current AI provider. '
           'Please describe your question in text, and I\'ll be happy to help!';
  }

  // ============== PRIVATE METHODS ==============

  /// Call Hugging Face Inference API
  Future<String> _callHuggingFaceApi(String prompt, {String? systemPrompt}) async {
    final url = Uri.parse('$_baseUrl/$_modelId');

    // Format the prompt with system instruction
    final systemInstruction = systemPrompt ?? 
        'You are EduVerse AI, a helpful educational assistant. '
        'Provide clear, concise, and educational responses. '
        'Help students learn and understand concepts better. '
        'Use markdown formatting for better readability.';

    // Format as instruction-following prompt for Mistral
    final formattedPrompt = '<s>[INST] $systemInstruction\n\nUser question: $prompt [/INST]';

    final body = {
      'inputs': formattedPrompt,
      'parameters': {
        'max_new_tokens': 1024,
        'temperature': 0.7,
        'top_p': 0.95,
        'do_sample': true,
        'return_full_text': false,
      },
    };

    if (kDebugMode) {
      print('[HuggingFace] Sending request to $_modelId');
    }

    final response = await http
        .post(
          url,
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(
          _timeout,
          onTimeout: () => throw Exception('Request timeout'),
        );

    if (kDebugMode) {
      print('[HuggingFace] Response status: ${response.statusCode}');
    }

    // Handle successful response
    if (response.statusCode == 200) {
      return _parseResponse(response.body);
    }

    // Handle rate limit (429)
    if (response.statusCode == 429) {
      throw RateLimitException(
        '⏳ AI service is busy right now. Please wait a moment and try again.',
      );
    }

    // Handle model loading (503 - model is loading)
    if (response.statusCode == 503) {
      final data = jsonDecode(response.body);
      final estimatedTime = data['estimated_time'];
      if (estimatedTime != null) {
        throw Exception(
          '⏳ AI model is loading. Please try again in ${estimatedTime.toStringAsFixed(0)} seconds.',
        );
      }
      throw Exception('⏳ AI model is loading. Please try again in a few moments.');
    }

    // Handle unauthorized (401)
    if (response.statusCode == 401) {
      throw Exception('🔑 Invalid API key. Please check your HF_API_KEY configuration.');
    }

    // Handle other errors
    String errorMessage = 'API error ${response.statusCode}';
    try {
      final errorData = jsonDecode(response.body);
      if (errorData is Map && errorData['error'] != null) {
        errorMessage = errorData['error'].toString();
      }
    } catch (_) {
      // Use default error message
    }
    throw Exception(errorMessage);
  }

  /// Parse the API response and extract generated text
  String _parseResponse(String responseBody) {
    try {
      final data = jsonDecode(responseBody);
      
      // Response is typically an array with generated_text
      if (data is List && data.isNotEmpty) {
        final firstResult = data[0];
        if (firstResult is Map && firstResult['generated_text'] != null) {
          final text = firstResult['generated_text'].toString().trim();
          if (text.isNotEmpty) {
            return text;
          }
        }
      }
      
      // Alternative response format
      if (data is Map && data['generated_text'] != null) {
        final text = data['generated_text'].toString().trim();
        if (text.isNotEmpty) {
          return text;
        }
      }

      throw Exception('Invalid response format');
    } catch (e) {
      if (e.toString().contains('Invalid response format')) {
        rethrow;
      }
      throw Exception('Failed to parse response: $e');
    }
  }

  /// Get user-friendly error message
  String _getErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    if (error is RateLimitException) {
      return error.message;
    }

    if (errorStr.contains('timeout')) {
      return '⏱️ Request timed out. Please check your connection and try again.';
    }

    if (errorStr.contains('socket') ||
        errorStr.contains('connection') ||
        errorStr.contains('network') ||
        errorStr.contains('failed to fetch') ||
        errorStr.contains('failed host lookup')) {
      return '🌐 Network error. Please check your internet connection.';
    }

    if (errorStr.contains('api key') || errorStr.contains('invalid') || errorStr.contains('401')) {
      return '🔑 Invalid API key. Please check your configuration.';
    }

    if (errorStr.contains('loading')) {
      return '⏳ AI model is loading. Please try again in a few moments.';
    }

    // Return the error message if it already has an emoji (formatted message)
    if (error.toString().startsWith('Exception: ') && 
        (error.toString().contains('⏳') || 
         error.toString().contains('🔑') ||
         error.toString().contains('📷'))) {
      return error.toString().replaceFirst('Exception: ', '');
    }

    return '❌ Something went wrong. Please try again.';
  }
}

// ============== CUSTOM EXCEPTIONS ==============

/// Exception for rate limit errors
class RateLimitException implements Exception {
  final String message;
  RateLimitException(this.message);

  @override
  String toString() => message;
}

/// Exception for prompt validation errors
class PromptException implements Exception {
  final String message;
  PromptException(this.message);

  @override
  String toString() => message;
}

// ============== GLOBAL INSTANCE ==============

/// Get Hugging Face API key from .env file
final String _hfApiKey = dotenv.get('HF_API_KEY', fallback: '');

/// Global AI service instance - uses Hugging Face
final AiService aiService = HuggingFaceAiService(apiKey: _hfApiKey);

/// Helper function for use in UI - wraps sendMessage with proper error handling
Future<String> generateAIResponse(String prompt, {String? systemPrompt}) async {
  try {
    return await aiService.sendMessage(prompt, systemPrompt: systemPrompt);
  } on RateLimitException catch (e) {
    return e.message;
  } on PromptException catch (e) {
    return '⚠️ ${e.message}';
  } catch (e) {
    return '❌ Error: Please try again later.';
  }
}
