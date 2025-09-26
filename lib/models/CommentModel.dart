// models/CommentModel.dart
class Comment {
  final int id;
  final String text;
  final String userUsername;
  final String userProfileImage;
  final String createdAt;
  final int likesCount;
  final bool isLiked;

  Comment({
    required this.id,
    required this.text,
    required this.userUsername,
    required this.userProfileImage,
    required this.createdAt,
    required this.likesCount,
    required this.isLiked,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] ?? 0,
      text: json['text'] ?? '',
      userUsername: json['user_username'] ?? json['user']?['username'] ?? 'Unknown',
      userProfileImage: json['user_profile_image'] ?? json['user']?['profile_image'] ?? '',
      createdAt: json['created_at'] ?? DateTime.now().toIso8601String(),
      likesCount: json['likes_count'] ?? 0,
      isLiked: json['is_liked'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'user_username': userUsername,
      'user_profile_image': userProfileImage,
      'created_at': createdAt,
      'likes_count': likesCount,
      'is_liked': isLiked,
    };
  }

  Comment copyWith({
    int? id,
    String? text,
    String? userUsername,
    String? userProfileImage,
    String? createdAt,
    int? likesCount,
    bool? isLiked,
  }) {
    return Comment(
      id: id ?? this.id,
      text: text ?? this.text,
      userUsername: userUsername ?? this.userUsername,
      userProfileImage: userProfileImage ?? this.userProfileImage,
      createdAt: createdAt ?? this.createdAt,
      likesCount: likesCount ?? this.likesCount,
      isLiked: isLiked ?? this.isLiked,
    );
  }
}