import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatHistoryService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  /// Create a new chat conversation
  Future<String?> createNewChat({String? title}) async {
    if (_userId == null) return null;

    final chatRef = _db.child('chat_history').child(_userId!).push();
    final chatId = chatRef.key;

    await chatRef.set({
      'id': chatId,
      'title': title ?? 'New Chat',
      'createdAt': ServerValue.timestamp,
      'updatedAt': ServerValue.timestamp,
      'messages': [],
    });

    return chatId;
  }

  /// Add a message to a chat
  Future<void> addMessage({
    required String chatId,
    required String sender,
    required String text,
  }) async {
    if (_userId == null) return;

    final messageRef = _db
        .child('chat_history')
        .child(_userId!)
        .child(chatId)
        .child('messages')
        .push();

    await messageRef.set({
      'sender': sender,
      'text': text,
      'timestamp': ServerValue.timestamp,
    });

    // Update chat's updatedAt and title if it's the first user message
    final chatRef = _db.child('chat_history').child(_userId!).child(chatId);

    if (sender == 'user') {
      // Update title with first few words of first user message
      final chatSnapshot = await chatRef.get();
      if (chatSnapshot.exists) {
        final data = chatSnapshot.value as Map;
        if (data['title'] == 'New Chat') {
          final shortTitle = text.length > 30
              ? '${text.substring(0, 30)}...'
              : text;
          await chatRef.update({
            'title': shortTitle,
            'updatedAt': ServerValue.timestamp,
          });
        } else {
          await chatRef.update({'updatedAt': ServerValue.timestamp});
        }
      }
    }
  }

  /// Get all chats for current user
  Future<List<Map<String, dynamic>>> getAllChats() async {
    if (_userId == null) return [];

    final snapshot = await _db
        .child('chat_history')
        .child(_userId!)
        .orderByChild('updatedAt')
        .limitToLast(50)
        .get();

    if (!snapshot.exists) return [];

    final List<Map<String, dynamic>> chats = [];
    final data = snapshot.value as Map;

    data.forEach((key, value) {
      if (value is Map) {
        chats.add({
          'id': key,
          'title': value['title'] ?? 'Untitled',
          'createdAt': value['createdAt'],
          'updatedAt': value['updatedAt'],
        });
      }
    });

    // Sort by updatedAt descending (most recent first)
    chats.sort((a, b) {
      final aTime = a['updatedAt'] ?? 0;
      final bTime = b['updatedAt'] ?? 0;
      return bTime.compareTo(aTime);
    });

    return chats;
  }

  /// Get messages for a specific chat
  Future<List<Map<String, dynamic>>> getChatMessages(String chatId) async {
    if (_userId == null) return [];

    final snapshot = await _db
        .child('chat_history')
        .child(_userId!)
        .child(chatId)
        .child('messages')
        .get();

    if (!snapshot.exists) return [];

    final List<Map<String, dynamic>> messages = [];
    final data = snapshot.value as Map;

    data.forEach((key, value) {
      if (value is Map) {
        messages.add({
          'id': key,
          'sender': value['sender'] ?? '',
          'text': value['text'] ?? '',
          'timestamp': value['timestamp'],
        });
      }
    });

    // Sort by timestamp ascending
    messages.sort((a, b) {
      final aTime = a['timestamp'] ?? 0;
      final bTime = b['timestamp'] ?? 0;
      return aTime.compareTo(bTime);
    });

    return messages;
  }

  /// Delete a chat
  Future<void> deleteChat(String chatId) async {
    if (_userId == null) return;
    await _db.child('chat_history').child(_userId!).child(chatId).remove();
  }

  /// Rename a chat
  Future<void> renameChat(String chatId, String newTitle) async {
    if (_userId == null) return;
    await _db.child('chat_history').child(_userId!).child(chatId).update({
      'title': newTitle,
    });
  }
}

final chatHistoryService = ChatHistoryService();
