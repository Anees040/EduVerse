import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class ChatSession {
  final String id;
  final String ownerId;
  final String ownerRole;
  final String title;
  final int? createdAt;
  final int? updatedAt;

  ChatSession({
    required this.id,
    required this.ownerId,
    required this.ownerRole,
    required this.title,
    this.createdAt,
    this.updatedAt,
  });

  factory ChatSession.fromMap(String id, Map data) {
    return ChatSession(
      id: id,
      ownerId: data['ownerId'] ?? '',
      ownerRole: data['ownerRole'] ?? 'student',
      title: data['title'] ?? 'New Chat',
      createdAt: data['createdAt'] is int ? data['createdAt'] as int : null,
      updatedAt: data['updatedAt'] is int ? data['updatedAt'] as int : null,
    );
  }
}

class ChatMessage {
  final String id;
  final String role;
  final String content;
  final int? timestamp;

  ChatMessage({required this.id, required this.role, required this.content, this.timestamp});

  factory ChatMessage.fromMap(String id, Map data) {
    return ChatMessage(
      id: id,
      role: data['role'] ?? 'user',
      content: data['content'] ?? '',
      timestamp: data['timestamp'] is int ? data['timestamp'] as int : null,
    );
  }
}

/// ChatRepository abstracts chat_sessions and chat_messages.
///
/// Allowed write paths:
/// - chat_sessions/{chatId}
/// - chat_messages/{chatId}/{messageId}
/// - student/{uid}/chatIds/{chatId}: true
/// - teacher/{uid}/chatIds/{chatId}: true
class ChatRepository {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final String? _currentUid = FirebaseAuth.instance.currentUser?.uid;

  String? activeChatId;

  /// Create a new chat session and add a chatIds reference under the owner
  Future<String?> createSession({required String ownerId, required String ownerRole, String? title}) async {
    final sessionRef = _db.child('chat_sessions').push();
    final chatId = sessionRef.key;
    if (chatId == null) return null;

    final now = ServerValue.timestamp;
    await sessionRef.set({
      'ownerId': ownerId,
      'ownerRole': ownerRole,
      'title': title ?? 'New Chat',
      'createdAt': now,
      'updatedAt': now,
    });

    final ownerPath = ownerRole == 'teacher' ? 'teacher' : 'student';
    await _db.child(ownerPath).child(ownerId).child('chatIds').child(chatId).set(true);

    activeChatId = chatId;
    return chatId;
  }

  /// Append a message to a chat. Always writes to chat_messages/{chatId}
  Future<void> addMessage({required String chatId, required String role, required String content, int? timestamp}) async {
    final msgRef = _db.child('chat_messages').child(chatId).push();
    final data = {
      'role': role,
      'content': content,
      'timestamp': timestamp ?? ServerValue.timestamp,
    };
    await msgRef.set(data);

    // Update session's updatedAt
    await _db.child('chat_sessions').child(chatId).update({'updatedAt': ServerValue.timestamp});
  }

  /// Read sessions for a user by reading student/teacher/{uid}/chatIds and fetching sessions
  Future<List<ChatSession>> getSessionsForUser({required String userId, required String role}) async {
    final ownerPath = role == 'teacher' ? 'teacher' : 'student';
    final snapshot = await _db.child(ownerPath).child(userId).child('chatIds').get();
    if (!snapshot.exists) return [];

    final data = snapshot.value as Map;
    final List<ChatSession> sessions = [];

    for (final key in data.keys) {
      final sessionSnap = await _db.child('chat_sessions').child(key).get();
      if (sessionSnap.exists) {
        final sdata = sessionSnap.value as Map;
        sessions.add(ChatSession.fromMap(key, sdata));
      }
    }

    // sort by updatedAt descending
    sessions.sort((a, b) {
      final at = a.updatedAt ?? 0;
      final bt = b.updatedAt ?? 0;
      return bt.compareTo(at);
    });
    return sessions;
  }

  /// Get messages for a chatId
  Future<List<ChatMessage>> getMessagesForChat(String chatId) async {
    final snap = await _db.child('chat_messages').child(chatId).get();
    if (!snap.exists) return [];

    final data = snap.value as Map;
    final List<ChatMessage> msgs = [];
    data.forEach((key, value) {
      if (value is Map) {
        msgs.add(ChatMessage.fromMap(key, value));
      }
    });

    msgs.sort((a, b) {
      final at = a.timestamp ?? 0;
      final bt = b.timestamp ?? 0;
      return at.compareTo(bt);
    });

    return msgs;
  }

  /// Rename a chat session (only chat_sessions node)
  Future<void> renameChat(String chatId, String newTitle) async {
    await _db.child('chat_sessions').child(chatId).update({'title': newTitle});
  }

  /// Delete chat: remove chat_sessions/{chatId}, chat_messages/{chatId}, and owner chatIds reference only
  Future<void> deleteChat({required String chatId, required String ownerId, required String ownerRole}) async {
    // remove session
    await _db.child('chat_sessions').child(chatId).remove();
    // remove messages
    await _db.child('chat_messages').child(chatId).remove();
    // remove owner reference
    final ownerPath = ownerRole == 'teacher' ? 'teacher' : 'student';
    await _db.child(ownerPath).child(ownerId).child('chatIds').child(chatId).remove();
  }

  /// Utility: ensure there's an active chat; create one if missing for current user
  Future<String?> ensureActiveChat({required String ownerRole, String? ownerId, String? title}) async {
    final uid = ownerId ?? _currentUid;
    if (uid == null) return null;
    if (activeChatId != null) return activeChatId;
    return await createSession(ownerId: uid, ownerRole: ownerRole, title: title);
  }
}

final chatRepository = ChatRepository();
