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

  factory VideoPost.fromJson(Map<String, dynamic> json) {
    return VideoPost(
      id: json['id'],
      title: json['title'] ?? 'Untitled',
      description: json['description'] ?? '',
      videoUrl: json['video_url'] ?? '',
      userUsername: json['user_username'] ?? 'Unknown',
      likesCount: json['likes_count'] ?? 0,
      commentsCount: json['comments_count'] ?? 0,
      isLiked: json['is_liked'] ?? false,
      isBookmarked: json['is_bookmarked'] ?? false,
      thumbnailUrl: json['thumbnail_url'] ?? '',
    );
  }
}
class Comment {
  final int id;
  final String userUsername;
  final String text;
  final String createdAt;

  Comment({
    required this.id,
    required this.userUsername,
    required this.text,
    required this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'],
      userUsername: json['user_username'] ?? 'Unknown',
      text: json['text'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }
}
