import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:eduverse/utils/app_theme.dart';
import 'package:eduverse/services/support_service.dart';

/// Admin Support Screen - Handle user support tickets
class AdminSupportScreen extends StatefulWidget {
  const AdminSupportScreen({super.key});

  @override
  State<AdminSupportScreen> createState() => _AdminSupportScreenState();
}

class _AdminSupportScreenState extends State<AdminSupportScreen> {
  final SupportService _supportService = SupportService();
  final TextEditingController _searchController = TextEditingController();
  
  String _statusFilter = 'all';
  String _categoryFilter = 'all';
  String _priorityFilter = 'all';
  List<Map<String, dynamic>> _tickets = [];
  Map<String, int> _ticketCounts = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    setState(() => _isLoading = true);
    
    try {
      final tickets = await _supportService.getAllTickets(
        statusFilter: _statusFilter == 'all' ? null : _statusFilter,
        categoryFilter: _categoryFilter == 'all' ? null : _categoryFilter,
        priorityFilter: _priorityFilter == 'all' ? null : _priorityFilter,
      );
      final counts = await _supportService.getTicketCounts();
      
      if (mounted) {
        setState(() {
          _tickets = tickets;
          _ticketCounts = counts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with refresh button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
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
              IconButton(
                icon: Icon(
                  Icons.refresh,
                  color: AppTheme.getTextPrimary(context),
                ),
                onPressed: _loadTickets,
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Stats Row
          _buildStatsRow(isDark),
          
          // Filters
          _buildFilters(isDark),
          
          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search tickets...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: isDark ? AppTheme.darkCard : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) => setState(() {}),
            ),
          ),
          const SizedBox(height: 16),
          
          // Tickets List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildTicketsList(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(bool isDark) {
    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          _buildStatCard(
            'Open',
            _ticketCounts['open'] ?? 0,
            Colors.orange,
            isDark,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            'In Progress',
            _ticketCounts['in_progress'] ?? 0,
            Colors.blue,
            isDark,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            'Resolved',
            _ticketCounts['resolved'] ?? 0,
            Colors.green,
            isDark,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            'Total',
            _ticketCounts['total'] ?? 0,
            isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, int count, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.3),
          ),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.getTextSecondary(context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildFilterChip('Status', _statusFilter, ['all', 'open', 'in_progress', 'resolved', 'closed'], (v) {
            setState(() => _statusFilter = v);
            _loadTickets();
          }, isDark),
          const SizedBox(width: 8),
          _buildFilterChip('Category', _categoryFilter, ['all', 'account', 'technical', 'billing', 'other'], (v) {
            setState(() => _categoryFilter = v);
            _loadTickets();
          }, isDark),
          const SizedBox(width: 8),
          _buildFilterChip('Priority', _priorityFilter, ['all', 'low', 'medium', 'high', 'urgent'], (v) {
            setState(() => _priorityFilter = v);
            _loadTickets();
          }, isDark),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, List<String> options, Function(String) onChanged, bool isDark) {
    return PopupMenuButton<String>(
      onSelected: onChanged,
      itemBuilder: (context) => options.map((o) => PopupMenuItem(
        value: o,
        child: Text(o == 'all' ? 'All ${label}s' : _formatFilterLabel(o)),
      )).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: value != 'all' 
              ? (isDark ? AppTheme.darkAccent : AppTheme.primaryColor).withOpacity(0.1)
              : isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: value != 'all'
                ? (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                : isDark ? AppTheme.darkBorder : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value == 'all' ? label : _formatFilterLabel(value),
              style: TextStyle(
                color: value != 'all'
                    ? (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
                    : AppTheme.getTextPrimary(context),
                fontWeight: value != 'all' ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              color: AppTheme.getTextSecondary(context),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  String _formatFilterLabel(String value) {
    return value.split('_').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
  }

  Widget _buildTicketsList(bool isDark) {
    final searchQuery = _searchController.text.toLowerCase();
    final filteredTickets = _tickets.where((t) {
      if (searchQuery.isEmpty) return true;
      final subject = (t['subject'] ?? '').toString().toLowerCase();
      final userName = (t['userName'] ?? '').toString().toLowerCase();
      final userEmail = (t['userEmail'] ?? '').toString().toLowerCase();
      return subject.contains(searchQuery) || 
             userName.contains(searchQuery) || 
             userEmail.contains(searchQuery);
    }).toList();

    if (filteredTickets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.support_agent,
              size: 64,
              color: AppTheme.getTextSecondary(context).withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No tickets found',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.getTextSecondary(context),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filteredTickets.length,
      itemBuilder: (context, index) {
        final ticket = filteredTickets[index];
        return _buildTicketCard(ticket, isDark);
      },
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> ticket, bool isDark) {
    final status = ticket['status'] ?? 'open';
    final priority = ticket['priority'] ?? 'medium';
    final createdAt = ticket['createdAt'] as int?;
    final updatedAt = ticket['updatedAt'] as int?;

    Color statusColor;
    switch (status) {
      case 'open':
        statusColor = Colors.orange;
        break;
      case 'in_progress':
        statusColor = Colors.blue;
        break;
      case 'resolved':
        statusColor = Colors.green;
        break;
      case 'closed':
        statusColor = Colors.grey;
        break;
      default:
        statusColor = Colors.orange;
    }

    Color priorityColor;
    switch (priority) {
      case 'low':
        priorityColor = Colors.grey;
        break;
      case 'medium':
        priorityColor = Colors.blue;
        break;
      case 'high':
        priorityColor = Colors.orange;
        break;
      case 'urgent':
        priorityColor = Colors.red;
        break;
      default:
        priorityColor = Colors.blue;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? AppTheme.darkCard : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
        ),
      ),
      child: InkWell(
        onTap: () => _openTicketDetail(ticket),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Priority Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: priorityColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      priority.toUpperCase(),
                      style: TextStyle(
                        color: priorityColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _formatFilterLabel(status),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Category
                  Text(
                    _formatFilterLabel(ticket['category'] ?? 'other'),
                    style: TextStyle(
                      color: AppTheme.getTextSecondary(context),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Subject
              Text(
                ticket['subject'] ?? 'No subject',
                style: TextStyle(
                  color: AppTheme.getTextPrimary(context),
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              
              // User info
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
                    child: Text(
                      (ticket['userName'] ?? 'U')[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ticket['userName'] ?? 'Unknown User',
                          style: TextStyle(
                            color: AppTheme.getTextPrimary(context),
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          ticket['userEmail'] ?? '',
                          style: TextStyle(
                            color: AppTheme.getTextSecondary(context),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Time
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        createdAt != null
                            ? DateFormat('MMM d, y').format(
                                DateTime.fromMillisecondsSinceEpoch(createdAt))
                            : '',
                        style: TextStyle(
                          color: AppTheme.getTextSecondary(context),
                          fontSize: 11,
                        ),
                      ),
                      if (updatedAt != null && updatedAt != createdAt)
                        Text(
                          'Updated ${_getTimeAgo(updatedAt)}',
                          style: TextStyle(
                            color: AppTheme.getTextSecondary(context),
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getTimeAgo(int timestamp) {
    final now = DateTime.now();
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final diff = now.difference(date);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(date);
    }
  }

  void _openTicketDetail(Map<String, dynamic> ticket) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _TicketDetailScreen(ticketId: ticket['id'] ?? ticket['ticketId']),
      ),
    ).then((_) => _loadTickets());
  }
}

/// Ticket Detail Screen
class _TicketDetailScreen extends StatefulWidget {
  final String ticketId;

  const _TicketDetailScreen({required this.ticketId});

  @override
  State<_TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<_TicketDetailScreen> {
  final SupportService _supportService = SupportService();
  final TextEditingController _replyController = TextEditingController();
  
  Map<String, dynamic>? _ticket;
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadTicket();
  }

  Future<void> _loadTicket() async {
    setState(() => _isLoading = true);
    
    final ticket = await _supportService.getTicket(widget.ticketId);
    
    if (mounted) {
      setState(() {
        _ticket = ticket;
        _isLoading = false;
      });
    }
  }

  Future<void> _sendReply() async {
    if (_replyController.text.trim().isEmpty) return;

    setState(() => _isSending = true);

    final currentUser = FirebaseAuth.instance.currentUser;
    final success = await _supportService.adminReply(
      ticketId: widget.ticketId,
      adminId: currentUser?.uid ?? '',
      adminName: 'Admin',
      message: _replyController.text.trim(),
    );

    if (mounted) {
      setState(() => _isSending = false);
      
      if (success) {
        _replyController.clear();
        _loadTicket();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send reply')),
        );
      }
    }
  }

  Future<void> _updateStatus(String status) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final success = await _supportService.updateTicketStatus(
      ticketId: widget.ticketId,
      status: status,
      adminId: currentUser?.uid,
    );

    if (success) {
      _loadTicket();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status updated to ${_formatLabel(status)}')),
        );
      }
    }
  }

  String _formatLabel(String value) {
    return value.split('_').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        title: Text(_ticket?['subject'] ?? 'Ticket Details'),
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        foregroundColor: AppTheme.getTextPrimary(context),
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: _updateStatus,
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'in_progress', child: Text('Mark In Progress')),
              const PopupMenuItem(value: 'resolved', child: Text('Mark Resolved')),
              const PopupMenuItem(value: 'closed', child: Text('Close Ticket')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _ticket == null
          ? const Center(child: Text('Ticket not found'))
          : Column(
              children: [
                // Ticket Info Header
                _buildTicketHeader(isDark),
                
                // Messages
                Expanded(
                  child: _buildMessagesList(isDark),
                ),
                
                // Reply Input
                _buildReplyInput(isDark),
              ],
            ),
    );
  }

  Widget _buildTicketHeader(bool isDark) {
    final status = _ticket!['status'] ?? 'open';
    final priority = _ticket!['priority'] ?? 'medium';

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
          Row(
            children: [
              _buildStatusChip(status),
              const SizedBox(width: 8),
              _buildPriorityChip(priority),
              const Spacer(),
              Text(
                _formatLabel(_ticket!['category'] ?? 'other'),
                style: TextStyle(
                  color: AppTheme.getTextSecondary(context),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
                child: Text(
                  (_ticket!['userName'] ?? 'U')[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _ticket!['userName'] ?? 'Unknown',
                      style: TextStyle(
                        color: AppTheme.getTextPrimary(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _ticket!['userEmail'] ?? '',
                      style: TextStyle(
                        color: AppTheme.getTextSecondary(context),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (isDark ? AppTheme.darkAccent : AppTheme.primaryColor).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _formatLabel(_ticket!['userRole'] ?? 'user'),
                  style: TextStyle(
                    color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'open':
        color = Colors.orange;
        break;
      case 'in_progress':
        color = Colors.blue;
        break;
      case 'resolved':
        color = Colors.green;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        _formatLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildPriorityChip(String priority) {
    Color color;
    switch (priority) {
      case 'urgent':
        color = Colors.red;
        break;
      case 'high':
        color = Colors.orange;
        break;
      case 'medium':
        color = Colors.blue;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        priority.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildMessagesList(bool isDark) {
    final messages = _ticket!['messagesList'] as List<Map<String, dynamic>>? ?? [];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isAdmin = message['senderRole'] == 'admin';
        
        return _buildMessageBubble(message, isAdmin, isDark);
      },
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isAdmin, bool isDark) {
    final timestamp = message['timestamp'] as int?;

    return Align(
      alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isAdmin
              ? (isDark ? AppTheme.darkAccent : AppTheme.primaryColor)
              : (isDark ? AppTheme.darkCard : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isAdmin ? const Radius.circular(4) : null,
            bottomLeft: !isAdmin ? const Radius.circular(4) : null,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message['senderName'] ?? 'Unknown',
                  style: TextStyle(
                    color: isAdmin
                        ? Colors.white.withOpacity(0.8)
                        : AppTheme.getTextSecondary(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  timestamp != null
                      ? DateFormat('MMM d, h:mm a').format(
                          DateTime.fromMillisecondsSinceEpoch(timestamp))
                      : '',
                  style: TextStyle(
                    color: isAdmin
                        ? Colors.white.withOpacity(0.6)
                        : AppTheme.getTextSecondary(context).withOpacity(0.7),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              message['message'] ?? '',
              style: TextStyle(
                color: isAdmin ? Colors.white : AppTheme.getTextPrimary(context),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyInput(bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _replyController,
              maxLines: null,
              decoration: InputDecoration(
                hintText: 'Type your reply...',
                filled: true,
                fillColor: isDark ? AppTheme.darkElevated : Colors.grey.shade100,
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
          IconButton(
            onPressed: _isSending ? null : _sendReply,
            icon: _isSending
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.send_rounded,
                    color: isDark ? AppTheme.darkAccent : AppTheme.primaryColor,
                  ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }
}
