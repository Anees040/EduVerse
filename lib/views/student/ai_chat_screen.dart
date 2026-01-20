import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:eduverse/services/ai_service.dart';
import 'package:eduverse/services/chat_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:eduverse/utils/app_theme.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class AIChatScreen extends StatefulWidget {
  final bool openNew;
  const AIChatScreen({super.key, this.openNew = false});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<Map<String, String>> messages = [];
  List<Map<String, dynamic>> chatHistory = [];
  String? currentChatId;
  String ownerRole = 'student';
  String? ownerId;
  bool _isLoading = false;
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    // if requested to open a fresh chat, clear active chat (no DB writes)
    if (widget.openNew) {
      currentChatId = null;
      messages = [];
    }
    // load history but don't auto-open last chat when openNew==true
    _loadChatHistory();
  }

  Future<void> _detectRole() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    ownerId = uid;
    if (uid == null) return;
    final db = FirebaseDatabase.instance.ref();
    final studentSnap = await db.child('student').child(uid).get();
    final teacherSnap = await db.child('teacher').child(uid).get();
    if (teacherSnap.exists) {
      ownerRole = 'teacher';
    } else if (studentSnap.exists) {
      ownerRole = 'student';
    } else {
      ownerRole = 'student';
    }
  }

  Future<void> _loadChatHistory() async {
    if (!mounted) return;
    setState(() => _isLoadingHistory = true);
    try {
      await _detectRole();
      if (ownerId == null) {
        if (mounted) setState(() => _isLoadingHistory = false);
        return;
      }

      final sessions = await chatRepository.getSessionsForUser(
        userId: ownerId!,
        role: ownerRole,
      );
      // Convert sessions to legacy map for UI compatibility
      chatHistory = sessions
          .map(
            (s) => {
              'id': s.id,
              'title': s.title,
              'createdAt': s.createdAt ?? 0,
              'updatedAt': s.updatedAt ?? 0,
            },
          )
          .toList();

      // set latest chat as active if none (unless opened as a fresh chat)
      if (!widget.openNew && chatHistory.isNotEmpty && currentChatId == null) {
        currentChatId = chatHistory.first['id'] as String?;
        // load messages for that chat
        await _loadChat(currentChatId!);
      }

      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _startNewChat() async {
    // Start a fresh in-memory chat without creating DB session yet.
    // Actual DB session will be created when the user sends the first message.
    if (mounted) {
      setState(() {
        currentChatId = null;
        messages = [];
      });
    }
    await _loadChatHistory();
    _closeDrawerIfOpen();
  }

  Future<void> _loadChat(String chatId) async {
    final chatMessages = await chatRepository.getMessagesForChat(chatId);
    if (!mounted) return;
    setState(() {
      currentChatId = chatId;
      messages = chatMessages
          .map(
            (m) => {
              'sender': m.role == 'user' ? 'user' : 'ai',
              'text': m.content,
            },
          )
          .toList();
    });
    _closeDrawerIfOpen();

    // Scroll to bottom after loading
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _deleteChat(String chatId) async {
    if (ownerId == null) await _detectRole();
    if (ownerId == null) return;
    await chatRepository.deleteChat(
      chatId: chatId,
      ownerId: ownerId!,
      ownerRole: ownerRole,
    );
    if (currentChatId == chatId) {
      if (mounted) {
        setState(() {
          currentChatId = null;
          messages = [];
        });
      }
    }
    await _loadChatHistory();
  }

  void _closeDrawerIfOpen() {
    final scaffoldState = _scaffoldKey.currentState;
    if (scaffoldState == null) return;
    if (scaffoldState.isDrawerOpen) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pop();
      });
    }
  }

  void _showRenameDialog(String chatId, String currentTitle) {
    final controller = TextEditingController(text: currentTitle);
    final isDark = AppTheme.isDarkMode(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.getCardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Rename Chat',
          style: TextStyle(color: AppTheme.getTextPrimary(context)),
        ),
        content: TextField(
          controller: controller,
          style: TextStyle(color: AppTheme.getTextPrimary(context)),
          decoration: InputDecoration(
            hintText: 'Enter new name',
            hintStyle: TextStyle(color: AppTheme.getTextSecondary(context)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.getBorderColor(context)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark
                    ? AppTheme.darkPrimaryLight
                    : AppTheme.primaryColor,
                width: 2,
              ),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.getTextSecondary(context)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await chatRepository.renameChat(chatId, controller.text.trim());
                await _loadChatHistory();
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark
                  ? AppTheme.darkAccent
                  : AppTheme.primaryColor,
              foregroundColor: const Color(0xFFF0F8FF),
              elevation: 6,
              shadowColor:
                  (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                      .withOpacity(0.5),
            ),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;
    // Ensure owner info and active chat
    if (ownerId == null) await _detectRole();
    if (ownerId == null) return;
    if (currentChatId == null) {
      final chatId = await chatRepository.createSession(
        ownerId: ownerId!,
        ownerRole: ownerRole,
        title: text.length > 30 ? '${text.substring(0, 30)}...' : text,
      );
      if (chatId == null) return;
      currentChatId = chatId;
      await _loadChatHistory();
    }

    if (!mounted) return;
    setState(() {
      messages.add({"sender": "user", "text": text});
      _controller.clear();
      _isLoading = true;
    });

    // Save user message to new messages store
    await chatRepository.addMessage(
      chatId: currentChatId!,
      role: 'user',
      content: text,
    );

    // Show typing indicator
    if (mounted) {
      setState(() {
        messages.add({"sender": "ai", "text": "Thinking..."});
      });
    }

    _scrollToBottom();

    try {
      final aiText = await generateAIResponse(text);

      if (mounted) {
        setState(() {
          messages.removeLast();
          messages.add({"sender": "ai", "text": aiText});
          _isLoading = false;
        });
      }

      // Save AI response to new messages store
      await chatRepository.addMessage(
        chatId: currentChatId!,
        role: 'assistant',
        content: aiText,
      );
    } catch (e) {
      final errorMessage = "Sorry, something went wrong. Please try again.";
      if (mounted) {
        setState(() {
          messages.removeLast();
          messages.add({"sender": "ai", "text": errorMessage});
          _isLoading = false;
        });
      }

      // Save error response to new messages store so chat is not lost
      if (currentChatId != null) {
        await chatRepository.addMessage(
          chatId: currentChatId!,
          role: 'assistant',
          content: errorMessage,
        );
      }
    }

    _scrollToBottom();
    await _loadChatHistory();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Prebuilt answers for common educational queries
  static final Map<String, String> _prebuiltAnswers = {
    'explain widgets in flutter': '''
## 📱 Widgets in Flutter

**Widgets** are the fundamental building blocks of Flutter applications. Everything you see on the screen is a widget!

### 🔑 Key Concepts:

**1. What is a Widget?**
A widget is an immutable description of a part of the user interface. It's like a blueprint that tells Flutter how to draw something on the screen.

**2. Types of Widgets:**

| Type | Description | Example |
|------|-------------|---------|
| **StatelessWidget** | Doesn't change once built | `Text`, `Icon`, `Container` |
| **StatefulWidget** | Can change dynamically | `TextField`, `Checkbox`, `Slider` |

**3. Widget Tree:**
Widgets are organized in a tree structure. Each widget can contain other widgets (children).

```dart
MaterialApp(
  home: Scaffold(
    appBar: AppBar(title: Text('Hello')),
    body: Center(
      child: Text('Welcome to Flutter!'),
    ),
  ),
)
```

**4. Common Widgets:**
- **Layout:** `Row`, `Column`, `Stack`, `Container`, `Padding`
- **Input:** `TextField`, `Button`, `Checkbox`, `Switch`
- **Display:** `Text`, `Image`, `Icon`, `Card`
- **Navigation:** `Navigator`, `TabBar`, `Drawer`

**5. Widget Lifecycle (StatefulWidget):**
1. `createState()` - Creates the mutable state
2. `initState()` - Called once when widget is inserted
3. `build()` - Builds the UI (called multiple times)
4. `setState()` - Triggers a rebuild
5. `dispose()` - Cleanup when removed

### 💡 Remember:
> "In Flutter, everything is a widget!" - From buttons to padding, from rows to the entire app.

Widgets are **composable**, **reusable**, and **declarative**, making Flutter development intuitive and efficient!
''',
    'what is flutter': '''
## 🚀 What is Flutter?

**Flutter** is an open-source UI software development kit created by **Google** for building beautiful, natively compiled applications for mobile, web, and desktop from a single codebase.

### 🌟 Key Features:

**1. Cross-Platform Development**
- Write once, run everywhere
- iOS, Android, Web, Windows, macOS, Linux

**2. Hot Reload**
- See changes instantly without restarting
- Speeds up development significantly

**3. Beautiful UI**
- Rich set of customizable widgets
- Material Design & Cupertino (iOS) support
- Smooth animations at 60fps

**4. Dart Language**
- Easy to learn, powerful to use
- Object-oriented and type-safe
- Ahead-of-time (AOT) compilation for performance

### 📊 Why Choose Flutter?

| Benefit | Description |
|---------|-------------|
| **Fast Development** | Hot reload, rich widgets |
| **Native Performance** | Compiled to native ARM code |
| **Single Codebase** | One code for all platforms |
| **Beautiful UIs** | Customizable widgets & animations |
| **Strong Community** | Large ecosystem & packages |

### 🏗️ Flutter Architecture:
1. **Framework (Dart)** - Widgets, animations, gestures
2. **Engine (C++)** - Skia graphics, Dart runtime
3. **Embedder** - Platform-specific code

Flutter is used by companies like Google, Alibaba, BMW, and eBay!
''',
    'what is dart': '''
## 🎯 What is Dart?

**Dart** is a client-optimized programming language developed by **Google** for building fast apps on any platform.

### 🔑 Key Features:

**1. Type-Safe Language**
```dart
String name = 'Flutter';
int count = 42;
bool isAwesome = true;
```

**2. Object-Oriented**
```dart
class Person {
  String name;
  int age;
  
  Person(this.name, this.age);
  
  void greet() => print('Hello, I am \$name');
}
```

**3. Null Safety**
```dart
String? nullableName; // Can be null
String name = 'Dart'; // Cannot be null
```

**4. Async Programming**
```dart
Future<String> fetchData() async {
  await Future.delayed(Duration(seconds: 1));
  return 'Data loaded!';
}
```

### 📊 Dart vs Other Languages:

| Feature | Dart | JavaScript | Java |
|---------|------|------------|------|
| Null Safety | ✅ Built-in | ❌ No | ⚠️ Optional |
| Type System | Sound | Dynamic | Static |
| Compilation | AOT + JIT | JIT | AOT |

### 💡 Why Dart for Flutter?
- **Hot Reload** - JIT compilation during development
- **Native Performance** - AOT compilation for production
- **Predictable** - Sound null safety prevents crashes
- **Easy to Learn** - Familiar syntax for most developers

Dart powers Flutter's amazing developer experience! 🚀
''',
    'what is stateful widget': '''
## 🔄 StatefulWidget in Flutter

A **StatefulWidget** is a widget that can change its appearance in response to events or user interactions.

### 🔑 Key Concepts:

**1. Two Classes Required:**
```dart
// The Widget class (immutable)
class Counter extends StatefulWidget {
  @override
  State<Counter> createState() => _CounterState();
}

// The State class (mutable)
class _CounterState extends State<Counter> {
  int _count = 0;
  
  @override
  Widget build(BuildContext context) {
    return Text('Count: \$_count');
  }
}
```

**2. Updating State:**
```dart
void _increment() {
  setState(() {
    _count++;
  });
}
```

### 📊 Lifecycle Methods:

| Method | When Called |
|--------|-------------|
| `createState()` | When widget is created |
| `initState()` | Once, after state is created |
| `didChangeDependencies()` | When dependencies change |
| `build()` | Every time UI needs to rebuild |
| `didUpdateWidget()` | When parent widget changes |
| `dispose()` | When widget is removed |

### 💡 When to Use StatefulWidget?
- Forms with user input
- Animations
- Data that changes over time
- Interactive elements (buttons, toggles)

### ⚠️ Best Practices:
1. Keep state minimal
2. Call `setState()` only when needed
3. Don't forget `dispose()` for cleanup
4. Consider state management for complex apps
''',
    'what is stateless widget': '''
## 📦 StatelessWidget in Flutter

A **StatelessWidget** is a widget that doesn't require mutable state - it describes part of the UI that doesn't change dynamically.

### 🔑 Key Concepts:

**1. Simple Structure:**
```dart
class Greeting extends StatelessWidget {
  final String name;
  
  const Greeting({required this.name});
  
  @override
  Widget build(BuildContext context) {
    return Text('Hello, \$name!');
  }
}
```

**2. Immutable Properties:**
- All fields should be `final`
- Use `const` constructor when possible
- Data passed through constructor

### 📊 StatelessWidget vs StatefulWidget:

| Aspect | StatelessWidget | StatefulWidget |
|--------|-----------------|----------------|
| State | No internal state | Has mutable state |
| Rebuilds | Only when parent changes | When `setState()` called |
| Performance | More efficient | Slightly more overhead |
| Use Case | Static content | Interactive content |

### 💡 When to Use StatelessWidget?
- Displaying static text or images
- Layout containers
- Icons and decorations
- Widgets that only depend on input data

### ✅ Best Practices:
```dart
// Good - use const for better performance
class MyIcon extends StatelessWidget {
  const MyIcon({super.key});
  
  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.star, color: Colors.amber);
  }
}
```

StatelessWidgets are lightweight and performant - use them when your widget doesn't need to change! 🚀
''',
  };

  // Check if user query matches any prebuilt answer
  String? _getPrebuiltAnswer(String query) {
    final normalizedQuery = query.toLowerCase().trim();

    // Direct match
    if (_prebuiltAnswers.containsKey(normalizedQuery)) {
      return _prebuiltAnswers[normalizedQuery];
    }

    // Fuzzy matching for common variations
    for (final entry in _prebuiltAnswers.entries) {
      final key = entry.key;
      // Check if query contains the key words
      if (_queryMatches(normalizedQuery, key)) {
        return entry.value;
      }
    }

    return null;
  }

  bool _queryMatches(String query, String key) {
    // Remove common question words
    final cleanQuery = query
        .replaceAll(
          RegExp(
            r'\b(what|is|are|the|a|an|in|explain|describe|tell me about|can you explain)\b',
          ),
          '',
        )
        .replaceAll(RegExp(r'[?.,!]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');

    final cleanKey = key
        .replaceAll(RegExp(r'\b(what|is|are|the|a|an|in|explain)\b'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');

    // Check for keyword matches
    final queryWords = cleanQuery.split(' ').where((w) => w.length > 2).toSet();
    final keyWords = cleanKey.split(' ').where((w) => w.length > 2).toSet();

    // If most key words are in query, it's a match
    final matchCount = keyWords
        .where(
          (kw) => queryWords.any((qw) => qw.contains(kw) || kw.contains(qw)),
        )
        .length;
    return matchCount >= keyWords.length * 0.7;
  }

  Future<String> generateAIResponse(String userText) async {
    // Check for prebuilt answer first
    final prebuiltAnswer = _getPrebuiltAnswer(userText);
    if (prebuiltAnswer != null) {
      // Add a small delay to simulate thinking
      await Future.delayed(const Duration(milliseconds: 500));
      return prebuiltAnswer;
    }

    // If no prebuilt answer, use AI service
    final response = await aiService.sendMessage(userText);
    return response;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "EduVerse AI",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: isDark
                ? AppTheme.darkPrimaryGradient
                : AppTheme.primaryGradient,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            tooltip: 'Chat History',
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            tooltip: 'New Chat',
            onPressed: _startNewChat,
          ),
        ],
      ),
      drawer: _buildChatHistoryDrawer(),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? _buildWelcomeScreen()
                : _buildChatMessages(),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildChatHistoryDrawer() {
    final isDark = AppTheme.isDarkMode(context);
    return Drawer(
      backgroundColor: AppTheme.getBackgroundColor(context),
      child: Column(
        children: [
          // Drawer Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
            decoration: BoxDecoration(
              gradient: isDark
                  ? AppTheme.darkPrimaryGradient
                  : AppTheme.primaryGradient,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.white, size: 28),
                    SizedBox(width: 10),
                    Text(
                      'Chat History',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // New Chat Button
                SizedBox(
                  width: double.infinity,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 1,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _startNewChat,
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('New Chat'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: isDark
                            ? AppTheme.darkPrimary
                            : AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Chat List
          Expanded(
            child: _isLoadingHistory
                ? Center(
                    child: CircularProgressIndicator(
                      color: isDark
                          ? AppTheme.darkPrimaryLight
                          : AppTheme.primaryColor,
                    ),
                  )
                : chatHistory.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 60,
                          color: isDark
                              ? Colors.grey.shade600
                              : Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No chat history yet',
                          style: TextStyle(
                            color: AppTheme.getTextSecondary(context),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start a new conversation!',
                          style: TextStyle(
                            color: AppTheme.getTextSecondary(context),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: chatHistory.length,
                    itemBuilder: (context, index) {
                      final chat = chatHistory[index];
                      final isSelected = chat['id'] == currentChatId;
                      return _buildChatHistoryItem(chat, isSelected);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatHistoryItem(Map<String, dynamic> chat, bool isSelected) {
    final isDark = AppTheme.isDarkMode(context);
    final date = chat['updatedAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(chat['updatedAt'])
        : DateTime.now();
    final timeAgo = _getTimeAgo(date);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? (isDark ? AppTheme.darkPrimaryLight : AppTheme.primaryColor)
                  .withOpacity(0.1)
            : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? AppTheme.darkPrimaryLight : AppTheme.primaryColor)
                      .withOpacity(0.2)
                : (isDark ? Colors.grey.shade800 : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.chat_bubble_outline,
            color: isSelected
                ? (isDark ? AppTheme.darkPrimaryLight : AppTheme.primaryColor)
                : AppTheme.getTextSecondary(context),
            size: 20,
          ),
        ),
        title: Text(
          chat['title'] ?? 'Untitled',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? (isDark ? AppTheme.darkPrimaryLight : AppTheme.primaryColor)
                : AppTheme.getTextPrimary(context),
          ),
        ),
        subtitle: Text(
          timeAgo,
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.getTextSecondary(context),
          ),
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(
            Icons.more_vert,
            color: AppTheme.getTextSecondary(context),
          ),
          color: AppTheme.getCardColor(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'rename',
              child: Row(
                children: [
                  Icon(
                    Icons.edit,
                    size: 18,
                    color: AppTheme.getTextSecondary(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Rename',
                    style: TextStyle(color: AppTheme.getTextPrimary(context)),
                  ),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'rename') {
              _showRenameDialog(chat['id'], chat['title'] ?? '');
            } else if (value == 'delete') {
              _showDeleteConfirmation(chat['id']);
            }
          },
        ),
        onTap: () => _loadChat(chat['id']),
      ),
    );
  }

  void _showDeleteConfirmation(String chatId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.getCardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Chat',
          style: TextStyle(color: AppTheme.getTextPrimary(context)),
        ),
        content: Text(
          'Are you sure you want to delete this chat? This action cannot be undone.',
          style: TextStyle(color: AppTheme.getTextSecondary(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.getTextSecondary(context)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteChat(chatId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: const Color(0xFFF5F5F5),
              elevation: 6,
              shadowColor: AppTheme.error.withOpacity(0.5),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Widget _buildWelcomeScreen() {
    final isDark = AppTheme.isDarkMode(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: isDark
                    ? AppTheme.darkPrimaryGradient
                    : AppTheme.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color:
                        (isDark
                                ? AppTheme.darkPrimaryLight
                                : AppTheme.primaryColor)
                            .withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 50,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Welcome to EduVerse AI',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppTheme.getTextPrimary(context),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your intelligent study companion',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.getTextSecondary(context),
              ),
            ),
            const SizedBox(height: 40),
            // Suggestion Cards
            _buildSuggestionCard(
              Icons.school,
              'Explain concepts',
              'Help me understand quantum physics',
            ),
            const SizedBox(height: 12),
            _buildSuggestionCard(
              Icons.quiz,
              'Create quizzes',
              'Generate a quiz on World War II',
            ),
            const SizedBox(height: 12),
            _buildSuggestionCard(
              Icons.summarize,
              'Summarize topics',
              'Summarize the French Revolution',
            ),
            const SizedBox(height: 12),
            _buildSuggestionCard(
              Icons.lightbulb_outline,
              'Get ideas',
              'Suggest project ideas for biology',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionCard(IconData icon, String title, String example) {
    final isDark = AppTheme.isDarkMode(context);
    return InkWell(
      onTap: () {
        _controller.text = example;
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.getCardColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.getBorderColor(context)),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black26 : Colors.grey.shade100,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:
                    (isDark ? AppTheme.darkPrimaryLight : AppTheme.primaryColor)
                        .withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isDark
                    ? AppTheme.darkPrimaryLight
                    : AppTheme.primaryColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.getTextPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '"$example"',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.getTextSecondary(context),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppTheme.getTextSecondary(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatMessages() {
    final isDark = AppTheme.isDarkMode(context);
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isUser = message["sender"] == "user";
        final isThinking = message["text"] == "Thinking...";

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              if (!isUser) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: isDark
                        ? AppTheme.darkPrimaryGradient
                        : AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isUser
                        ? (isDark
                              ? AppTheme
                                    .darkAccent // Teal for user messages
                              : AppTheme.primaryColor)
                        : (isDark
                              ? AppTheme
                                    .darkElevated // Better contrast for AI messages
                              : AppTheme.getCardColor(context)),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                    border: isDark && !isUser
                        ? Border.all(
                            color: AppTheme.darkBorder.withOpacity(0.5),
                            width: 1,
                          )
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? Colors.black38 : Colors.grey.shade200,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: isThinking
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.getTextSecondary(context),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Thinking...',
                              style: TextStyle(
                                color: AppTheme.getTextSecondary(context),
                              ),
                            ),
                          ],
                        )
                      : isUser
                      ? SelectableText(
                          message["text"] ?? "",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            height: 1.5,
                          ),
                        )
                      : MarkdownBody(
                          data: message["text"] ?? "",
                          selectable: true,
                          styleSheet: MarkdownStyleSheet(
                            p: TextStyle(
                              color: isDark
                                  ? AppTheme.darkTextPrimary
                                  : AppTheme.textPrimary,
                              fontSize: 15,
                              height: 1.5,
                            ),
                            h1: TextStyle(
                              color: isDark
                                  ? AppTheme.darkTextPrimary
                                  : AppTheme.textPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            h2: TextStyle(
                              color: isDark
                                  ? AppTheme.darkTextPrimary
                                  : AppTheme.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            h3: TextStyle(
                              color: isDark
                                  ? AppTheme.darkTextPrimary
                                  : AppTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            strong: TextStyle(
                              color: isDark
                                  ? AppTheme.darkTextPrimary
                                  : AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                            em: TextStyle(
                              color: isDark
                                  ? AppTheme.darkTextPrimary
                                  : AppTheme.textPrimary,
                              fontStyle: FontStyle.italic,
                            ),
                            code: TextStyle(
                              color: isDark
                                  ? Colors.greenAccent
                                  : Colors.green.shade800,
                              backgroundColor: isDark
                                  ? Colors.black26
                                  : Colors.grey.shade200,
                              fontFamily: 'monospace',
                              fontSize: 14,
                            ),
                            codeblockDecoration: BoxDecoration(
                              color: isDark
                                  ? Colors.black38
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            listBullet: TextStyle(
                              color: isDark
                                  ? AppTheme.darkTextPrimary
                                  : AppTheme.textPrimary,
                            ),
                          ),
                        ),
                ),
              ),
              if (isUser) ...[
                const SizedBox(width: 10),
                CircleAvatar(
                  radius: 16,
                  backgroundColor: isDark
                      ? AppTheme.darkAccentColor
                      : AppTheme.accentColor,
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildInputArea() {
    final isDark = AppTheme.isDarkMode(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.grey.shade200,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: KeyboardListener(
                  focusNode: FocusNode(),
                  onKeyEvent: (event) {
                    if (event is KeyDownEvent &&
                        event.logicalKey == LogicalKeyboardKey.enter &&
                        !HardwareKeyboard.instance.isShiftPressed) {
                      if (_controller.text.trim().isNotEmpty && !_isLoading) {
                        sendMessage();
                      }
                    }
                  },
                  child: TextField(
                    controller: _controller,
                    maxLines: null,
                    style: TextStyle(color: AppTheme.getTextPrimary(context)),
                    decoration: InputDecoration(
                      hintText: 'Ask me anything...',
                      hintStyle: TextStyle(
                        color: AppTheme.getTextSecondary(context),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                gradient: isDark
                    ? const LinearGradient(
                        colors: [
                          Color(0xFF2EC4B6),
                          Color(0xFF22A094),
                        ], // Vibrant teal
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color:
                        (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                            .withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: IconButton(
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white),
                onPressed: _isLoading ? null : sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
