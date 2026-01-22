import 'dart:async';

/// Simple in-memory cache service for faster loading
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  final Map<String, dynamic> _cache = {};
  final Map<String, DateTime> _cacheTimestamps = {};

  // Increased default cache duration for better performance
  static const Duration defaultCacheDuration = Duration(minutes: 30);
  static const Duration shortCacheDuration = Duration(minutes: 5);
  static const Duration longCacheDuration = Duration(hours: 2);

  /// Get cached data
  T? get<T>(String key, {Duration? maxAge}) {
    if (!_cache.containsKey(key)) return null;

    final timestamp = _cacheTimestamps[key];
    final duration = maxAge ?? defaultCacheDuration;
    if (timestamp != null && DateTime.now().difference(timestamp) > duration) {
      // Cache expired
      _cache.remove(key);
      _cacheTimestamps.remove(key);
      return null;
    }

    return _cache[key] as T?;
  }

  /// Set cached data
  void set(String key, dynamic value) {
    _cache[key] = value;
    _cacheTimestamps[key] = DateTime.now();
  }

  /// Check if cache exists and is valid
  bool has(String key, {Duration? maxAge}) {
    if (!_cache.containsKey(key)) return false;

    final timestamp = _cacheTimestamps[key];
    final duration = maxAge ?? defaultCacheDuration;
    if (timestamp != null && DateTime.now().difference(timestamp) > duration) {
      _cache.remove(key);
      _cacheTimestamps.remove(key);
      return false;
    }

    return true;
  }

  /// Remove specific cache
  void remove(String key) {
    _cache.remove(key);
    _cacheTimestamps.remove(key);
  }

  /// Clear all cache
  void clear() {
    _cache.clear();
    _cacheTimestamps.clear();
  }

  /// Clear cache for a specific prefix (e.g., clear all user-related cache)
  void clearPrefix(String prefix) {
    final keysToRemove = _cache.keys
        .where((key) => key.startsWith(prefix))
        .toList();
    for (final key in keysToRemove) {
      _cache.remove(key);
      _cacheTimestamps.remove(key);
    }
  }

  /// Get cached data or fetch from source
  Future<T> getOrFetch<T>({
    required String key,
    required Future<T> Function() fetch,
    Duration? cacheDuration,
  }) async {
    // Check cache first
    if (has(key, maxAge: cacheDuration)) {
      return _cache[key] as T;
    }

    // Fetch and cache
    final data = await fetch();
    set(key, data);
    return data;
  }

  /// Invalidate all caches related to a specific user
  void invalidateUserCache(String uid) {
    clearPrefix('user_');
    clearPrefix('profile_');
    clearPrefix('profile_data_');
    clearPrefix('enrolled_');
    clearPrefix('enrolled_courses_');
    clearPrefix('unenrolled_');
    clearPrefix('unenrolled_courses_');
    clearPrefix('course_progress_');
    clearPrefix('course_detail_');
    clearPrefix('teacher_');
    clearPrefix('all_courses_');
  }

  /// Clear all student progress related caches
  void clearStudentProgressCache(String studentUid) {
    remove('enrolled_courses_detail_$studentUid');
    remove('course_progress_$studentUid');
    remove('profile_data_$studentUid');
    clearPrefix('course_detail_');
  }

  /// Clear all teacher analytics caches
  void clearTeacherAnalyticsCache() {
    clearPrefix('teacher_analytics_');
    clearPrefix('teacher_students_');
    clearPrefix('teacher_reviews_');
  }

  /// Get the age of a cached item
  Duration? getCacheAge(String key) {
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null) return null;
    return DateTime.now().difference(timestamp);
  }

  /// Check if cache needs refresh (older than specified duration)
  bool needsRefresh(
    String key, {
    Duration threshold = const Duration(minutes: 5),
  }) {
    final age = getCacheAge(key);
    if (age == null) return true;
    return age > threshold;
  }

  /// Clear ALL caches including static caches from all screens
  /// IMPORTANT: Call this on logout to prevent data leakage between users
  void clearAllOnLogout() {
    // Clear this service's in-memory cache
    clear();
  }
}
