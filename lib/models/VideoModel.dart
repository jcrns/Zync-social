// In your VideoModel.dart file, add this to the VideoPost class
import 'CommentModel.dart'; // Add this import

class VideoPost {
  final int id;
  final String title;
  final String description;
  final String videoUrl;
  final String userUsername;
  final int likesCount;
  final int commentsCount;
  final bool isLiked;
  final bool isBookmarked;
  final String thumbnailUrl;

  VideoPost({
    required this.id,
    required this.title,
    required this.description,
    required this.videoUrl,
    required this.userUsername,
    required this.likesCount,
    required this.commentsCount,
    required this.isLiked,
    required this.isBookmarked,
    required this.thumbnailUrl,
  });

  // Add copyWith method
  VideoPost copyWith({
    int? id,
    String? title,
    String? description,
    String? videoUrl,
    String? userUsername,
    int? likesCount,
    int? commentsCount,
    bool? isLiked,
    bool? isBookmarked,
    String? thumbnailUrl,
  }) {
    return VideoPost(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      videoUrl: videoUrl ?? this.videoUrl,
      userUsername: userUsername ?? this.userUsername,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      isLiked: isLiked ?? this.isLiked,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    );
  }

  // Your existing fromJson method...
  factory VideoPost.fromJson(Map<String, dynamic> json) {
    return VideoPost(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      videoUrl: json['video_url'] ?? '',
      userUsername: json['user_username'] ?? '',
      likesCount: json['likes_count'] ?? 0,
      commentsCount: json['comments_count'] ?? 0,
      isLiked: json['is_liked'] ?? false,
      isBookmarked: json['is_bookmarked'] ?? false,
      thumbnailUrl: json['thumbnail_url'] ?? '',
    );
  }
}