import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:bbdsocial/utils/SVConstants.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SVProfileHeaderComponent extends StatelessWidget {
  final String? profileImage;
  const SVProfileHeaderComponent({Key? key, this.profileImage}) : super(key: key);
  static const String _baseUrl = 'http://10.0.0.158:5000';

  @override
  Widget build(BuildContext context) {
    // The base URL for the background image is the same.
    // The profile image needs to be constructed with the baseUrl.
    final String profileImageUrl = profileImage != null ? '$_baseUrl$profileImage' : 'https://example.com/default-profile.png';
    // The background image is a local asset and remains unchanged.

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Image.asset(
                'images/socialv/backgroundImage.png',
                width: context.width(),
                height: 130,
                fit: BoxFit.cover,
              ).cornerRadiusWithClipRRectOnly(topLeft: SVAppCommonRadius.toInt(), topRight: SVAppCommonRadius.toInt()),
              Positioned(
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 2), borderRadius: radius(18)),
                  child: CachedNetworkImage(
                    imageUrl: profileImageUrl,
                    // height: 88,
                    // width: 88,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => CircularProgressIndicator(),
                    errorWidget: (context, url, error) => Icon(Icons.person),
                  ).cornerRadiusWithClipRRect(SVAppCommonRadius),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}