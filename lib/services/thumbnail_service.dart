import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:eduverse/services/cache_service.dart';

/// Service for generating and caching video thumbnails
class ThumbnailService {
  static final ThumbnailService _instance = ThumbnailService._internal();
  factory ThumbnailService() => _instance;
  ThumbnailService._internal();

  final CacheService _cacheService = CacheService();
  final Map<String, Uint8List> _memoryCache = {};

  /// Get thumbnail URL from Cloudinary video URL
  /// Cloudinary automatically provides thumbnail via URL transformation
  String? getCloudinaryThumbnailUrl(String videoUrl) {
    if (videoUrl.isEmpty) return null;

    // Check if this is a Cloudinary URL
    if (videoUrl.contains('cloudinary.com') ||
        videoUrl.contains('res.cloudinary')) {
      // Transform video URL to image thumbnail
      // Example: .../video/upload/... -> .../video/upload/so_0,w_320,h_180,c_fill/...
      // This gets the first frame (so_0 = start offset 0)
      try {
        // Replace /upload/ with /upload/so_0,w_320,h_180,c_fill,f_jpg/
        String thumbnailUrl = videoUrl.replaceFirst(
          '/upload/',
          '/upload/so_0,w_320,h_180,c_fill,f_jpg/',
        );
        // Change extension to jpg
        thumbnailUrl = thumbnailUrl.replaceAll(
          RegExp(r'\.(mp4|mov|avi|webm|mkv)(\?.*)?$', caseSensitive: false),
          '.jpg',
        );
        return thumbnailUrl;
      } catch (e) {
        debugPrint('Error creating Cloudinary thumbnail URL: $e');
        return null;
      }
    }

    return null;
  }

  /// Generate thumbnail from video URL (fallback for non-Cloudinary videos)
  /// Returns cached thumbnail if available, otherwise generates new one
  Future<Uint8List?> getThumbnailFromUrl(String videoUrl) async {
    if (videoUrl.isEmpty) return null;

    // Check memory cache first
    if (_memoryCache.containsKey(videoUrl)) {
      return _memoryCache[videoUrl];
    }

    // Check disk cache
    final cacheKey = 'thumb_${videoUrl.hashCode}';
    final cached = _cacheService.get<Uint8List>(cacheKey);
    if (cached != null) {
      _memoryCache[videoUrl] = cached;
      return cached;
    }

    try {
      // Generate thumbnail from network video
      final thumbnail = await VideoThumbnail.thumbnailData(
        video: videoUrl,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 320,
        maxHeight: 180,
        quality: 75,
      );

      if (thumbnail != null) {
        // Cache in memory and disk
        _memoryCache[videoUrl] = thumbnail;
        _cacheService.set(cacheKey, thumbnail);
      }

      return thumbnail;
    } catch (e) {
      debugPrint('Error generating thumbnail from URL: $e');
      return null;
    }
  }

  /// Generate thumbnail from local file path
  Future<Uint8List?> getThumbnailFromFile(String filePath) async {
    try {
      final thumbnail = await VideoThumbnail.thumbnailData(
        video: filePath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 320,
        maxHeight: 180,
        quality: 75,
      );
      return thumbnail;
    } catch (e) {
      debugPrint('Error generating thumbnail from file: $e');
      return null;
    }
  }

  /// Generate and save thumbnail to a file (useful for uploading)
  Future<String?> generateThumbnailFile(String videoPath) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final thumbnailPath =
          '${tempDir.path}/thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final path = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: thumbnailPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 320,
        maxHeight: 180,
        quality: 75,
      );

      return path;
    } catch (e) {
      debugPrint('Error generating thumbnail file: $e');
      return null;
    }
  }

  /// Clear cached thumbnail for a specific URL
  void clearThumbnail(String videoUrl) {
    _memoryCache.remove(videoUrl);
    _cacheService.remove('thumb_${videoUrl.hashCode}');
  }

  /// Clear all cached thumbnails
  void clearAllThumbnails() {
    _memoryCache.clear();
    _cacheService.clearPrefix('thumb_');
  }
}
