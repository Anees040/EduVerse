import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// AI Service for EduVerse using xAI Grok API
///
/// Architecture:
/// - Uses Grok API directly for both web and mobile
/// - Has exponential backoff for rate limiting
/// - Includes fallback responses for demo purposes
/// - Supports both text and vision (image) queries
///
/// This ensures:
/// 1. Fast response times with direct API calls
/// 2. Graceful handling of rate limits
/// 3. Demo-ready fallback responses when API is unavailable
class GrokApiService {
  // Grok API configuration
  static const String _grokApiUrl = 'https://api.x.ai/v1/chat/completions';
  static const String _grokTextModel = 'grok-3-mini-beta';
  static const String _grokVisionModel = 'grok-2-vision-latest';

  // Pre-planned fallback responses for demo purposes
  static final Map<String, String> _fallbackResponses = {
    'help me understand quantum physics': '''
# 🔬 Understanding Quantum Physics

Quantum physics is the study of matter and energy at the smallest scales. Here are the key concepts:

## 1. Wave-Particle Duality
Everything in the quantum world behaves as both a wave and a particle. Light, for example, can act as photons (particles) or electromagnetic waves.

## 2. The Uncertainty Principle
Proposed by Heisenberg, this states that we cannot simultaneously know both the exact position and momentum of a particle with perfect precision.

## 3. Quantum Superposition
A quantum system can exist in multiple states at once until it is observed. This is famously illustrated by Schrödinger's cat thought experiment.

## 4. Quantum Entanglement
When particles become entangled, the state of one instantly influences the other, regardless of the distance between them.

## Real-world Applications:
- 💻 Quantum computers
- 🔒 Quantum cryptography
- 🏥 MRI machines in medicine
- 📱 Transistors in your phone

Would you like me to explain any of these concepts in more detail?
''',

    'generate a quiz on world war ii': '''
# 📝 World War II Quiz

Test your knowledge about World War II with these questions:

---

### Question 1:
**When did World War II begin?**
- A) 1935
- B) 1939 ✓
- C) 1941
- D) 1945

*Answer: B) September 1, 1939, when Germany invaded Poland*

---

### Question 2:
**Which countries were part of the Allied Powers?**
- A) Germany, Italy, Japan
- B) USA, UK, Soviet Union ✓
- C) Spain, Portugal, Sweden
- D) Austria, Hungary, Bulgaria

*Answer: B) The main Allied Powers were USA, UK, Soviet Union, France, and China*

---

### Question 3:
**What was D-Day?**
- A) The day Japan surrendered
- B) The Allied invasion of Normandy ✓
- C) The bombing of Pearl Harbor
- D) The start of the war

*Answer: B) June 6, 1944 - The Allied invasion of Nazi-occupied France*

---

### Question 4:
**When did World War II end?**
- A) 1944
- B) 1945 ✓
- C) 1946
- D) 1947

*Answer: B) September 2, 1945, when Japan formally surrendered*

---

### Question 5:
**What was the Holocaust?**

*Answer: The systematic genocide of approximately 6 million Jews and millions of others by Nazi Germany.*

---

**Score Guide:**
- 5/5: Excellent! 🌟
- 4/5: Great job! 👏
- 3/5: Good effort! 📚
- Below 3: Keep studying! 💪
''',

    'summarize the french revolution': '''
# 🇫🇷 The French Revolution - Summary

## Overview
The French Revolution (1789-1799) was a period of radical political and societal change in France that transformed the country from a monarchy to a republic.

## Key Causes
1. **Financial Crisis** - France was bankrupt from wars and royal extravagance
2. **Social Inequality** - The Third Estate (common people) paid most taxes
3. **Enlightenment Ideas** - Concepts of liberty, equality, and democracy spread
4. **Food Shortages** - Bread prices soared, causing widespread hunger

## Major Events Timeline

📅 **1789** - Storming of the Bastille (July 14)
📅 **1789** - Declaration of the Rights of Man adopted
📅 **1791** - New Constitution established
📅 **1792** - France becomes a Republic
📅 **1793-94** - Reign of Terror under Robespierre
📅 **1799** - Napoleon Bonaparte takes power

## Key Figures
- 👑 **King Louis XVI** - Executed monarch
- 👸 **Marie Antoinette** - Queen, executed 1793
- ⚔️ **Maximilien Robespierre** - Led the Reign of Terror
- 🎖️ **Napoleon Bonaparte** - Rose to power after revolution

## Impact
✅ End of absolute monarchy in France
✅ Spread of democratic ideals worldwide
✅ Inspiration for future revolutions
✅ Declaration of human rights principles

## Famous Motto
**"Liberté, Égalité, Fraternité"**
(Liberty, Equality, Fraternity)
''',

    'suggest project ideas for biology': '''
# 🧬 Biology Project Ideas

Here are some engaging biology project ideas for different levels:

## 🌱 Beginner Level

### 1. Plant Growth Experiment
Grow plants under different conditions (light, water, soil types) and document the results over 2-3 weeks.

### 2. Ecosystem in a Bottle
Create a self-sustaining terrarium to observe plant and water cycles.

### 3. DNA Extraction
Extract DNA from strawberries or bananas using household items.

---

## 🔬 Intermediate Level

### 4. Effects of Music on Plant Growth
Test whether different types of music affect how plants grow.

### 5. Bacteria Growth Study
Collect samples from different surfaces and grow bacteria in petri dishes to compare hygiene levels.

### 6. Heart Rate and Exercise
Measure how different activities affect heart rate and recovery time.

---

## 🧪 Advanced Level

### 7. Antibiotic Resistance
Study how bacteria develop resistance using different concentrations of antibiotics.

### 8. Enzyme Activity
Investigate how temperature and pH affect enzyme (like catalase) activity.

### 9. Genetics and Inheritance
Study inherited traits in fast-reproducing organisms like fruit flies.

---

## 💡 Tips for Success
- 📝 Keep a detailed lab notebook
- 📊 Use graphs and charts for data
- 🔄 Repeat experiments for accuracy
- 📷 Document with photos
- 🤔 Form a clear hypothesis first

Would you like more details on any of these projects?
''',

    'what is photosynthesis': '''
# 🌿 Photosynthesis Explained

Photosynthesis is the process by which plants convert light energy into chemical energy (food).

## The Basic Equation
**6CO₂ + 6H₂O + Light Energy → C₆H₁₂O₆ + 6O₂**

(Carbon Dioxide + Water + Light → Glucose + Oxygen)

## Where It Happens
📍 **Chloroplasts** - Special organelles in plant cells containing chlorophyll (the green pigment)

## Two Main Stages

### 1. Light-Dependent Reactions
- Occur in the thylakoid membranes
- Light energy splits water molecules
- Produces ATP and NADPH (energy carriers)
- Releases oxygen as a byproduct

### 2. Light-Independent Reactions (Calvin Cycle)
- Occur in the stroma
- Uses ATP and NADPH to convert CO₂ into glucose
- Does not directly need light

## Why It Matters
🌍 Produces oxygen we breathe
🍎 Creates food for plants (and indirectly for us)
🌡️ Helps regulate Earth's climate
⛽ Fossil fuels come from ancient photosynthetic organisms

## Fun Fact
Plants produce about 70% of Earth's oxygen through photosynthesis!
''',

    'explain newton\'s laws of motion': '''
# ⚡ Newton's Three Laws of Motion

Sir Isaac Newton published these fundamental laws in 1687, forming the foundation of classical mechanics.

---

## 🥇 First Law: Law of Inertia

> **"An object at rest stays at rest, and an object in motion stays in motion at constant velocity, unless acted upon by an external force."**

### Examples:
- A book on a table stays there until you push it
- A hockey puck slides until friction stops it
- You lurch forward when a car brakes suddenly

---

## 🥈 Second Law: Force and Acceleration

> **F = ma** (Force = Mass × Acceleration)

### Key Points:
- More force = more acceleration
- More mass = less acceleration (for same force)
- Force and acceleration are in the same direction

### Examples:
- It's harder to push a heavy box than a light one
- A tennis ball accelerates faster than a bowling ball with the same force

---

## 🥉 Third Law: Action and Reaction

> **"For every action, there is an equal and opposite reaction."**

### Examples:
- 🚀 Rocket pushes gas down, gas pushes rocket up
- 🏊 Swimmer pushes water back, water pushes swimmer forward
- 🚶 You push Earth backward when walking, Earth pushes you forward

---

## Quick Summary Table

| Law | Key Concept | Formula |
|-----|-------------|---------|
| 1st | Inertia | Objects resist change |
| 2nd | F = ma | Force causes acceleration |
| 3rd | Action-Reaction | Forces come in pairs |
''',

    'what is machine learning': '''
# 🤖 Machine Learning Explained

Machine Learning (ML) is a branch of Artificial Intelligence that enables computers to learn from data without being explicitly programmed.

## How It Works
Instead of writing specific rules, we feed the computer lots of examples, and it learns patterns on its own.

## Three Main Types

### 1. 📊 Supervised Learning
- Computer learns from labeled examples
- Like a teacher showing correct answers
- **Examples:** Spam detection, image classification

### 2. 🔍 Unsupervised Learning
- Computer finds patterns in unlabeled data
- No "correct answers" provided
- **Examples:** Customer grouping, recommendation systems

### 3. 🎮 Reinforcement Learning
- Computer learns through trial and error
- Gets rewards for good decisions
- **Examples:** Game AI, self-driving cars

## Real-World Applications

| Application | How ML is Used |
|-------------|----------------|
| 📧 Email | Spam filtering |
| 🎵 Spotify | Song recommendations |
| 📸 Photos | Face recognition |
| 🗣️ Siri/Alexa | Voice recognition |
| 🚗 Tesla | Self-driving |
| 🏥 Healthcare | Disease diagnosis |

## Simple Example
Teaching ML to recognize cats:
1. Show it 10,000 cat pictures ✅
2. Show it 10,000 non-cat pictures ❌
3. It learns features of cats (ears, whiskers, etc.)
4. Now it can identify cats in new pictures!

## Key Terms
- **Algorithm** - The learning method used
- **Model** - What the computer creates after learning
- **Training** - The learning process
- **Dataset** - Collection of examples used to train
''',
  };

  /// Get fallback response for demo purposes
  static String? _getFallbackResponse(String prompt) {
    final lowerPrompt = prompt.toLowerCase().trim();

    // Check for exact or close matches
    for (final entry in _fallbackResponses.entries) {
      if (lowerPrompt.contains(entry.key) || entry.key.contains(lowerPrompt)) {
        return entry.value;
      }
    }

    // Check for keyword matches
    if (lowerPrompt.contains('quantum') || lowerPrompt.contains('physics')) {
      return _fallbackResponses['help me understand quantum physics'];
    }
    if (lowerPrompt.contains('world war') ||
        lowerPrompt.contains('ww2') ||
        lowerPrompt.contains('wwii')) {
      return _fallbackResponses['generate a quiz on world war ii'];
    }
    if (lowerPrompt.contains('french revolution')) {
      return _fallbackResponses['summarize the french revolution'];
    }
    if (lowerPrompt.contains('biology') ||
        lowerPrompt.contains('project idea')) {
      return _fallbackResponses['suggest project ideas for biology'];
    }
    if (lowerPrompt.contains('photosynthesis') ||
        lowerPrompt.contains('plant')) {
      return _fallbackResponses['what is photosynthesis'];
    }
    if (lowerPrompt.contains('newton') ||
        lowerPrompt.contains('motion') ||
        lowerPrompt.contains('force')) {
      return _fallbackResponses['explain newton\'s laws of motion'];
    }
    if (lowerPrompt.contains('machine learning') ||
        lowerPrompt.contains('ai') ||
        lowerPrompt.contains('artificial intelligence')) {
      return _fallbackResponses['what is machine learning'];
    }

    return null;
  }

  final String? apiKey;

  // Rate limiting protection with exponential backoff
  DateTime? _lastRequestTime;
  int _consecutiveRateLimits = 0;
  static const _baseRequestInterval = Duration(seconds: 2);
  static const _maxBackoffSeconds = 60;

  GrokApiService({this.apiKey});

  /// Calculate delay based on consecutive rate limits (exponential backoff)
  Duration _getBackoffDelay() {
    if (_consecutiveRateLimits == 0) return _baseRequestInterval;
    final seconds =
        (_baseRequestInterval.inSeconds * (1 << _consecutiveRateLimits)).clamp(
          2,
          _maxBackoffSeconds,
        );
    return Duration(seconds: seconds);
  }

  /// Send a message to Grok AI and get a response
  Future<String> sendMessage(
    String prompt, {
    String? systemPrompt,
    int retryCount = 0,
  }) async {
    // First, check for fallback response (for demo purposes)
    final fallbackResponse = _getFallbackResponse(prompt);

    // Rate limiting with exponential backoff
    if (_lastRequestTime != null) {
      final backoffDelay = _getBackoffDelay();
      final elapsed = DateTime.now().difference(_lastRequestTime!);
      if (elapsed < backoffDelay) {
        await Future.delayed(backoffDelay - elapsed);
      }
    }
    _lastRequestTime = DateTime.now();

    // Try Grok API directly
    if (apiKey != null && apiKey!.isNotEmpty) {
      try {
        final response = await _callGrokApi(prompt, systemPrompt: systemPrompt);
        _consecutiveRateLimits = 0; // Reset on success
        return response;
      } catch (e) {
        final errorStr = e.toString().toLowerCase();

        if (kDebugMode) {
          print('Grok API error: $e');
        }

        // Handle rate limiting with retry
        if (errorStr.contains('rate_limit') || errorStr.contains('429')) {
          _consecutiveRateLimits++;

          if (retryCount < 3) {
            final waitTime = _getBackoffDelay();
            if (kDebugMode) {
              print(
                'Rate limited. Waiting ${waitTime.inSeconds}s before retry #${retryCount + 1}',
              );
            }
            await Future.delayed(waitTime);
            return sendMessage(
              prompt,
              systemPrompt: systemPrompt,
              retryCount: retryCount + 1,
            );
          }
        }

        // Return fallback response if available, otherwise error message
        if (fallbackResponse != null) {
          return fallbackResponse;
        }
        return _getErrorMessage(e);
      }
    }

    // If no API key, use fallback response if available
    if (fallbackResponse != null) {
      // Add small delay to simulate API call
      await Future.delayed(const Duration(milliseconds: 800));
      return fallbackResponse;
    }

    return '🔑 API key not configured. Please check your settings.';
  }

  /// Call Grok API directly for text queries
  Future<String> _callGrokApi(String prompt, {String? systemPrompt}) async {
    if (apiKey == null || apiKey!.isEmpty) {
      throw Exception('API key not configured');
    }

    final url = Uri.parse(_grokApiUrl);

    final systemInstruction =
        systemPrompt ??
        'You are EduVerse AI, a helpful educational assistant powered by Grok. Provide clear, concise, and educational responses. Help students learn and understand concepts better. Use markdown formatting for better readability.';

    final body = {
      'model': _grokTextModel,
      'messages': [
        {'role': 'system', 'content': systemInstruction},
        {'role': 'user', 'content': prompt},
      ],
      'temperature': 0.7,
      'max_tokens': 4096,
      'stream': false,
    };

    if (kDebugMode) {
      print('Grok API Request: ${jsonEncode(body)}');
    }

    final response = await http
        .post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode(body),
        )
        .timeout(
          const Duration(seconds: 60),
          onTimeout: () => throw Exception('Request timeout'),
        );

    if (kDebugMode) {
      print('Grok API Response Status: ${response.statusCode}');
      print('Grok API Response Body: ${response.body}');
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final choices = data['choices'] as List?;
      if (choices != null && choices.isNotEmpty) {
        final message = choices[0]['message'];
        final content = message['content'] as String?;
        if (content != null && content.isNotEmpty) {
          return content;
        }
      }
      throw Exception('Invalid response format');
    } else if (response.statusCode == 429) {
      throw Exception('rate_limit');
    } else {
      // Safe error parsing
      String errorMessage = 'API error ${response.statusCode}';
      try {
        final errorData = jsonDecode(response.body);
        if (errorData is Map) {
          final error = errorData['error'];
          if (error is Map) {
            errorMessage = error['message']?.toString() ?? errorMessage;
          } else if (error is String) {
            errorMessage = error;
          }
        }
      } catch (_) {
        // Use default error message
      }
      throw Exception(errorMessage);
    }
  }

  /// Get user-friendly error message
  String _getErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('rate_limit') || errorStr.contains('429')) {
      return '⏳ AI is busy right now. Please wait a few seconds and try again.';
    }

    if (errorStr.contains('timeout')) {
      return '⏱️ Request timed out. Please check your connection and try again.';
    }

    if (errorStr.contains('socket') ||
        errorStr.contains('connection') ||
        errorStr.contains('network') ||
        errorStr.contains('failed to fetch')) {
      return '🌐 Network error. Please check your internet connection.';
    }

    if (errorStr.contains('failed host lookup') ||
        errorStr.contains('404') ||
        errorStr.contains('not found')) {
      return '⚠️ AI service temporarily unavailable. Please try again later.';
    }

    if (errorStr.contains('api key') || errorStr.contains('invalid')) {
      return '🔑 Invalid API key. Please check your configuration.';
    }

    return '❌ Something went wrong. Please try again.';
  }

  /// Analyze an image using Grok Vision API (for homework help feature)
  Future<String> analyzeImage(
    String base64Image, {
    String? prompt,
    int retryCount = 0,
  }) async {
    // Rate limiting with exponential backoff
    if (_lastRequestTime != null) {
      final backoffDelay = _getBackoffDelay();
      final elapsed = DateTime.now().difference(_lastRequestTime!);
      if (elapsed < backoffDelay) {
        await Future.delayed(backoffDelay - elapsed);
      }
    }
    _lastRequestTime = DateTime.now();

    // Try Grok Vision API directly
    if (apiKey != null && apiKey!.isNotEmpty) {
      try {
        final response = await _callGrokVisionApi(base64Image, prompt: prompt);
        _consecutiveRateLimits = 0; // Reset on success
        return response;
      } catch (e) {
        final errorStr = e.toString().toLowerCase();

        if (kDebugMode) {
          print('Grok Vision API error: $e');
        }

        // Handle rate limiting with retry
        if (errorStr.contains('rate_limit') || errorStr.contains('429')) {
          _consecutiveRateLimits++;

          if (retryCount < 3) {
            final waitTime = _getBackoffDelay();
            if (kDebugMode) {
              print(
                'Rate limited. Waiting ${waitTime.inSeconds}s before retry #${retryCount + 1}',
              );
            }
            await Future.delayed(waitTime);
            return analyzeImage(
              base64Image,
              prompt: prompt,
              retryCount: retryCount + 1,
            );
          }
        }

        return _getErrorMessage(e);
      }
    }

    return '🔑 API key not configured. Please check your settings.';
  }

  /// Call Grok Vision API directly for image analysis
  Future<String> _callGrokVisionApi(
    String base64Image, {
    String? prompt,
  }) async {
    if (apiKey == null || apiKey!.isEmpty) {
      throw Exception('API key not configured');
    }

    final url = Uri.parse(_grokApiUrl);

    final userPrompt =
        prompt ??
        'Please help me solve this homework problem. Explain step by step. If it\'s a math problem, show all work clearly.';

    // Clean up base64 string - remove any data URL prefix if present
    String cleanBase64 = base64Image;
    if (cleanBase64.contains(',')) {
      cleanBase64 = cleanBase64.split(',').last;
    }
    // Remove any whitespace or newlines
    cleanBase64 = cleanBase64.replaceAll(RegExp(r'\s'), '');

    final body = {
      'model': _grokVisionModel,
      'messages': [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': userPrompt},
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:image/jpeg;base64,$cleanBase64',
                'detail': 'high',
              },
            },
          ],
        },
      ],
      'max_tokens': 4096,
      'stream': false,
    };

    if (kDebugMode) {
      print('Grok Vision API Request model: $_grokVisionModel');
      print('Grok Vision API base64 length: ${cleanBase64.length}');
    }

    final response = await http
        .post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode(body),
        )
        .timeout(
          const Duration(seconds: 90),
          onTimeout: () => throw Exception('Request timeout'),
        );

    if (kDebugMode) {
      print('Grok Vision API Response Status: ${response.statusCode}');
      print('Grok Vision API Response Body: ${response.body}');
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final choices = data['choices'] as List?;
      if (choices != null && choices.isNotEmpty) {
        final message = choices[0]['message'];
        final content = message['content'] as String?;
        if (content != null && content.isNotEmpty) {
          return content;
        }
      }
      throw Exception('Invalid response format');
    } else if (response.statusCode == 429) {
      throw Exception('rate_limit');
    } else {
      // Safe error parsing
      String errorMessage = 'API error ${response.statusCode}';
      try {
        final errorData = jsonDecode(response.body);
        if (errorData is Map) {
          final error = errorData['error'];
          if (error is Map) {
            errorMessage = error['message']?.toString() ?? errorMessage;
          } else if (error is String) {
            errorMessage = error;
          }
        }
      } catch (_) {
        // Use default error message
      }
      throw Exception(errorMessage);
    }
  }
}

// Get Grok API key from .env file (key is stored as GROQ_API_KEY but it's actually xAI key)
final _apiKey = dotenv.get('GROQ_API_KEY', fallback: '');

// Global AI service instance using Grok
final grokAiService = GrokApiService(apiKey: _apiKey);

// Alias for backward compatibility - maps to Grok service
final aiService = grokAiService;
