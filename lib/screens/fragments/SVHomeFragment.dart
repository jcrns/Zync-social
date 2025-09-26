import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:bbdsocial/screens/home/components/SVHomeDrawerComponent.dart';
import 'package:bbdsocial/screens/fragments/SocialFragment.dart';
import 'package:bbdsocial/screens/home/components/SVStoryComponent.dart';
import 'package:bbdsocial/utils/SVCommon.dart';


class SVHomeFragment extends StatefulWidget {
  @override
  State<SVHomeFragment> createState() => _SVHomeFragmentState();
}

class _SVHomeFragmentState extends State<SVHomeFragment> {
  var scaffoldKey = GlobalKey<ScaffoldState>();

  File? image;

  @override
  void initState() {
    super.initState();
    afterBuildCreated(() {
      setStatusBarColor(svGetScaffoldColor());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: svGetScaffoldColor(),
      appBar: AppBar(
        backgroundColor: svGetScaffoldColor(),
        elevation: 0,
        leading: IconButton(
          icon: Image.asset(
            'images/socialv/icons/ic_More.png',
            width: 18,
            height: 18,
            fit: BoxFit.cover,
            color: context.iconColor,
          ),
          onPressed: () {
            scaffoldKey.currentState?.openDrawer();
          },
        ),
        title: Text('Home', style: boldTextStyle(size: 18)),
        actions: [
          IconButton(
            icon: Image.asset(
              'images/socialv/icons/ic_Camera.png',
              width: 24,
              height: 22,
              fit: BoxFit.fill,
              color: context.iconColor,
            ),
            onPressed: () async {
              image = await svGetImageSource();
            },
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: context.cardColor,
        child: SVHomeDrawerComponent(),
      ),
      // Use a Column with Expanded for the feed so the social fragment
      // receives bounded height. Embedding a full-screen Scaffold inside a
      // SingleChildScrollView caused unbounded height to be passed down and
      // produced the RenderCustomMultiChildLayoutBox/infinite size error.
      body: Column(
        children: [
          // 16.height,
          // SVStoryComponent(),
          // 16.height,
          // Give the social fragment the remaining space
          Expanded(child: SVSocialFragment()),
          16.height,
        ],
      ),
    );
  }
}
