import 'package:firebase_database/firebase_database.dart';

/// Support Service - Handles user support tickets and admin responses
class SupportService {
  static final SupportService _instance = SupportService._internal();
  factory SupportService() => _instance;
  SupportService._internal();

  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  /// Create a new support ticket
  Future<String?> createTicket({
    required String userId,
    required String userEmail,
    required String userName,
    required String userRole, // 'student', 'teacher', 'suspended'
    required String subject,
    required String message,
    required String category, // 'account', 'technical', 'billing', 'other'
    String? priority, // 'low', 'medium', 'high', 'urgent'
  }) async {
    try {
      final ticketRef = _db.child('support_tickets').push();
      final ticketId = ticketRef.key!;
      
      await ticketRef.set({
        'ticketId': ticketId,
        'userId': userId,
        'userEmail': userEmail,
        'userName': userName,
        'userRole': userRole,
        'subject': subject,
        'category': category,
        'priority': priority ?? 'medium',
        'status': 'open', // open, in_progress, resolved, closed
        'createdAt': ServerValue.timestamp,
        'updatedAt': ServerValue.timestamp,
        'messages': {
          '0': {
            'senderId': userId,
            'senderName': userName,
            'senderRole': userRole,
            'message': message,
            'timestamp': ServerValue.timestamp,
          }
        },
        'assignedTo': null,
        'resolvedAt': null,
      });

      return ticketId;
    } catch (e) {
      return null;
    }
  }

  /// Add a message to an existing ticket
  Future<bool> addMessage({
    required String ticketId,
    required String senderId,
    required String senderName,
    required String senderRole,
    required String message,
  }) async {
    try {
      final messageRef = _db.child('support_tickets/$ticketId/messages').push();
      
      await messageRef.set({
        'senderId': senderId,
        'senderName': senderName,
        'senderRole': senderRole,
        'message': message,
        'timestamp': ServerValue.timestamp,
      });

      // Update ticket's updatedAt
      await _db.child('support_tickets/$ticketId').update({
        'updatedAt': ServerValue.timestamp,
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Admin reply to a ticket
  Future<bool> adminReply({
    required String ticketId,
    required String adminId,
    required String adminName,
    required String message,
    bool markInProgress = true,
  }) async {
    try {
      final messageRef = _db.child('support_tickets/$ticketId/messages').push();
      
      await messageRef.set({
        'senderId': adminId,
        'senderName': adminName,
        'senderRole': 'admin',
        'message': message,
        'timestamp': ServerValue.timestamp,
      });

      // Update ticket status and timestamp
      final updates = <String, dynamic>{
        'updatedAt': ServerValue.timestamp,
        'assignedTo': adminId,
      };
      
      if (markInProgress) {
        updates['status'] = 'in_progress';
      }

      await _db.child('support_tickets/$ticketId').update(updates);

      // Create notification for user
      final ticketSnapshot = await _db.child('support_tickets/$ticketId').get();
      if (ticketSnapshot.exists) {
        final ticketData = Map<String, dynamic>.from(ticketSnapshot.value as Map);
        final userId = ticketData['userId'];
        
        await _db.child('notifications/$userId').push().set({
          'type': 'support_reply',
          'title': 'Support Reply',
          'message': 'You have a new reply to your support ticket',
          'ticketId': ticketId,
          'timestamp': ServerValue.timestamp,
          'read': false,
        });
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Update ticket status
  Future<bool> updateTicketStatus({
    required String ticketId,
    required String status,
    String? adminId,
  }) async {
    try {
      final updates = <String, dynamic>{
        'status': status,
        'updatedAt': ServerValue.timestamp,
      };

      if (adminId != null) {
        updates['assignedTo'] = adminId;
      }

      if (status == 'resolved') {
        updates['resolvedAt'] = ServerValue.timestamp;
      }

      await _db.child('support_tickets/$ticketId').update(updates);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get all tickets (for admin)
  Future<List<Map<String, dynamic>>> getAllTickets({
    String? statusFilter,
    String? categoryFilter,
    String? priorityFilter,
    int limit = 50,
  }) async {
    try {
      Query query = _db.child('support_tickets').orderByChild('createdAt');
      
      final snapshot = await query.limitToLast(limit).get();
      
      if (!snapshot.exists || snapshot.value == null) {
        return [];
      }

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      var tickets = data.entries.map((e) {
        final ticket = Map<String, dynamic>.from(e.value as Map);
        ticket['id'] = e.key;
        return ticket;
      }).toList();

      // Apply filters
      if (statusFilter != null) {
        tickets = tickets.where((t) => t['status'] == statusFilter).toList();
      }
      if (categoryFilter != null) {
        tickets = tickets.where((t) => t['category'] == categoryFilter).toList();
      }
      if (priorityFilter != null) {
        tickets = tickets.where((t) => t['priority'] == priorityFilter).toList();
      }

      // Sort by updatedAt descending
      tickets.sort((a, b) {
        final aTime = a['updatedAt'] ?? a['createdAt'] ?? 0;
        final bTime = b['updatedAt'] ?? b['createdAt'] ?? 0;
        return bTime.compareTo(aTime);
      });

      return tickets;
    } catch (e) {
      return [];
    }
  }

  /// Get tickets for a specific user
  Future<List<Map<String, dynamic>>> getUserTickets(String userId) async {
    try {
      final snapshot = await _db.child('support_tickets')
          .orderByChild('userId')
          .equalTo(userId)
          .get();
      
      if (!snapshot.exists || snapshot.value == null) {
        return [];
      }

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final tickets = data.entries.map((e) {
        final ticket = Map<String, dynamic>.from(e.value as Map);
        ticket['id'] = e.key;
        return ticket;
      }).toList();

      // Sort by createdAt descending
      tickets.sort((a, b) {
        final aTime = a['createdAt'] ?? 0;
        final bTime = b['createdAt'] ?? 0;
        return bTime.compareTo(aTime);
      });

      return tickets;
    } catch (e) {
      return [];
    }
  }

  /// Get a single ticket with all messages
  Future<Map<String, dynamic>?> getTicket(String ticketId) async {
    try {
      final snapshot = await _db.child('support_tickets/$ticketId').get();
      
      if (!snapshot.exists || snapshot.value == null) {
        return null;
      }

      final ticket = Map<String, dynamic>.from(snapshot.value as Map);
      ticket['id'] = ticketId;

      // Convert messages to list and sort
      if (ticket['messages'] != null) {
        final messagesMap = Map<String, dynamic>.from(ticket['messages'] as Map);
        final messagesList = messagesMap.entries.map((e) {
          final msg = Map<String, dynamic>.from(e.value as Map);
          msg['id'] = e.key;
          return msg;
        }).toList();
        
        messagesList.sort((a, b) {
          final aTime = a['timestamp'] ?? 0;
          final bTime = b['timestamp'] ?? 0;
          return aTime.compareTo(bTime);
        });
        
        ticket['messagesList'] = messagesList;
      }

      return ticket;
    } catch (e) {
      return null;
    }
  }

  /// Get ticket counts by status (for dashboard)
  Future<Map<String, int>> getTicketCounts() async {
    try {
      final snapshot = await _db.child('support_tickets').get();
      
      if (!snapshot.exists || snapshot.value == null) {
        return {'open': 0, 'in_progress': 0, 'resolved': 0, 'closed': 0, 'total': 0};
      }

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      int open = 0, inProgress = 0, resolved = 0, closed = 0;

      for (final entry in data.entries) {
        final ticket = Map<String, dynamic>.from(entry.value as Map);
        final status = ticket['status'] ?? 'open';
        
        switch (status) {
          case 'open':
            open++;
            break;
          case 'in_progress':
            inProgress++;
            break;
          case 'resolved':
            resolved++;
            break;
          case 'closed':
            closed++;
            break;
        }
      }

      return {
        'open': open,
        'in_progress': inProgress,
        'resolved': resolved,
        'closed': closed,
        'total': data.length,
      };
    } catch (e) {
      return {'open': 0, 'in_progress': 0, 'resolved': 0, 'closed': 0, 'total': 0};
    }
  }

  /// Listen to tickets stream (for real-time updates)
  Stream<List<Map<String, dynamic>>> ticketsStream() {
    return _db.child('support_tickets')
        .orderByChild('updatedAt')
        .onValue
        .map((event) {
      if (event.snapshot.value == null) return [];
      
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      final tickets = data.entries.map((e) {
        final ticket = Map<String, dynamic>.from(e.value as Map);
        ticket['id'] = e.key;
        return ticket;
      }).toList();

      tickets.sort((a, b) {
        final aTime = a['updatedAt'] ?? a['createdAt'] ?? 0;
        final bTime = b['updatedAt'] ?? b['createdAt'] ?? 0;
        return bTime.compareTo(aTime);
      });

      return tickets;
    });
  }
}
