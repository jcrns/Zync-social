import 'dart:convert';
import 'package:bbdsocial/screens/addPost/components/SVPostOptionsComponent.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:bbdsocial/screens/addPost/components/PostDetailScreen.dart';
import 'package:bbdsocial/utils/SVCommon.dart';
import 'package:bbdsocial/utils/SVConstants.dart';
import 'package:bbdsocial/utils/SVColors.dart';
import 'package:bbdsocial/screens/addPost/components/PostInputWidget.dart';

class SVSocialFragment extends StatefulWidget {
  const SVSocialFragment({Key? key}) : super(key: key);

  @override
  State<SVSocialFragment> createState() => _SVSocialFragmentState();
}

class _SVSocialFragmentState extends State<SVSocialFragment> {
  static const String url = 'http://10.0.0.158:5000';
  static const String apiUrl = '$url/api/social-posts/';
  static const String likeUrl = '$url/like/';
  final TextEditingController _postController = TextEditingController();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  String get bearerToken => 'Bearer $token';
  bool _isLoading = false;
  List<dynamic> _posts = [];
  Map<int, bool> _expandedPosts = {};
  Map<int, bool> _expandedComments = {};
  int? _replyingToPostId;
  String _replyingToUsername = '';

  late String token;
  final FocusNode _postFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    token = await getStringAsync('auth_token', defaultValue: '');
    if (token.isNotEmpty) {
      print("token loaded: $token");
      fetchPosts();
    } else {
      print("No token found in secure storage.");
    }
  }

  @override
  void dispose() {
    _postFocusNode.dispose();
    super.dispose();
  }

  Future<void> fetchChildPosts(int postId) async {
    try {
      final response = await http.get(
        Uri.parse('$apiUrl?parent_pk=$postId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Client-Version': '1.0.0',
          'X-Client-Platform': 'flutter-ios',
          'Authorization': 'Token $token'
        },
      );
      
      if (response.statusCode == 200) {
        final childPosts = json.decode(response.body);
        setState(() {
          final postIndex = _posts.indexWhere((post) => post['id'] == postId);
          if (postIndex != -1) {
            _posts[postIndex]['child_posts'] = childPosts;
          }
        });
      }
    } catch (e) {
      print('Error fetching child posts: $e');
    }
  }

  Future<void> fetchPosts() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Client-Version': '1.0.0',
          'X-Client-Platform': 'flutter-ios',
          'Authorization': 'Bearer $token'
        },
      );
      if (response.statusCode == 200) {
        print('Posts fetched: ${response.body}');
        setState(() {
          _posts = json.decode(response.body);
          for (var post in _posts) {
            _expandedPosts[post['id']] = false;
          }
        });
      }
    } catch (e) {
      print('Error fetching posts: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> createPost(String content, {int? parentId}) async {
    if (content.trim().isEmpty) return;
    try {
      final Map<String, dynamic> postData = {'content': content};
      if (parentId != null) {
        postData['parent'] = parentId;
      }
      
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Client-Version': '1.0.0',
          'X-Client-Platform': 'flutter-ios',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(postData),
      );
      if (response.statusCode == 201) {
        _postController.clear();
        setState(() {
          _replyingToPostId = null;
          _replyingToUsername = '';
        });
        fetchPosts();
        print("response.body");
        print(response.body);

        final responseData = json.decode(response.body);
        final post = responseData;
        // _posts.insert(0, responseData);

        print("Opening newly created post detail view.");

        // final post = _posts[_posts.length - 1];
        print('New post: $post');
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SVPostDetailScreen(
              post: post,
              token: token,
              url: url,
            ),
          ),
        );
      }
    } catch (e) {
      print('Error creating post: $e');
    }
  }

  Future<void> likePost(int postId) async {
    try {
      final response = await http.post(
        Uri.parse(likeUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Token $token',
        },
        body: {
          'object_type': 'post',
          'object_id': postId.toString(),
        },
      );
      
      if (response.statusCode == 200) {
        setState(() {
          final postIndex = _posts.indexWhere((post) => post['id'] == postId);
          if (postIndex != -1) {
            final data = json.decode(response.body);
            _posts[postIndex]['likesCount'] = data['likes_count'];
          }
        });
      }
    } catch (e) {
      print('Error liking post: $e');
    }
  }

// Replace the entire _buildMedia function with this new one

Widget _buildMedia(List<dynamic> media) {
  if (media.isEmpty) return SizedBox.shrink();

  // Using a LayoutBuilder gives us the available width for accurate calculations.
  return LayoutBuilder(
    builder: (context, constraints) {
      double totalWidth = constraints.maxWidth;
      int crossAxisCount = media.length == 1 ? 1 : 2;
      double spacing = 4.0;

      // Calculate the size of each item based on available width
      double itemWidth = (totalWidth - (spacing * (crossAxisCount - 1))) / crossAxisCount;

      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: media.map<Widget>((mediaItem) {
          final mediaUrl = '$url${mediaItem['file']}';
          
          return SizedBox(
            // Use calculated width and height for a perfect square grid
            width: itemWidth,
            height: itemWidth,
            child: ClipRRect( // Use ClipRRect to ensure the image respects the border radius
              borderRadius: BorderRadius.circular(SVAppCommonRadius),
              child: CachedNetworkImage(
                imageUrl: mediaUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[300],
                  child: Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Icon(Icons.error),
              ),
            ),
          );
        }).toList(),
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
        contentPadding: EdgeInsets.only(
          left: 16.0 + (depth * 12.0),
          right: 8.0,
        ),
        leading: CircleAvatar(
          radius: 16.0,
          child: Text(
            comment['user']['username'][0].toUpperCase(),
            style: TextStyle(fontSize: 12.0),
          ),
        ),
        title: Text(
          comment['user']['username'],
          style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          comment['content'],
          style: TextStyle(fontSize: 13.0),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.thumb_up, size: 16.0),
              onPressed: () {}, // Implement comment like if needed
            ),
            Text('${comment['likesCount'] ?? 0}', style: TextStyle(fontSize: 12.0)),
            SizedBox(width: 8.0),
            if (hasReplies)
              IconButton(
                icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more, size: 16.0),
                onPressed: () {
                  setState(() {
                    _expandedComments[comment['id']] = !isExpanded;
                  });
                },
              ),
            SizedBox(width: 8.0),
            IconButton(
              icon: Icon(Icons.reply, size: 16.0),
              onPressed: () {
                // setState(() {
                //   _replyingToPostId = postId;
                //   _replyingToUsername = comment['user']['username'];
                //   _postController.text = '@$_replyingToUsername ';
                //   _postFocusNode.requestFocus();
                // });
                
              },
            ),
          ],
        ),
      ),
      if (hasReplies && isExpanded) ...[
        Padding(
          padding: EdgeInsets.only(left: 16.0 + (depth * 12.0)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start, // Good practice for alignment
            children: [
              Container(
                width: 2,
                // Make the line connect properly by giving it a height or making it part of the child
                // This is a UI suggestion, not related to the crash fix.
                color: Colors.grey[300],
                margin: EdgeInsets.only(right: 8),
              ),
              Expanded(
                child: Column(
                  // FIX APPLIED HERE:
                  mainAxisSize: MainAxisSize.min, 
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (comment['child_posts'] != null)
                      ...comment['child_posts'].map((reply) =>
                        _buildPostItem(reply, isChild: true, depth: depth + 1)
                      ).toList(),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _expandedComments[comment['id']] = false;
                        });
                      },
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
    final isExpanded = _expandedPosts[post['id']] ?? false;
    final childPosts = post['child_posts'] ?? [];
    final comments = post['comments'] ?? [];
    final totalReplies = childPosts.length + comments.length;
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SVPostDetailScreen(
              post: post,
              token: token,
              url: url,
            ),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16),
        margin: EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          borderRadius: radius(SVAppCommonRadius), 
          color: context.cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: SVAppColorPrimary.withOpacity(0.2),
                      child: Text(
                        post['user']['username'][0].toUpperCase(),
                        style: boldTextStyle(size: 14, color: SVAppColorPrimary),
                      ),
                    ),
                    12.width,
                    Text(post['user']['username'], style: boldTextStyle()),
                  ],
                ).paddingSymmetric(horizontal: 16),
                Row(
                  children: [
                    Text(
                      post['created_at'].toString().substring(0, 16).replaceFirst('T', ' '),
                      style: secondaryTextStyle(color: svGetBodyColor(), size: 12),
                    ),
                    IconButton(
                      onPressed: () {}, 
                      icon: Icon(Icons.more_horiz, color: svGetBodyColor())
                    ),
                  ],
                ).paddingSymmetric(horizontal: 8),
              ],
            ),
            16.height,
            if (post['content'] != null && post['content'].isNotEmpty)
              svRobotoText(
                text: post['content'],
                textAlign: TextAlign.start,
              ).paddingSymmetric(horizontal: 16),
            if (post['content'] != null && post['content'].isNotEmpty) 16.height,
            _buildMedia(post['media']).paddingSymmetric(horizontal: 16),
            16.height,
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Image.asset(
                            'images/socialv/icons/ic_Heart.png',
                            height: 18, // Reduced size
                            width: 18,  // Reduced size
                            color: context.iconColor,
                          ),
                          onPressed: () => likePost(post['id']),
                          padding: EdgeInsets.all(4), // Reduced padding
                          constraints: BoxConstraints(maxWidth: 30, maxHeight: 30), // Tighter constraints
                        ),
                        Text(
                          '${post['likesCount'] ?? 0}', 
                          style: secondaryTextStyle(
                            color: svGetBodyColor(),
                            size: 12 // Smaller text
                          )
                        ),
                        SizedBox(width: 4), // Reduced spacing
                        IconButton(
                          icon: Image.asset(
                            'images/socialv/icons/ic_Chat.png',
                            height: 18,
                            width: 18,
                            color: context.iconColor,
                          ),
                          onPressed: () async {
                            await fetchChildPosts(post['id']);
                            setState(() {
                              _expandedPosts[post['id']] = !isExpanded;
                            });
                          },
                          padding: EdgeInsets.all(4),
                          constraints: BoxConstraints(maxWidth: 30, maxHeight: 30),
                        ),
                        Text(
                          '$totalReplies', 
                          style: secondaryTextStyle(
                            color: svGetBodyColor(),
                            size: 12
                          )
                        ),
                        SizedBox(width: 4),
                        IconButton(
                          icon: Image.asset(
                            'images/socialv/icons/ic_Send.png',
                            height: 18,
                            width: 18,
                            color: context.iconColor,
                          ),
                          onPressed: () {
                            setState(() {
                              _replyingToPostId = post['id'];
                              _replyingToUsername = post['user']['username'];
                              _postController.text = '@${_replyingToUsername} ';
                              _postFocusNode.requestFocus();
                            });
                          },
                          padding: EdgeInsets.all(4),
                          constraints: BoxConstraints(maxWidth: 30, maxHeight: 30),
                        ),
                      ],
                    ),
                  ),
                ),
                if (totalReplies > 0)
                  Flexible(
                    fit: FlexFit.loose,
                    child: Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            _expandedPosts[post['id']] = !isExpanded;
                          });
                        },
                        child: Text(
                          isExpanded ? 'Hide' : 'Show',
                          style: secondaryTextStyle(
                            color: SVAppColorPrimary, 
                            size: 12
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ).paddingSymmetric(horizontal: 8), // Reduced padding from 16 to 8
            if (isExpanded && totalReplies > 0) ...[
              Divider(indent: 16, endIndent: 16, height: 20),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Replies ($totalReplies)',
                  style: boldTextStyle(size: 14),
                ),
              ),
              ...comments.map((comment) => _buildCommentItem(comment, post['id'], depth: depth)).toList(),
              ...childPosts.map((childPost) => _buildPostItem(childPost, isChild: true, depth: depth + 1)).toList(),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double availableHeight = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : MediaQuery.of(context).size.height;

          return ConstrainedBox(
            constraints: BoxConstraints(minHeight: availableHeight),
            child: Column(
              children: [
                Expanded(
                  child: _isLoading
                      ? Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                          onRefresh: fetchPosts,
                          child: ListView.builder(
                            padding: EdgeInsets.all(16),
                            itemCount: _posts.length,
                            itemBuilder: (context, index) => _buildPostItem(_posts[index]),
                          ),
                        ),
                ),
                
                // Use the new component
                SVPostInputWidget(
                  replyingToUsername: _replyingToUsername,
                  replyingToPostId: _replyingToPostId,
                  onCreatePost: createPost,
                  onCancelReply: () {
                    setState(() {
                      _replyingToPostId = null;
                      _replyingToUsername = '';
                    });
                  },
                  showOptions: isKeyboardVisible,
                ),

                // SVAdvancedPostInputWidget(
                //   replyingToUsername: _replyingToUsername,
                //   replyingToPostId: _replyingToPostId,
                //   onCreatePost: createPost,
                //   onCancelReply: cancelReply,
                //   mentionSuggestions: _userSuggestions,
                //   onMentionQuery: (query) => searchUsers(query),
                // )

                
                // Only show SVPostOptionsComponent when keyboard is visible
                if (isKeyboardVisible) SVPostOptionsComponent(),
              ],
            ),
          );
        },
      ),
    );
  }

  // Update the reply button in _buildPostItem and _buildCommentItem:
  // Change from:
  // onPressed: () {
  //   setState(() {
  //     _replyingToPostId = post['id'];
  //     _replyingToUsername = post['user']['username'];
  //     _postController.text = '@${_replyingToUsername} ';
  //     _postFocusNode.requestFocus();
  //   });
  // }
  
  // To:
  // onPressed: () {
  //   setState(() {
  //     _replyingToPostId = post['id'];
  //     _replyingToUsername = post['user']['username'];
  //   });
  // }
}