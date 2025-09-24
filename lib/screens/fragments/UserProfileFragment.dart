import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:bbdsocial/main.dart';
import 'package:bbdsocial/screens/profile/components/SVProfileHeaderComponent.dart';
import 'package:bbdsocial/screens/profile/components/SVProfilePostsComponent.dart';
import 'package:bbdsocial/utils/SVCommon.dart';
import 'package:bbdsocial/utils/SVConstants.dart';
import 'package:bbdsocial/utils/SVColors.dart';
import 'package:bbdsocial/services/UserService.dart';
// import 'package:bbdsocial/screens/CoinPage.dart';
import 'package:bbdsocial/screens/profile/screens/EditProfileScreen.dart';

class SVProfileFragment extends StatefulWidget {
  const SVProfileFragment({Key? key}) : super(key: key);

  @override
  State<SVProfileFragment> createState() => _SVProfileFragmentState();
}

class _SVProfileFragmentState extends State<SVProfileFragment> {
  static const String _baseUrl = 'http://10.0.0.158:8000';
  Map<String, dynamic>? userProfile;
  Map<String, int>? coinBalances;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    setStatusBarColor(Colors.transparent);
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    setState(() => isLoading = true);
    
    try {
      final profile = await UserService.getUserProfile();
      final coins = await UserService.getCoinBalances();

      print('\n\n\nFetched profile: $profile');
      print('Fetched coins: $coins');
      setState(() {
        userProfile = profile;
        coinBalances = coins;
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching user data: $e");
      toast('Failed to load profile data');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) => Scaffold(
        backgroundColor: svGetScaffoldColor(),
        appBar: AppBar(
          backgroundColor: svGetScaffoldColor(),
          title: Text('Profile', style: boldTextStyle(size: 20)),
          automaticallyImplyLeading: false,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: context.iconColor),
          actions: [
            Switch(
              onChanged: (val) {
                appStore.toggleDarkMode(value: val);
              },
              value: appStore.isDarkMode,
              activeThumbColor: SVAppColorPrimary,
            ),
          ],
        ),
        body: isLoading
            ? Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  children: [
                    SVProfileHeaderComponent(
                      profileImage: userProfile?['image'] != null 
                          ? _baseUrl + userProfile!['image']
                          : null,
                    ),
                    16.height,
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(userProfile?['username'] ?? 'User Name', style: boldTextStyle(size: 20)),
                        4.width,
                        if (userProfile?['is_verified'] == true)
                          Image.asset('images/socialv/icons/ic_TickSquare.png', height: 14, width: 14, fit: BoxFit.cover),
                      ],
                    ),
                    Text('@${userProfile?['username']?.toLowerCase() ?? 'username'}', 
                         style: secondaryTextStyle(color: svGetBodyColor())),
                    24.height,
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AppButton(
                          shapeBorder: RoundedRectangleBorder(borderRadius: radius(4)),
                          text: 'Edit Profile',
                          textStyle: boldTextStyle(color: Colors.white, size: 14),
                          onTap: () => SVEditProfileScreen(profileData: userProfile).launch(context)
                              .then((_) => _fetchUserData()),
                          elevation: 0,
                          color: SVAppColorPrimary,
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        ),
                        16.width,
                        AppButton(
                          shapeBorder: RoundedRectangleBorder(borderRadius: radius(4)),
                          text: 'Coins',
                          textStyle: boldTextStyle(color: Colors.white, size: 14),
                          // onTap: () => CoinPage().launch(context),
                          elevation: 0,
                          color: SVAppColorPrimary,
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        ),
                      ],
                    ),
                    24.height,
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text('Posts', style: secondaryTextStyle(color: svGetBodyColor(), size: 12)),
                            4.height,
                            Text('${userProfile?['post_count'] ?? 0}', style: boldTextStyle(size: 18)),
                          ],
                        ),
                        Column(
                          children: [
                            Text('Followers', style: secondaryTextStyle(color: svGetBodyColor(), size: 12)),
                            4.height,
                            Text('${userProfile?['follower_count'] ?? 0}', style: boldTextStyle(size: 18)),
                          ],
                        ),
                        Column(
                          children: [
                            Text('Following', style: secondaryTextStyle(color: svGetBodyColor(), size: 12)),
                            4.height,
                            Text('${userProfile?['following_count'] ?? 0}', style: boldTextStyle(size: 18)),
                          ],
                        ),
                        Column(
                          children: [
                            Text('Coins', style: secondaryTextStyle(color: svGetBodyColor(), size: 12)),
                            4.height,
                            Text('${coinBalances?['total_coins'] ?? 0}', style: boldTextStyle(size: 18)),
                          ],
                        ),
                      ],
                    ),
                    16.height,
                    Container(
                      decoration: BoxDecoration(color: context.cardColor, borderRadius: radius(SVAppCommonRadius)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          16.height,
                          Text('Bio', style: boldTextStyle(size: 14)).paddingSymmetric(horizontal: 16),
                          8.height,
                          Text(
                            userProfile?['bio'] ?? 'No bio yet',
                            style: secondaryTextStyle(),
                            textAlign: TextAlign.center,
                          ).paddingSymmetric(horizontal: 16),
                          16.height,
                        ],
                      ),
                    ),
                    16.height,
                    // SVProfilePostsComponent(userId: userProfile?['id']),
                    // 16.height,
                    Container(
                      decoration: BoxDecoration(color: context.cardColor, borderRadius: radius(SVAppCommonRadius)),
                      child: Column(
                        children: [
                          ListTile(
                            leading: Icon(Icons.settings, color: context.iconColor),
                            title: Text('Settings', style: primaryTextStyle()),
                            trailing: Icon(Icons.arrow_forward_ios, size: 16, color: context.iconColor),
                            onTap: () {
                              // Navigate to settings page
                            },
                          ),
                          Divider(height: 0),
                          ListTile(
                            leading: Icon(Icons.logout, color: Colors.red),
                            title: Text('Logout', style: primaryTextStyle(color: Colors.red)),
                            onTap: () {
                              showConfirmDialogCustom(
                                context,
                                cancelable: false,
                                title: "Are you sure you want to logout?",
                                dialogType: DialogType.CONFIRMATION,
                                onCancel: (v) => finish(context),
                                onAccept: (v) {
                                  // Implement logout logic
                                  // Navigate to login screen
                                },
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
      ),
    );
  }
}