import 'dart:async';

import 'package:bbdsocial/services/UserService.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:bbdsocial/utils/SVColors.dart';
import 'package:bbdsocial/models/VideoModel.dart';

class SVForumScreen extends StatefulWidget {
  const SVForumScreen({Key? key}) : super(key: key);

  @override
  _SVForumScreenState createState() => _SVForumScreenState();
}

class _SVForumScreenState extends State<SVForumScreen> {
  final PageController _pageController = PageController();
  List<VideoPost> _videos = [];
  int _currentPage = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 1;

  // Comment state
  List<Comment> _comments = [];
  bool _isLoadingComments = false;
  int? _currentVideoId;

  @override
  void initState() {
    super.initState();
    _loadVideos();
    _pageController.addListener(_pageListener);
  }

  @override
  void dispose() {
    _pageController.removeListener(_pageListener);
    _pageController.dispose();
    super.dispose();
  }

  void _pageListener() {
    final newPage = _pageController.page?.round() ?? 0;
    if (newPage != _currentPage) {
      setState(() {
        _currentPage = newPage;
      });
      
      // Load more videos when near the end
      if (newPage >= _videos.length - 2 && _hasMore && !_isLoading) {
        _loadVideos();
      }
    }
  }

  Future<bool> _testVideoUrl(String url) async {
    try {
      final response = await http.head(Uri.parse(url));
      if (response.statusCode == 200) {
        print('Video URL is accessible: $url');
        return true;
      } else {
        print('Video URL returned status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Video URL test failed: $e');
      return false;
    }
  }

  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // In SVForumScreen.dart - Update the API calls to use UserService
  Future<void> _loadVideos() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Use UserService instead of direct HTTP calls
      final videosData = await UserService.getVideos(page: _page);
      
      final List<VideoPost> newVideos = videosData
          .map((videoJson) {
            try {
              return VideoPost.fromJson(videoJson);
            } catch (e) {
              print('Error parsing video: $e');
              return null;
            }
          })
          .where((video) => video != null)
          .cast<VideoPost>()
          .toList();

      setState(() {
        _videos.addAll(newVideos);
        _isLoading = false;
        _page++;
        _hasMore = videosData.length == 10; // Assuming 10 per page
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      toast('Error loading videos: $e');
    }
  }

  Future<void> _likeVideo(int videoId) async {
    try {
      await UserService.likeVideo(videoId);
      
      setState(() {
        final videoIndex = _videos.indexWhere((v) => v.id == videoId);
        if (videoIndex != -1) {
          final video = _videos[videoIndex];
          _videos[videoIndex] = VideoPost(
            id: video.id,
            title: video.title,
            description: video.description,
            videoUrl: video.videoUrl,
            userUsername: video.userUsername,
            likesCount: video.isLiked ? video.likesCount - 1 : video.likesCount + 1,
            commentsCount: video.commentsCount,
            isLiked: !video.isLiked,
            isBookmarked: video.isBookmarked,
            thumbnailUrl: video.thumbnailUrl,
          );
        }
      });
    } catch (e) {
      toast('Error liking video: $e');
    }
  }

// Similarly update _bookmarkVideo, _loadComments, _sendComment to use UserService

  Future<void> _loadComments(int videoId) async {
    setState(() {
      _isLoadingComments = true;
      _currentVideoId = videoId;
    });

    try {
      final token = await _getAuthToken();
      final response = await http.get(
        Uri.parse('http://10.0.0.158:5000/api/videos/$videoId/comments/'),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<Comment> comments = (data as List)
            .map((commentJson) => Comment.fromJson(commentJson))
            .toList();

        setState(() {
          _comments = comments;
          _isLoadingComments = false;
        });
      } else {
        throw Exception('Failed to load comments');
      }
    } catch (e) {
      setState(() {
        _isLoadingComments = false;
      });
      toast('Error loading comments: $e');
    }
  }

  Future<void> _bookmarkVideo(int videoId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        toast('Please login to bookmark videos');
        return;
      }

      final response = await http.post(
        Uri.parse('http://10.0.0.158:5000/api/videos/$videoId/bookmark/'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          final videoIndex = _videos.indexWhere((v) => v.id == videoId);
          if (videoIndex != -1) {
            final video = _videos[videoIndex];
            _videos[videoIndex] = VideoPost(
              id: video.id,
              title: video.title,
              description: video.description,
              videoUrl: video.videoUrl,
              userUsername: video.userUsername,
              likesCount: video.likesCount,
              commentsCount: video.commentsCount,
              isLiked: video.isLiked,
              isBookmarked: !video.isBookmarked,
              thumbnailUrl: video.thumbnailUrl,
            );
          }
        });
      }
    } catch (e) {
      toast('Error bookmarking video: $e');
    }
  }

  void _showCommentsSheet(int videoId) {
    _loadComments(videoId);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsBottomSheet(
        videoId: videoId,
        comments: _comments,
        isLoading: _isLoadingComments,
        onSendComment: (text) {
          // Implement comment sending
          _sendComment(videoId, text);
        },
      ),
    );
  }

  Future<void> _sendComment(int videoId, String text) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        toast('Please login to comment');
        return;
      }

      final response = await http.post(
        Uri.parse('http://10.0.0.158:5000/api/videos/$videoId/comments/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'text': text}),
      );

      if (response.statusCode == 201) {
        _loadComments(videoId); // Reload comments
        toast('Comment added');
      }
    } catch (e) {
      toast('Error sending comment: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _videos.isEmpty && _isLoading
          ? Center(child: CircularProgressIndicator(color: SVAppColorPrimary))
          : PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: _videos.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= _videos.length) {
                  return Center(child: CircularProgressIndicator(color: SVAppColorPrimary));
                }
                
                final video = _videos[index];
                return VideoPostItem(
                  video: video,
                  isCurrent: index == _currentPage,
                  onLike: () => _likeVideo(video.id),
                  onBookmark: () => _bookmarkVideo(video.id),
                  onComment: () => _showCommentsSheet(video.id),
                );
              },
            ),
    );
  }
}

class VideoPostItem extends StatefulWidget {
  final VideoPost video;
  final bool isCurrent;
  final VoidCallback onLike;
  final VoidCallback onBookmark;
  final VoidCallback onComment;

  const VideoPostItem({
    Key? key,
    required this.video,
    required this.isCurrent,
    required this.onLike,
    required this.onBookmark,
    required this.onComment,
  }) : super(key: key);

  @override
  _VideoPostItemState createState() => _VideoPostItemState();
}

class _VideoPostItemState extends State<VideoPostItem> {
  late VideoPlayerController _controller;
  bool _isVideoInitialized = false;
  bool _isLoadingVideo = false;
  String? _videoError;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

Future<void> _initializeVideo() async {
  if (widget.video.videoUrl.isEmpty) {
    setState(() {
      _videoError = 'Video URL is empty';
    });
    return;
  }

  setState(() {
    _isLoadingVideo = true;
    _videoError = null;
  });

  try {
    // Test the URL first
    final response = await http.head(Uri.parse(widget.video.videoUrl));
    if (response.statusCode != 200) {
      throw Exception('Video URL returned status ${response.statusCode}');
    }

    // Create controller with explicit format hint
    _controller = VideoPlayerController.network(
      widget.video.videoUrl,
      // Removed formatHint as it is not required
      videoPlayerOptions: VideoPlayerOptions(
        allowBackgroundPlayback: false,
        mixWithOthers: false,
      ),
    );

    // Set up error handling
    _controller.addListener(() {
      if (_controller.value.hasError && mounted) {
        setState(() {
          _videoError = _controller.value.errorDescription ?? 'Unknown video error';
          _isLoadingVideo = false;
        });
      }
    });

    // Initialize with better error handling
    await _controller.initialize().timeout(
      Duration(seconds: 30),
      onTimeout: () {
        throw TimeoutException('Video initialization timed out after 30 seconds');
      },
    );

    if (mounted) {
      setState(() {
        _isVideoInitialized = true;
        _isLoadingVideo = false;
      });
      
      // Auto-play if this is the current video
      if (widget.isCurrent) {
        await _controller.play();
        _controller.setLooping(true);
      }
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        _videoError = 'Failed to load video: ${e.toString()}';
        _isLoadingVideo = false;
        _isVideoInitialized = false;
      });
    }
    print('Video initialization error: $e');
    
    // Try alternative approach for problematic videos
    if (e.toString().contains('byte range') || e.toString().contains('range')) {
      await _tryAlternativeVideoLoad();
    }
  }
}

Future<void> _tryAlternativeVideoLoad() async {
  // Try loading the video in a different way
  try {
    print('Trying alternative video loading method...');
    
    // Create a new controller with different options
    _controller = VideoPlayerController.network(
      widget.video.videoUrl,
      // Don't use format hint this time
      videoPlayerOptions: VideoPlayerOptions(
        allowBackgroundPlayback: false,
      ),
    );
    
    await _controller.initialize().timeout(Duration(seconds: 20));
    
    if (mounted) {
      setState(() {
        _isVideoInitialized = true;
        _isLoadingVideo = false;
        _videoError = null;
      });
      
      if (widget.isCurrent) {
        await _controller.play();
        _controller.setLooping(true);
      }
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        _videoError = 'Alternative load also failed: ${e.toString()}';
        _isLoadingVideo = false;
      });
    }
    print('Alternative video load error: $e');
  }
}

  @override
  void didUpdateWidget(covariant VideoPostItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isCurrent && !oldWidget.isCurrent) {
      // Became current video - play it
      if (_isVideoInitialized && !_controller.value.isPlaying) {
        _controller.play();
      }
    } else if (!widget.isCurrent && oldWidget.isCurrent) {
      // No longer current video - pause it
      if (_isVideoInitialized && _controller.value.isPlaying) {
        _controller.pause();
      }
    }
    
    // If video URL changed, reinitialize
    if (widget.video.videoUrl != oldWidget.video.videoUrl) {
      _controller.dispose();
      _initializeVideo();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (!_isVideoInitialized) return;
    
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
  }

  void _retryVideoLoad() {
    _initializeVideo();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Video background with error handling
        if (_isLoadingVideo)
          Container(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: SVAppColorPrimary),
                  SizedBox(height: 16),
                  // Text(
                  //   'Loading video...',
                  //   style: TextStyle(color: Colors.white),
                  // ),
                ],
              ),
            ),
          )
        else if (_videoError != null)
          Container(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 48),
                  SizedBox(height: 16),
                  Text(
                    'Video load failed',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _videoError!,
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _retryVideoLoad,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SVAppColorPrimary,
                    ),
                    child: Text('Retry'),
                  ),
                ],
              ),
            ),
          )
        else if (_isVideoInitialized)
          GestureDetector(
            onTap: _togglePlayPause,
            child: VideoPlayer(_controller),
          )
        else
          Container(
            color: Colors.black,
            child: Center(child: CircularProgressIndicator(color: SVAppColorPrimary)),
          ),

        // Rest of your overlay widgets...
        // Gradient overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withOpacity(0.3),
                Colors.black.withOpacity(0.7),
              ],
            ),
          ),
        ),
        
        // Content overlay
        Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User info and follow button at top
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Text(
                      widget.video.userUsername[0].toUpperCase(),
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    widget.video.userUsername,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: SVAppColorPrimary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Follow',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              Spacer(),

              // Video description
              Text(
                widget.video.description.isNotEmpty 
                    ? widget.video.description 
                    : widget.video.title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              SizedBox(height: 16),

              // Sound info
              Row(
                children: [
                  Icon(Icons.music_note, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Original Sound',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 16),
            ],
          ),
        ),

        // Right side action buttons
        Positioned(
          right: 16,
          bottom: 100,
          child: Column(
            children: [
              // Like button
              _ActionButton(
                icon: widget.video.isLiked ? Icons.favorite : Icons.favorite_border,
                count: widget.video.likesCount,
                color: widget.video.isLiked ? Colors.red : Colors.white,
                onTap: widget.onLike,
              ),
              SizedBox(height: 20),

              // Comment button
              _ActionButton(
                icon: Icons.chat_bubble_outline,
                count: widget.video.commentsCount,
                onTap: widget.onComment,
              ),
              SizedBox(height: 20),

              // Bookmark button
              _ActionButton(
                icon: widget.video.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                count: 0,
                color: widget.video.isBookmarked ? SVAppColorPrimary : Colors.white,
                onTap: widget.onBookmark,
              ),
              SizedBox(height: 20),

              // Share button
              _ActionButton(
                icon: Icons.share,
                count: 0,
                onTap: () {
                  // Implement share functionality
                  toast('Share functionality coming soon');
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    Key? key,
    required this.icon,
    required this.count,
    this.color = Colors.white,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconButton(
          icon: Icon(icon, color: color, size: 32),
          onPressed: onTap,
        ),
        if (count > 0)
          Text(
            _formatCount(count),
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}

class CommentsBottomSheet extends StatefulWidget {
  final int videoId;
  final List<Comment> comments;
  final bool isLoading;
  final Function(String) onSendComment;

  const CommentsBottomSheet({
    Key? key,
    required this.videoId,
    required this.comments,
    required this.isLoading,
    required this.onSendComment,
  }) : super(key: key);

  @override
  _CommentsBottomSheetState createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  final TextEditingController _commentController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white24)),
            ),
            child: Row(
              children: [
                Text(
                  'Comments',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Comments list
          Expanded(
            child: widget.isLoading
                ? Center(child: CircularProgressIndicator(color: SVAppColorPrimary))
                : widget.comments.isEmpty
                    ? Center(
                        child: Text(
                          'No comments yet',
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: widget.comments.length,
                        itemBuilder: (context, index) {
                          final comment = widget.comments[index];
                          return CommentItem(comment: comment);
                        },
                      ),
          ),

          // Comment input
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.white24)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      hintStyle: TextStyle(color: Colors.white54),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white12,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.send, color: SVAppColorPrimary),
                  onPressed: () {
                    if (_commentController.text.trim().isNotEmpty) {
                      widget.onSendComment(_commentController.text.trim());
                      _commentController.clear();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}

class CommentItem extends StatelessWidget {
  final Comment comment;

  const CommentItem({Key? key, required this.comment}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: SVAppColorPrimary,
            child: Text(
              comment.userUsername[0].toUpperCase(),
              style: TextStyle(color: Colors.white),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment.userUsername,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  comment.text,
                  style: TextStyle(color: Colors.white),
                ),
                SizedBox(height: 4),
                Text(
                  comment.createdAt,
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.favorite_border, color: Colors.white54, size: 16),
            onPressed: () {
              // Implement like comment
            },
          ),
        ],
      ),
    );
  }
}