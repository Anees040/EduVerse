import 'dart:async';

/// Simple in-memory cache service for faster loading
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  final Map<String, dynamic> _cache = {};
  final Map<String, DateTime> _cacheTimestamps = {};

 
  static const Duration defaultCacheDuration = Duration(minutes: 2);

  /// Get cached data
  T? get<T>(String key) {
    if (!_cache.containsKey(key)) return null;

    final timestamp = _cacheTimestamps[key];
    if (timestamp != null &&
        DateTime.now().difference(timestamp) > defaultCacheDuration) {
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
  bool has(String key) {
    if (!_cache.containsKey(key)) return false;

    final timestamp = _cacheTimestamps[key];
    if (timestamp != null &&
        DateTime.now().difference(timestamp) > defaultCacheDuration) {
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
    if (has(key)) {
      return _cache[key] as T;
    }

    // Fetch and cache
    final data = await fetch();
    set(key, data);
    return data;
  }
}
