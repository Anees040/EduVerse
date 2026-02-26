import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:eduverse/utils/app_theme.dart';
import 'package:eduverse/services/support_service.dart';

/// Admin Support Screen - Gmail-like support ticket management
class AdminSupportScreen extends StatefulWidget {
  const AdminSupportScreen({super.key});

  @override
  State<AdminSupportScreen> createState() => _AdminSupportScreenState();
}

class _AdminSupportScreenState extends State<AdminSupportScreen>
    with SingleTickerProviderStateMixin {
  final SupportService _supportService = SupportService();
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;

  final List<_TabInfo> _tabs = const [
    _TabInfo('All', null, Icons.all_inbox_rounded),
    _TabInfo('Open', 'open', Icons.mark_email_unread_rounded),
    _TabInfo('In Progress', 'in_progress', Icons.pending_rounded),
    _TabInfo('Resolved', 'resolved', Icons.check_circle_outline_rounded),
    _TabInfo('Closed', 'closed', Icons.archive_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Support Center',
                      style: TextStyle(
                        color: AppTheme.getTextPrimary(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage user support tickets',
                      style: TextStyle(
                        color: AppTheme.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              // Live indicator
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: Colors.green),
                    SizedBox(width: 6),
                    Text(
                      'Live',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stats row - real-time
          _buildStatsStream(isDark),
          const SizedBox(height: 12),

          // Tabs
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
              ),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorSize: TabBarIndicatorSize.label,
              indicatorColor:
                  isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
              labelColor:
                  isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
              unselectedLabelColor: AppTheme.getTextSecondary(context),
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              dividerColor: Colors.transparent,
              tabs: _tabs
                  .map((t) => Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(t.icon, size: 16),
                            const SizedBox(width: 6),
                            Text(t.label),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),

          // Search
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by subject, user, or email...',
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: isDark ? AppTheme.darkCard : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),

          // Ticket list - real-time with StreamBuilder
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _supportService.ticketsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allTickets = snapshot.data ?? [];

                return AnimatedBuilder(
                  animation: _tabController,
                  builder: (context, _) {
                    final tabFilter =
                        _tabs[_tabController.index].statusFilter;
                    return _buildTicketList(allTickets, tabFilter, isDark);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Stats stream ----------
  Widget _buildStatsStream(bool isDark) {
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance
          .ref('support_tickets')
          .onValue,
      builder: (context, snapshot) {
        int open = 0, inProgress = 0, resolved = 0, closed = 0, total = 0;

        if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          final data = Map<String, dynamic>.from(
            snapshot.data!.snapshot.value as Map,
          );
          total = data.length;
          for (final entry in data.values) {
            if (entry is! Map) continue;
            final status = (entry['status'] ?? 'open').toString();
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
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _statChip('Open', open, Colors.orange, isDark),
              const SizedBox(width: 8),
              _statChip('In Progress', inProgress, Colors.blue, isDark),
              const SizedBox(width: 8),
              _statChip('Resolved', resolved, Colors.green, isDark),
              const SizedBox(width: 8),
              _statChip('Closed', closed, Colors.grey, isDark),
              const SizedBox(width: 8),
              _statChip(
                'Total',
                total,
                isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
                isDark,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statChip(String label, int count, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.getTextSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Ticket list ----------
  Widget _buildTicketList(
    List<Map<String, dynamic>> allTickets,
    String? statusFilter,
    bool isDark,
  ) {
    final searchQuery = _searchController.text.toLowerCase();

    var filtered = allTickets;

    // Tab filter
    if (statusFilter != null) {
      filtered =
          filtered.where((t) => t['status'] == statusFilter).toList();
    }

    // Search filter
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((t) {
        final subject = (t['subject'] ?? '').toString().toLowerCase();
        final userName = (t['userName'] ?? '').toString().toLowerCase();
        final email = (t['userEmail'] ?? '').toString().toLowerCase();
        return subject.contains(searchQuery) ||
            userName.contains(searchQuery) ||
            email.contains(searchQuery);
      }).toList();
    }

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.support_agent_rounded,
              size: 56,
              color: AppTheme.getTextSecondary(context).withOpacity(0.3),
            ),
            const SizedBox(height: 12),
            Text(
              statusFilter == null
                  ? 'No tickets yet'
                  : 'No ${_formatLabel(statusFilter)} tickets',
              style: TextStyle(
                fontSize: 15,
                color: AppTheme.getTextSecondary(context),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        return _TicketListTile(
          ticket: filtered[index],
          isDark: isDark,
          onTap: () => _openTicket(filtered[index]),
        );
      },
    );
  }

  void _openTicket(Map<String, dynamic> ticket) {
    final ticketId = ticket['id'] ?? ticket['ticketId'];
    if (ticketId == null) return;

    // Mark as read immediately
    if (ticket['adminRead'] != true) {
      _supportService.markAdminRead(ticketId.toString());
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _TicketDetailScreen(ticketId: ticketId.toString()),
      ),
    );
  }

  String _formatLabel(String value) {
    return value
        .split('_')
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}

// ---------- Tab info ----------
class _TabInfo {
  final String label;
  final String? statusFilter;
  final IconData icon;
  const _TabInfo(this.label, this.statusFilter, this.icon);
}

// ---------- Ticket list tile (Gmail-like) ----------
class _TicketListTile extends StatelessWidget {
  final Map<String, dynamic> ticket;
  final bool isDark;
  final VoidCallback onTap;

  const _TicketListTile({
    required this.ticket,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = (ticket['status'] ?? 'open').toString();
    final priority = (ticket['priority'] ?? 'medium').toString();
    final isUnread = ticket['adminRead'] != true && status == 'open';
    final updatedAt = ticket['updatedAt'] as int?;
    final messageCount = _messageCount();

    final statusColor = _statusColor(status);
    final priorityIcon = _priorityIcon(priority);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isUnread
            ? (isDark
                ? AppTheme.darkAccent.withOpacity(0.06)
                : AppTheme.primaryColor.withOpacity(0.04))
            : (isDark ? AppTheme.darkCard : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnread
              ? (isDark
                  ? AppTheme.darkAccent.withOpacity(0.2)
                  : AppTheme.primaryColor.withOpacity(0.15))
              : (isDark ? AppTheme.darkBorder : Colors.grey.shade200),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Unread dot + priority icon
              SizedBox(
                width: 36,
                child: Column(
                  children: [
                    if (isUnread)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.darkAccent
                              : AppTheme.primaryColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    Icon(
                      priorityIcon,
                      size: 20,
                      color: _priorityColor(priority),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Subject + time
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            ticket['subject'] ?? 'No subject',
                            style: TextStyle(
                              color: AppTheme.getTextPrimary(context),
                              fontWeight: isUnread
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          updatedAt != null ? _timeAgo(updatedAt) : '',
                          style: TextStyle(
                            fontSize: 11,
                            color: isUnread
                                ? (isDark
                                    ? AppTheme.darkAccent
                                    : AppTheme.primaryColor)
                                : AppTheme.getTextSecondary(context),
                            fontWeight: isUnread
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // User + status + message count
                    Row(
                      children: [
                        // User avatar
                        CircleAvatar(
                          radius: 10,
                          backgroundColor: isDark
                              ? AppTheme.darkAccent.withOpacity(0.2)
                              : AppTheme.primaryColor.withOpacity(0.1),
                          child: Text(
                            (ticket['userName'] ?? 'U')[0].toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppTheme.darkAccent
                                  : AppTheme.primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            ticket['userName'] ?? 'Unknown',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.getTextSecondary(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Status chip
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _formatLabel(status),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (messageCount > 1) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.getTextSecondary(context)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$messageCount',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.getTextSecondary(context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Preview of last message
                    Text(
                      _lastMessage(),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.getTextSecondary(context),
                        fontWeight:
                            isUnread ? FontWeight.w500 : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _messageCount() {
    if (ticket['messages'] != null && ticket['messages'] is Map) {
      return (ticket['messages'] as Map).length;
    }
    return 0;
  }

  String _lastMessage() {
    if (ticket['messages'] != null && ticket['messages'] is Map) {
      final msgs = Map<String, dynamic>.from(ticket['messages'] as Map);
      if (msgs.isEmpty) return '';

      // Sort by timestamp, get last
      final sorted = msgs.entries.toList();
      sorted.sort((a, b) {
        final at = (a.value is Map ? (a.value['timestamp'] ?? 0) : 0) as num;
        final bt = (b.value is Map ? (b.value['timestamp'] ?? 0) : 0) as num;
        return bt.compareTo(at);
      });

      final last = sorted.first.value;
      if (last is Map) {
        final sender = last['senderRole'] == 'admin' ? 'You' : last['senderName'] ?? '';
        final msg = last['message'] ?? '';
        return '$sender: $msg';
      }
    }
    return '';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'open':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  IconData _priorityIcon(String priority) {
    switch (priority) {
      case 'urgent':
        return Icons.priority_high_rounded;
      case 'high':
        return Icons.arrow_upward_rounded;
      case 'medium':
        return Icons.remove_rounded;
      case 'low':
        return Icons.arrow_downward_rounded;
      default:
        return Icons.remove_rounded;
    }
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'urgent':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.blue;
      case 'low':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  String _formatLabel(String value) {
    return value
        .split('_')
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  String _timeAgo(int timestamp) {
    final now = DateTime.now();
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateFormat('MMM d').format(date);
  }
}

// ============================================================
// Ticket Detail Screen - Gmail-like thread view
// ============================================================
class _TicketDetailScreen extends StatefulWidget {
  final String ticketId;
  const _TicketDetailScreen({required this.ticketId});

  @override
  State<_TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<_TicketDetailScreen> {
  final SupportService _supportService = SupportService();
  final TextEditingController _replyController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  String _adminName = 'Admin';
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadAdminName();
  }

  Future<void> _loadAdminName() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final snap = await _db.child('admin/$uid/name').get();
      if (snap.exists && snap.value != null) {
        _adminName = snap.value.toString();
      }
    } catch (_) {}
  }

  Future<void> _sendReply(String currentStatus) async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    // Prevent replies on closed tickets
    if (currentStatus == 'closed') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This ticket is closed')),
      );
      return;
    }

    setState(() => _isSending = true);

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final success = await _supportService.adminReply(
      ticketId: widget.ticketId,
      adminId: uid,
      adminName: _adminName,
      message: text,
      markInProgress: currentStatus == 'open',
    );

    if (mounted) {
      setState(() => _isSending = false);
      if (success) {
        _replyController.clear();
        // Auto-scroll to bottom after short delay
        Future.delayed(const Duration(milliseconds: 300), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send reply')),
        );
      }
    }
  }

  Future<void> _updateStatus(String status) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final success = await _supportService.updateTicketStatus(
      ticketId: widget.ticketId,
      status: status,
      adminId: uid,
    );
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ticket marked as ${_formatLabel(status)}')),
      );
    }
  }

  String _formatLabel(String value) {
    return value
        .split('_')
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        foregroundColor: AppTheme.getTextPrimary(context),
        elevation: 0,
        title: const Text('Ticket Details', style: TextStyle(fontSize: 16)),
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: _db.child('support_tickets/${widget.ticketId}').onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData ||
              snapshot.data!.snapshot.value == null) {
            return const Center(child: Text('Ticket not found'));
          }

          final raw = snapshot.data!.snapshot.value;
          if (raw is! Map) {
            return const Center(child: Text('Invalid ticket data'));
          }

          final ticket = <String, dynamic>{};
          (raw).forEach((k, v) => ticket[k.toString()] = v);
          ticket['id'] = widget.ticketId;

          // Parse messages
          final messages = <Map<String, dynamic>>[];
          if (ticket['messages'] is Map) {
            (ticket['messages'] as Map).forEach((k, v) {
              if (v is Map) {
                final m = <String, dynamic>{};
                v.forEach((mk, mv) => m[mk.toString()] = mv);
                m['id'] = k.toString();
                messages.add(m);
              }
            });
            messages.sort((a, b) {
              final at = (a['timestamp'] as num?)?.toInt() ?? 0;
              final bt = (b['timestamp'] as num?)?.toInt() ?? 0;
              return at.compareTo(bt);
            });
          }

          final status = (ticket['status'] ?? 'open').toString();
          final isClosed = status == 'closed';
          final isResolved = status == 'resolved';

          return Column(
            children: [
              // Header
              _buildHeader(ticket, status, isDark),

              // Status banner
              if (isClosed)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  color: Colors.grey.withOpacity(0.1),
                  child: Row(
                    children: [
                      const Icon(Icons.lock, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        'This ticket is closed. No further messages allowed.',
                        style: TextStyle(
                          color: AppTheme.getTextSecondary(context),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              if (isResolved)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  color: Colors.green.withOpacity(0.08),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        size: 16,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This ticket has been resolved.',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      // Allow reopening
                      TextButton.icon(
                        onPressed: () => _updateStatus('open'),
                        icon: const Icon(Icons.refresh, size: 14),
                        label: const Text(
                          'Reopen',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.green.shade700,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ),

              // Messages
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    return _MessageBubble(
                      message: messages[i],
                      isDark: isDark,
                    );
                  },
                ),
              ),

              // Reply input (hidden when closed)
              if (!isClosed) _buildReplyBar(status, isDark),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(
    Map<String, dynamic> ticket,
    String status,
    bool isDark,
  ) {
    final priority = (ticket['priority'] ?? 'medium').toString();
    final category = (ticket['category'] ?? 'other').toString();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subject
          Text(
            ticket['subject'] ?? 'No subject',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.getTextPrimary(context),
            ),
          ),
          const SizedBox(height: 12),

          // Meta row
          Row(
            children: [
              // User
              CircleAvatar(
                radius: 16,
                backgroundColor: isDark
                    ? AppTheme.darkAccent.withOpacity(0.2)
                    : AppTheme.primaryColor.withOpacity(0.1),
                child: Text(
                  (ticket['userName'] ?? 'U')[0].toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color:
                        isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket['userName'] ?? 'Unknown',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppTheme.getTextPrimary(context),
                      ),
                    ),
                    Text(
                      '${ticket['userEmail'] ?? ''} ${String.fromCharCode(0x00B7)} ${_formatLabel(ticket['userRole'] ?? 'user')}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              // Status chip
              _buildChip(
                _formatLabel(status),
                _statusColor(status),
              ),
              const SizedBox(width: 6),
              _buildChip(
                priority.toUpperCase(),
                _priorityColor(priority),
              ),
              const SizedBox(width: 6),
              _buildChip(
                _formatLabel(category),
                AppTheme.getTextSecondary(context),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Action buttons
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (status != 'in_progress' && status != 'closed')
                  _actionBtn(
                    'In Progress',
                    Icons.pending_rounded,
                    Colors.blue,
                    () => _updateStatus('in_progress'),
                  ),
                if (status != 'resolved' && status != 'closed')
                  _actionBtn(
                    'Resolve',
                    Icons.check_circle_outline,
                    Colors.green,
                    () => _updateStatus('resolved'),
                  ),
                if (status != 'closed')
                  _actionBtn(
                    'Close',
                    Icons.archive_rounded,
                    Colors.grey,
                    () => _updateStatus('closed'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _actionBtn(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 14),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withOpacity(0.3)),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _buildReplyBar(String currentStatus, bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _replyController,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Type your reply...',
                filled: true,
                fillColor:
                    isDark ? AppTheme.darkElevated : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              onTap: _isSending ? null : () => _sendReply(currentStatus),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                child: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'open':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _priorityColor(String p) {
    switch (p) {
      case 'urgent':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  void dispose() {
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

// ---------- Message Bubble ----------
class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isDark;

  const _MessageBubble({required this.message, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isAdmin = message['senderRole'] == 'admin';
    final timestamp = message['timestamp'] as int?;

    return Align(
      alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment:
              isAdmin ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Sender + time
            Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 4, right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isAdmin)
                    const Icon(
                      Icons.admin_panel_settings,
                      size: 12,
                      color: Colors.blue,
                    ),
                  if (isAdmin) const SizedBox(width: 4),
                  Text(
                    isAdmin
                        ? (message['senderName'] ?? 'Admin')
                        : (message['senderName'] ?? 'User'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isAdmin
                          ? Colors.blue
                          : AppTheme.getTextSecondary(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    timestamp != null
                        ? DateFormat('MMM d, h:mm a').format(
                            DateTime.fromMillisecondsSinceEpoch(timestamp),
                          )
                        : '',
                    style: TextStyle(
                      fontSize: 10,
                      color:
                          AppTheme.getTextSecondary(context).withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),

            // Bubble
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isAdmin
                    ? (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                    : (isDark ? AppTheme.darkCard : Colors.grey.shade100),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isAdmin ? 16 : 4),
                  bottomRight: Radius.circular(isAdmin ? 4 : 16),
                ),
                border: isAdmin
                    ? null
                    : Border.all(
                        color: isDark
                            ? AppTheme.darkBorder
                            : Colors.grey.shade200,
                      ),
              ),
              child: Text(
                message['message'] ?? '',
                style: TextStyle(
                  color: isAdmin
                      ? Colors.white
                      : AppTheme.getTextPrimary(context),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
