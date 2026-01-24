import 'package:flutter/foundation.dart';
import '../services/admin_service.dart';

/// Admin State for managing dashboard data
class AdminState {
  final bool isLoading;
  final bool isAdmin;
  final String? error;
  final Map<String, dynamic>? kpiStats;
  final List<Map<String, dynamic>> users;
  final List<Map<String, dynamic>> reportedContent;
  final List<Map<String, dynamic>> userGrowthData;
  final List<Map<String, dynamic>> revenueData;
  final String? lastUserKey;
  final bool hasMoreUsers;
  final String userSearchQuery;
  final String? userRoleFilter;

  AdminState({
    this.isLoading = false,
    this.isAdmin = false,
    this.error,
    this.kpiStats,
    this.users = const [],
    this.reportedContent = const [],
    this.userGrowthData = const [],
    this.revenueData = const [],
    this.lastUserKey,
    this.hasMoreUsers = false,
    this.userSearchQuery = '',
    this.userRoleFilter,
  });

  AdminState copyWith({
    bool? isLoading,
    bool? isAdmin,
    String? error,
    Map<String, dynamic>? kpiStats,
    List<Map<String, dynamic>>? users,
    List<Map<String, dynamic>>? reportedContent,
    List<Map<String, dynamic>>? userGrowthData,
    List<Map<String, dynamic>>? revenueData,
    String? lastUserKey,
    bool? hasMoreUsers,
    String? userSearchQuery,
    String? userRoleFilter,
    bool clearRoleFilter = false,
  }) {
    return AdminState(
      isLoading: isLoading ?? this.isLoading,
      isAdmin: isAdmin ?? this.isAdmin,
      error: error,
      kpiStats: kpiStats ?? this.kpiStats,
      users: users ?? this.users,
      reportedContent: reportedContent ?? this.reportedContent,
      userGrowthData: userGrowthData ?? this.userGrowthData,
      revenueData: revenueData ?? this.revenueData,
      lastUserKey: lastUserKey ?? this.lastUserKey,
      hasMoreUsers: hasMoreUsers ?? this.hasMoreUsers,
      userSearchQuery: userSearchQuery ?? this.userSearchQuery,
      userRoleFilter: clearRoleFilter
          ? null
          : (userRoleFilter ?? this.userRoleFilter),
    );
  }
}

/// Admin Provider - Manages admin module state using ChangeNotifier
class AdminProvider extends ChangeNotifier {
  final AdminService _adminService = AdminService();
  AdminState _state = AdminState();

  AdminState get state => _state;

  /// Check if current user is admin
  Future<bool> checkAdminAccess() async {
    _state = _state.copyWith(isLoading: true, error: null);
    notifyListeners();

    try {
      final isAdmin = await _adminService.isAdmin();
      _state = _state.copyWith(isLoading: false, isAdmin: isAdmin);
      notifyListeners();
      return isAdmin;
    } catch (e) {
      _state = _state.copyWith(
        isLoading: false,
        isAdmin: false,
        error: e.toString(),
      );
      notifyListeners();
      return false;
    }
  }

  /// Load KPI statistics
  Future<void> loadKPIStats() async {
    try {
      final stats = await _adminService.getKPIStats();
      _state = _state.copyWith(kpiStats: stats);
      notifyListeners();
    } catch (e) {
      _state = _state.copyWith(error: e.toString());
      notifyListeners();
    }
  }

  /// Load users with pagination
  Future<void> loadUsers({bool refresh = false}) async {
    if (_state.isLoading) return;

    _state = _state.copyWith(isLoading: true, error: null);
    notifyListeners();

    try {
      final result = await _adminService.getUsers(
        searchQuery: _state.userSearchQuery.isEmpty
            ? null
            : _state.userSearchQuery,
        role: _state.userRoleFilter,
        startAfterKey: refresh ? null : _state.lastUserKey,
      );

      final newUsers = result['users'] as List<Map<String, dynamic>>;

      _state = _state.copyWith(
        isLoading: false,
        users: refresh ? newUsers : [..._state.users, ...newUsers],
        lastUserKey: result['lastKey'] as String?,
        hasMoreUsers: result['hasMore'] as bool,
      );
      notifyListeners();
    } catch (e) {
      _state = _state.copyWith(isLoading: false, error: e.toString());
      notifyListeners();
    }
  }

  /// Update search query and refresh users
  void setSearchQuery(String query) {
    _state = _state.copyWith(
      userSearchQuery: query,
      users: [],
      lastUserKey: null,
      hasMoreUsers: false,
    );
    notifyListeners();
    loadUsers(refresh: true);
  }

  /// Update role filter and refresh users
  void setRoleFilter(String? role) {
    _state = _state.copyWith(
      userRoleFilter: role,
      clearRoleFilter: role == null,
      users: [],
      lastUserKey: null,
      hasMoreUsers: false,
    );
    notifyListeners();
    loadUsers(refresh: true);
  }

  /// Suspend/Unsuspend a user (optimistic update)
  Future<void> toggleUserSuspension(
    String uid,
    String role,
    bool suspend,
  ) async {
    // Optimistic update
    final updatedUsers = _state.users.map((user) {
      if (user['uid'] == uid) {
        return {...user, 'isSuspended': suspend};
      }
      return user;
    }).toList();

    _state = _state.copyWith(users: updatedUsers);
    notifyListeners();

    try {
      await _adminService.toggleUserSuspension(uid, role, suspend);
      // Also refresh KPI stats as suspension affects counts
      loadKPIStats();
    } catch (e) {
      // Revert optimistic update on failure
      final revertedUsers = _state.users.map((user) {
        if (user['uid'] == uid) {
          return {...user, 'isSuspended': !suspend};
        }
        return user;
      }).toList();

      _state = _state.copyWith(users: revertedUsers, error: e.toString());
      notifyListeners();
    }
  }

  /// Suspend user with reason and email notification
  Future<void> suspendUserWithReason({
    required String uid,
    required String role,
    required String reason,
    required bool isPermanent,
    required String userEmail,
    required String userName,
  }) async {
    // Optimistic update
    final updatedUsers = _state.users.map((user) {
      if (user['uid'] == uid) {
        return {
          ...user,
          'isSuspended': true,
          'suspensionReason': reason,
          'suspensionType': isPermanent ? 'permanent' : 'temporary',
        };
      }
      return user;
    }).toList();

    _state = _state.copyWith(users: updatedUsers);
    notifyListeners();

    try {
      await _adminService.suspendUserWithDetails(
        uid: uid,
        role: role,
        reason: reason,
        isPermanent: isPermanent,
        userEmail: userEmail,
        userName: userName,
      );
      // Also refresh KPI stats as suspension affects counts
      loadKPIStats();
    } catch (e) {
      // Revert optimistic update on failure
      final revertedUsers = _state.users.map((user) {
        if (user['uid'] == uid) {
          return {...user, 'isSuspended': false};
        }
        return user;
      }).toList();

      _state = _state.copyWith(users: revertedUsers, error: e.toString());
      notifyListeners();
    }
  }

  /// Verify a teacher (optimistic update) and send approval email
  Future<void> verifyTeacher(String uid, {String? email, String? name}) async {
    // Optimistic update
    final updatedUsers = _state.users.map((user) {
      if (user['uid'] == uid) {
        return {...user, 'isVerified': true};
      }
      return user;
    }).toList();

    _state = _state.copyWith(users: updatedUsers);
    notifyListeners();

    try {
      await _adminService.verifyTeacher(uid, email: email, name: name);
    } catch (e) {
      // Revert optimistic update on failure
      final revertedUsers = _state.users.map((user) {
        if (user['uid'] == uid) {
          return {...user, 'isVerified': false};
        }
        return user;
      }).toList();

      _state = _state.copyWith(users: revertedUsers, error: e.toString());
      notifyListeners();
    }
  }

  /// Reject a teacher (optimistic update) and send rejection email
  Future<void> rejectTeacher(String uid, {String? email, String? name, String? reason}) async {
    // Optimistic update
    final updatedUsers = _state.users.map((user) {
      if (user['uid'] == uid) {
        return {...user, 'isRejected': true};
      }
      return user;
    }).toList();

    _state = _state.copyWith(users: updatedUsers);
    notifyListeners();

    try {
      await _adminService.rejectTeacher(uid, email: email, name: name, reason: reason);
    } catch (e) {
      // Revert optimistic update on failure
      final revertedUsers = _state.users.map((user) {
        if (user['uid'] == uid) {
          return {...user, 'isRejected': false};
        }
        return user;
      }).toList();

      _state = _state.copyWith(users: revertedUsers, error: e.toString());
      notifyListeners();
    }
  }

  /// Load flagged content
  Future<void> loadFlaggedContent({bool refresh = false}) async {
    try {
      final result = await _adminService.getFlaggedContent();
      _state = _state.copyWith(
        reportedContent: result['items'] as List<Map<String, dynamic>>,
      );
      notifyListeners();
    } catch (e) {
      _state = _state.copyWith(error: e.toString());
      notifyListeners();
    }
  }

  /// Moderate content (approve to keep, reject to remove)
  Future<void> moderateContent({
    required String contentId,
    required String contentType,
    required bool approve,
    String? parentId,
  }) async {
    // Optimistic update - remove from list
    final updatedContent = _state.reportedContent
        .where((item) => item['id'] != contentId)
        .toList();

    _state = _state.copyWith(reportedContent: updatedContent);
    notifyListeners();

    try {
      await _adminService.moderateContent(
        contentId: contentId,
        contentType: contentType,
        approve: approve,
        parentId: parentId,
      );
    } catch (e) {
      // Reload on failure
      loadFlaggedContent(refresh: true);
      _state = _state.copyWith(error: e.toString());
      notifyListeners();
    }
  }

  /// Load analytics data
  Future<void> loadAnalyticsData() async {
    try {
      final results = await Future.wait([
        _adminService.getUserGrowthData(),
        _adminService.getRevenueData(),
      ]);

      _state = _state.copyWith(
        userGrowthData: results[0],
        revenueData: results[1],
      );
      notifyListeners();
    } catch (e) {
      _state = _state.copyWith(error: e.toString());
      notifyListeners();
    }
  }

  /// Clear error
  void clearError() {
    _state = _state.copyWith(error: null);
    notifyListeners();
  }

  /// Reset state (for logout)
  void reset() {
    _state = AdminState();
    notifyListeners();
  }
}
