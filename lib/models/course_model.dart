/// Course model for EduVerse platform
/// Represents a course with all metadata, pricing, and branding information
class Course {
  final String courseUid;
  final String teacherUid;
  final String title;
  final String? subtitle;
  final String description;
  final String imageUrl;
  final String? videoUrl; // Legacy field for main course video
  final String? previewVideoUrl; // Trailer/intro video
  final String category;
  final String difficulty; // 'beginner', 'intermediate', 'advanced'
  final bool isFree;
  final double price;
  final double? discountedPrice;
  final int createdAt;
  final int? updatedAt;
  final int enrolledCount;
  final int videoCount;
  final double? averageRating;
  final int? reviewCount;
  final bool isPublished;

  Course({
    required this.courseUid,
    required this.teacherUid,
    required this.title,
    this.subtitle,
    required this.description,
    required this.imageUrl,
    this.videoUrl,
    this.previewVideoUrl,
    required this.category,
    required this.difficulty,
    required this.isFree,
    required this.price,
    this.discountedPrice,
    required this.createdAt,
    this.updatedAt,
    this.enrolledCount = 0,
    this.videoCount = 0,
    this.averageRating,
    this.reviewCount,
    this.isPublished = true,
  });

  /// Create Course from Firebase Map
  factory Course.fromMap(String courseUid, Map<dynamic, dynamic> data) {
    // Count enrolled students if available
    int enrolledCount = 0;
    if (data['enrolledStudents'] != null) {
      enrolledCount = (data['enrolledStudents'] as Map).length;
    }

    // Count videos: support Map, List, and legacy single video fields
    int videoCount = 0;
    if (data['videos'] != null) {
      final vids = data['videos'];
      if (vids is Map) {
        videoCount = vids.length;
      } else if (vids is List) {
        videoCount = vids.length;
      }
    } else if (data['videoUrl'] != null || data['video'] != null) {
      videoCount = 1;
    }

    return Course(
      courseUid: courseUid,
      teacherUid: data['teacherUid'] ?? '',
      title: data['title'] ?? '',
      subtitle: data['subtitle'],
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      videoUrl: data['videoUrl'],
      previewVideoUrl: data['previewVideoUrl'],
      category: data['category'] ?? 'General',
      difficulty: data['difficulty'] ?? 'beginner',
      isFree: data['isFree'] ?? true,
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      discountedPrice: (data['discountedPrice'] as num?)?.toDouble(),
      createdAt: data['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
      updatedAt: data['updatedAt'],
      enrolledCount: enrolledCount,
      videoCount: videoCount,
      averageRating: (data['averageRating'] as num?)?.toDouble(),
      reviewCount: data['reviewCount'],
      isPublished: data['isPublished'] ?? true,
    );
  }

  /// Convert Course to Map for Firebase storage
  Map<String, dynamic> toMap() {
    return {
      'courseUid': courseUid,
      'teacherUid': teacherUid,
      'title': title,
      if (subtitle != null) 'subtitle': subtitle,
      'description': description,
      'imageUrl': imageUrl,
      if (videoUrl != null) 'videoUrl': videoUrl,
      if (previewVideoUrl != null) 'previewVideoUrl': previewVideoUrl,
      'category': category,
      'difficulty': difficulty,
      'isFree': isFree,
      'price': price,
      if (discountedPrice != null) 'discountedPrice': discountedPrice,
      'createdAt': createdAt,
      if (updatedAt != null) 'updatedAt': updatedAt,
      'isPublished': isPublished,
    };
  }

  /// Create a copy with updated fields
  Course copyWith({
    String? courseUid,
    String? teacherUid,
    String? title,
    String? subtitle,
    String? description,
    String? imageUrl,
    String? videoUrl,
    String? previewVideoUrl,
    String? category,
    String? difficulty,
    bool? isFree,
    double? price,
    double? discountedPrice,
    int? createdAt,
    int? updatedAt,
    int? enrolledCount,
    int? videoCount,
    double? averageRating,
    int? reviewCount,
    bool? isPublished,
  }) {
    return Course(
      courseUid: courseUid ?? this.courseUid,
      teacherUid: teacherUid ?? this.teacherUid,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      previewVideoUrl: previewVideoUrl ?? this.previewVideoUrl,
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
      isFree: isFree ?? this.isFree,
      price: price ?? this.price,
      discountedPrice: discountedPrice ?? this.discountedPrice,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      enrolledCount: enrolledCount ?? this.enrolledCount,
      videoCount: videoCount ?? this.videoCount,
      averageRating: averageRating ?? this.averageRating,
      reviewCount: reviewCount ?? this.reviewCount,
      isPublished: isPublished ?? this.isPublished,
    );
  }

  /// Get difficulty display text
  String get difficultyDisplay {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return 'Beginner';
      case 'intermediate':
        return 'Intermediate';
      case 'advanced':
        return 'Advanced';
      default:
        return 'Beginner';
    }
  }

  /// Get formatted price string
  String get priceDisplay {
    if (isFree) return 'Free';
    if (discountedPrice != null && discountedPrice! < price) {
      return '\$${discountedPrice!.toStringAsFixed(2)}';
    }
    return '\$${price.toStringAsFixed(2)}';
  }

  /// Check if course has discount
  bool get hasDiscount =>
      !isFree && discountedPrice != null && discountedPrice! < price;

  /// Get discount percentage
  int get discountPercentage {
    if (!hasDiscount) return 0;
    return (((price - discountedPrice!) / price) * 100).round();
  }
}

/// Course categories available in the platform
class CourseCategories {
  static const List<String> categories = [
    'Programming',
    'Web Development',
    'Mobile Development',
    'Data Science',
    'Machine Learning',
    'Design',
    'Business',
    'Marketing',
    'Photography',
    'Music',
    'Health & Fitness',
    'Language',
    'Personal Development',
    'Finance',
    'Other',
  ];

  static const List<String> difficulties = [
    'beginner',
    'intermediate',
    'advanced',
  ];

  static String getDifficultyDisplay(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return 'Beginner';
      case 'intermediate':
        return 'Intermediate';
      case 'advanced':
        return 'Advanced';
      default:
        return 'Beginner';
    }
  }
}
