import 'dart:convert';
import 'package:bbdsocial/screens/addPost/components/PostInputWidget.dart';
import 'package:bbdsocial/screens/profile/screens/ProfileDetail.dart';
import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:bbdsocial/utils/SVCommon.dart';
import 'package:bbdsocial/utils/SVConstants.dart';
import 'package:bbdsocial/utils/SVColors.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

class SVPostDetailScreen extends StatefulWidget {
  final dynamic post;
  final String token;
  final String url;

  const SVPostDetailScreen({
    Key? key,
    required this.post,
    required this.token,
    required this.url,
  }) : super(key: key);

  @override
  _SVPostDetailScreenState createState() => _SVPostDetailScreenState();
}

class _SVPostDetailScreenState extends State<SVPostDetailScreen> {
  static const String likeUrl = 'like/';
  dynamic _post;
  bool _isLoading = true;
  Map<int, bool> _expandedPosts = {};
  Map<int, bool> _expandedComments = {};

  final TextEditingController _postController = TextEditingController();
  final FocusNode _postFocusNode = FocusNode();
  int? _replyingToPostId;
  String _replyingToUsername = '';
  final ScrollController _scrollController = ScrollController();
  bool _isRefreshing = false;

  WebSocketChannel? _channel;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _fetchPostDetails();
    _connectToWebSocket();
  }

  void _connectToWebSocket() {
    if (_post == null || _post['id'] == null) return;
    
    final wsUrl = Uri.parse('ws://10.0.0.158:8000/ws/post/${_post['id']}/');
    _channel = IOWebSocketChannel.connect(wsUrl);

    _channel!.stream.listen((message) {
      final decodedMessage = json.decode(message);
      final eventType = decodedMessage['type'];
      final data = decodedMessage['data'];

      if (mounted) {
        setState(() {
          if (eventType == 'new_reply') {
            if (_post['child_posts'] == null) {
              _post['child_posts'] = [];
            }
            if (!_post['child_posts'].any((p) => p['id'] == data['id'])) {
                _post['child_posts'].insert(0, data);
            }
          }
        });
      }
    }, onError: (error) {
      print('WebSocket Error: $error');
    }, onDone: () {
      print('WebSocket connection closed');
    });
  }

  @override
  void dispose() {
    _postController.dispose();
    _postFocusNode.dispose();
    _scrollController.dispose();
    _channel?.sink.close();
    super.dispose();
  }

  Future<void> _fetchPostDetails() async {
    try {
      final response = await http.get(
        Uri.parse('${widget.url}/api/social-posts/${_post['id']}/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Client-Version': '1.0.0',
          'X-Client-Platform': 'flutter-ios',
          'Authorization': 'Bearer ${widget.token}'
        },
      );
      
      if (response.statusCode == 200) {
        setState(() {
          _post = json.decode(response.body);
          _isLoading = false;
          // Auto-expand the main post only
          _expandedPosts[_post['id']] = true;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error fetching post details: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchChildPosts(int postId) async {
    try {
      final response = await http.get(
        Uri.parse('${widget.url}/api/social-posts/?parent_pk=$postId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Client-Version': '1.0.0',
          'X-Client-Platform': 'flutter-ios',
          'Authorization': 'Bearer ${widget.token}'
        },
      );
      
      if (response.statusCode == 200) {
        final childPosts = json.decode(response.body);
        setState(() {
          _post['child_posts'] = childPosts;
        });
      }
    } catch (e) {
      print('Error fetching child posts: $e');
    }
  }

  Future<void> _likePost(int postId) async {
    try {
      final response = await http.post(
        Uri.parse('${widget.url}/$likeUrl'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: {
          'object_type': 'post',
          'object_id': postId.toString(),
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _post['likesCount'] = data['likes_count'];
        });
      }
    } catch (e) {
      print('Error liking post: $e');
    }
  }

  Widget _buildMedia(List<dynamic> media) {
    if (media.isEmpty) return SizedBox.shrink();
    
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: media.length == 1 ? 1 : 2,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: 1.0,
      ),
      itemCount: media.length,
      itemBuilder: (context, index) {
        final mediaItem = media[index];
        final mediaUrl = '${widget.url}${mediaItem['file']}';
        
        return CachedNetworkImage(
          imageUrl: mediaUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: Colors.grey[300],
            child: Center(child: CircularProgressIndicator()),
          ),
          errorWidget: (context, url, error) => Icon(Icons.error),
        );
      },
    );
  }

  Widget _buildCommentItem(dynamic comment, int postId, {int depth = 0}) {
    final isExpanded = _expandedComments[comment['id']] ?? false;
    final hasReplies = comment['commentCount'] != null && comment['commentCount'] > 0;
    
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.only(left: 16.0 + (depth * 12.0), right: 8.0),
          leading: GestureDetector(
            onTap: () => ProfileDetailScreen(username: comment['user']['username']).launch(context),
            child: CircleAvatar(
              radius: 16.0,
              child: Text(comment['user']['username'][0].toUpperCase(), style: TextStyle(fontSize: 12.0)),
            ),
          ),
          title: Text(comment['user']['username'], style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold)),
          subtitle: Text(comment['content'], style: TextStyle(fontSize: 13.0)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(icon: Icon(Icons.thumb_up, size: 16.0), onPressed: () {}),
              Text('${comment['likesCount'] ?? 0}', style: TextStyle(fontSize: 12.0)),
              if (hasReplies) ...[
                SizedBox(width: 8.0),
                IconButton(
                  icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more, size: 16.0),
                  onPressed: () => setState(() => _expandedComments[comment['id']] = !isExpanded),
                ),
              ],
              SizedBox(width: 8.0),
              IconButton(
                icon: Icon(Icons.reply, size: 16.0),
                onPressed: () => setState(() {
                  _replyingToPostId = comment['id'];
                  _replyingToUsername = comment['user']['username'];
                }),
              ),
            ],
          ),
        ),
        if (hasReplies && isExpanded) ...[
          Padding(
            padding: EdgeInsets.only(left: 16.0 + (depth * 12.0)),
            child: Row(
              children: [
                Container(width: 2, color: Colors.grey[300], margin: EdgeInsets.only(right: 8)),
                Expanded(
                  child: Column(
                    children: [
                      if (comment['child_posts'] != null)
                        ...comment['child_posts'].map((reply) => _buildPostItem(reply, isChild: true, depth: depth + 1)),
                      TextButton(
                        onPressed: () => setState(() => _expandedComments[comment['id']] = false),
                        child: Text('Hide replies', style: TextStyle(fontSize: 12.0)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPostItem(dynamic post, {bool isChild = false, int depth = 0}) {
    // All posts can be toggled, main post starts expanded
    final bool isExpanded = _expandedPosts[post['id']] ?? (post['id'] == _post['id']);
    final childPosts = post['child_posts'] ?? [];
    final comments = post['comments'] ?? [];
    final totalReplies = childPosts.length + comments.length;
    final bool isMainPost = post['id'] == _post['id'];

    return GestureDetector(
      onTap: () {
        if (!isMainPost) {
          Navigator.push(context, MaterialPageRoute(
            builder: (context) => SVPostDetailScreen(post: post, token: widget.token, url: widget.url),
          ));
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16),
        margin: EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          borderRadius: radius(SVAppCommonRadius), 
          color: context.cardColor,
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 3, offset: Offset(0, 1))],
        ),
        child: Padding(
          padding: EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Post header
              Row(
                children: [
                  GestureDetector(
                    onTap: () => ProfileDetailScreen(username: post['user']['username']).launch(context),
                    child: CircleAvatar(
                      radius: 16.0,
                      child: Text(post['user']['username'][0].toUpperCase(), style: TextStyle(fontSize: 12.0)),
                    ),
                  ),
                  SizedBox(width: 12.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(post['user']['username'], style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold)),
                        Text(post['created_at'].toString().substring(0, 16).replaceFirst('T', ' '), 
                             style: TextStyle(fontSize: 11.0, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.0),
              Text(post['content'], style: TextStyle(fontSize: 14.0)),
              SizedBox(height: 12.0),
              _buildMedia(post['media']),
              SizedBox(height: 12.0),
              
              // Action buttons - FIXED OVERFLOW LAYOUT
              Container(
                constraints: BoxConstraints(minHeight: 40),
                child: Row(
                  children: [
                    // Left side: Action buttons
                    Expanded(
                      child: Wrap(
                        spacing: 4.0,
                        runSpacing: 4.0,
                        children: [
                          // Like button
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: BoxConstraints(minWidth: 36, minHeight: 36),
                                icon: Image.asset('images/socialv/icons/ic_Heart.png', height: 20, width: 20, color: context.iconColor),
                                onPressed: () => _likePost(post['id']),
                              ),
                              Text('${post['likesCount']}', style: TextStyle(fontSize: 12.0)),
                            ],
                          ),
                          
                          // Comment button
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: BoxConstraints(minWidth: 36, minHeight: 36),
                                icon: Image.asset('images/socialv/icons/ic_Chat.png', height: 20, width: 20, color: context.iconColor),
                                onPressed: () async {
                                  await _fetchChildPosts(post['id']);
                                  setState(() => _expandedPosts[post['id']] = !isExpanded);
                                },
                              ),
                              Text('$totalReplies', style: TextStyle(fontSize: 12.0)),
                            ],
                          ),
                          
                          // Share/Reply button
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(minWidth: 36, minHeight: 36),
                            icon: Image.asset('images/socialv/icons/ic_Send.png', height: 20, width: 20, color: context.iconColor),
                            onPressed: () => setState(() {
                              _replyingToPostId = post['id'];
                              _replyingToUsername = post['user']['username'];
                            }),
                          ),
                        ],
                      ),
                    ),
                    
                    // Right side: Show/Hide button for ALL posts with replies
                    if (totalReplies > 0)
                      Container(
                        margin: EdgeInsets.only(left: 8),
                        child: TextButton(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: Size(0, 30),
                          ),
                          onPressed: () => setState(() => _expandedPosts[post['id']] = !isExpanded),
                          child: Text(
                            isExpanded ? 'Hide Replies' : 'Show Replies', 
                            style: TextStyle(fontSize: 11.0),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              // Replies section - shown when expanded
              if (totalReplies > 0 && isExpanded) ...[
                Divider(thickness: 1.0),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text('Replies ($totalReplies)', style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold)),
                ),
                ...comments.map((comment) => _buildCommentItem(comment, post['id'], depth: depth)),
                ...childPosts.map((childPost) => _buildPostItem(childPost, isChild: true, depth: depth + 1)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> createPost(String content, {int? parentId}) async {
    if (content.trim().isEmpty) return;
    
    try {
      final Map<String, dynamic> postData = {'content': content};
      if (parentId != null) postData['parent'] = parentId;

      final response = await http.post(
        Uri.parse('${widget.url}/api/social-posts/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Client-Version': '1.0.0',
          'X-Client-Platform': 'flutter-ios',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: json.encode(postData),
      );

      if (response.statusCode == 201) {
        setState(() {
          _replyingToPostId = null;
          _replyingToUsername = '';
          _postController.clear();
        });
        toast('Posted successfully');
      } else {
        toast('Failed to create post: ${response.statusCode}');
      }
    } catch (e) {
      toast('Error creating post: $e');
    }
  }

  void _cancelReply() => setState(() {
    _replyingToPostId = null;
    _replyingToUsername = '';
  });

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    
    try {
      if (_post != null && _post['parentpk'] != null) {
        await _fetchParentPost(_post['parentpk']);
      }
    } catch (e) {
      print('Refresh error: $e');
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _fetchParentPost(int parentId) async {
    try {
      final response = await http.get(
        Uri.parse('${widget.url}/api/social-posts/$parentId/'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      
      if (response.statusCode == 200) {
        final parentPost = json.decode(response.body);
        await _fetchChildPostsForParent(parentId, parentPost);
      }
    } catch (e) {
      print('Error fetching parent post: $e');
    }
  }

  Future<void> _fetchChildPostsForParent(int parentId, dynamic parentPost) async {
    try {
      final response = await http.get(
        Uri.parse('${widget.url}/api/social-posts/?parent_pk=$parentId'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      
      if (response.statusCode == 200) {
        final childPosts = json.decode(response.body);
        final currentPostInThread = childPosts.firstWhere((child) => child['id'] == _post['id'], orElse: () => null);
        
        if (currentPostInThread != null) {
          setState(() {
            parentPost['child_posts'] = childPosts;
            _post = parentPost;
            _expandedPosts[_post['id']] = true;
          });
        }
      }
    } catch (e) {
      print('Error fetching child posts for parent: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Post Thread', style: boldTextStyle()),
        leading: IconButton(icon: Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      body: _isLoading ? Center(child: CircularProgressIndicator()) : GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! > 100) Navigator.pop(context);
        },
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          displacement: 40,
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(16),
            child: _buildPostItem(_post, isChild: false, depth: 0),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(bottom: 16.0),
        child: SVPostInputWidget(
          replyingToUsername: _replyingToUsername,
          replyingToPostId: _replyingToPostId,
          onCreatePost: createPost,
          onCancelReply: _cancelReply,
          focusNode: _postFocusNode,
          showOptions: false,
        ),
      ),
    );
  }
}