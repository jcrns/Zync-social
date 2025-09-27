// lib/screens/profile/screens/ProfileDetail.dart
import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:bbdsocial/utils/SVCommon.dart';
import 'package:bbdsocial/utils/SVConstants.dart';
import 'package:bbdsocial/utils/SVColors.dart';
import 'package:bbdsocial/services/UserService.dart';

class ProfileDetailScreen extends StatefulWidget {
  final String username;

  const ProfileDetailScreen({Key? key, required this.username}) : super(key: key);

  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen> {
  static const String _baseUrl = 'http://10.0.0.158:5000';
  Map<String, dynamic>? userProfile;
  List<dynamic> userPosts = [];
  bool isLoading = true;
  bool isFollowing = false;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    setState(() => isLoading = true);
    
    try {
      final profileData = await UserService.getUserProfileByUsername(widget.username);
      
      setState(() {
        userProfile = profileData;
        userPosts = profileData['posts'] ?? [];
        // You might want to check if current user is following this profile
        isFollowing = false; // Update this based on your follow logic
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching user profile: $e");
      toast('Failed to load profile');
      setState(() => isLoading = false);
    }
  }

  void _handleFollow() {
    // Implement follow/unfollow logic here
    setState(() {
      isFollowing = !isFollowing;
    });
    // Call API to follow/unfollow user
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: svGetScaffoldColor(),
      appBar: AppBar(
        backgroundColor: svGetScaffoldColor(),
        title: Text('Profile', style: boldTextStyle(size: 20)),
        automaticallyImplyLeading: true,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: context.iconColor),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Profile Header
                  Container(
                    width: context.width(),
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundImage: userProfile?['profile']?['image'] != null
                              ? NetworkImage(_baseUrl + userProfile!['profile']['image'])
                              : AssetImage('images/default_avatar.png') as ImageProvider,
                        ),
                        16.height,
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${userProfile?['first_name'] ?? ''} ${userProfile?['last_name'] ?? ''}'.trim().isEmpty
                                  ? '${userProfile?['username']}'
                                  : '${userProfile?['first_name'] ?? ''} ${userProfile?['last_name'] ?? ''}',
                              style: boldTextStyle(size: 20),
                            ),

                            4.width,
                            // Add verification badge logic if needed
                          ],
                        ),
                        Text('@${userProfile?['username']}', 
                             style: secondaryTextStyle(color: svGetBodyColor())),
                        16.height,
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AppButton(
                              shapeBorder: RoundedRectangleBorder(borderRadius: radius(4)),
                              text: isFollowing ? 'Following' : 'Follow',
                              textStyle: boldTextStyle(
                                color: isFollowing ? Colors.black : Colors.white, 
                                size: 14
                              ),
                              onTap: _handleFollow,
                              elevation: 0,
                              color: isFollowing ? context.cardColor : SVAppColorPrimary,
                              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            ),
                            16.width,
                            AppButton(
                              shapeBorder: RoundedRectangleBorder(borderRadius: radius(4)),
                              text: 'Message',
                              textStyle: boldTextStyle(color: Colors.white, size: 14),
                              onTap: () {
                                // Navigate to message screen
                              },
                              elevation: 0,
                              color: SVAppColorPrimary,
                              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  16.height,
                  // Stats Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('Posts', style: secondaryTextStyle(color: svGetBodyColor(), size: 12)),
                          4.height,
                          Text('${userPosts.length}', style: boldTextStyle(size: 18)),
                        ],
                      ),
                      Column(
                        children: [
                          Text('Followers', style: secondaryTextStyle(color: svGetBodyColor(), size: 12)),
                          4.height,
                          Text('${userProfile?['profile']?['follower_count'] ?? 0}', style: boldTextStyle(size: 18)),
                        ],
                      ),
                      Column(
                        children: [
                          Text('Following', style: secondaryTextStyle(color: svGetBodyColor(), size: 12)),
                          4.height,
                          Text('${userProfile?['profile']?['following_count'] ?? 0}', style: boldTextStyle(size: 18)),
                        ],
                      ),
                    ],
                  ),
                  16.height,
                  // Bio Section
                  Container(
                    decoration: BoxDecoration(
                      color: context.cardColor,
                      borderRadius: radius(SVAppCommonRadius)
                    ),
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bio', style: boldTextStyle(size: 14)),
                        8.height,
                        Text(
                          userProfile?['profile']?['bio'] ?? 'No bio yet',
                          style: secondaryTextStyle(),
                        ),
                      ],
                    ),
                  ),
                  16.height,
                  // Posts Section
                  Container(
                    decoration: BoxDecoration(
                      color: context.cardColor,
                      borderRadius: radius(SVAppCommonRadius)
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Posts', style: boldTextStyle(size: 18)),
                        ),
                        userPosts.isEmpty
                            ? Text('No posts yet', style: secondaryTextStyle()).paddingAll(16)
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: NeverScrollableScrollPhysics(),
                                itemCount: userPosts.length,
                                itemBuilder: (context, index) {
                                  final post = userPosts[index];
                                  return Container(
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      border: Border(bottom: BorderSide(color: context.dividerColor))
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(post['title'], style: boldTextStyle()),
                                        8.height,
                                        Text(post['content'], style: primaryTextStyle()),
                                        8.height,
                                        Text(
                                          formatTime(post['created_at']),
                                          style: secondaryTextStyle(size: 12),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ],
                    ),
                  ),
                  16.height,
                ],
              ),
            ),
    );
  }
}