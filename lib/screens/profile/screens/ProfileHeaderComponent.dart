// In SVProfileHeaderComponent.dart
import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:bbdsocial/utils/SVCommon.dart';
import 'package:bbdsocial/utils/SVConstants.dart';

class SVProfileHeaderComponent extends StatelessWidget {
  final String? profileImage;

  const SVProfileHeaderComponent({Key? key, this.profileImage}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: context.width(),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: radiusOnly(bottomLeft: SVAppCommonRadius, bottomRight: SVAppCommonRadius),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              Image.asset('images/socialv/backgroundImage.png', height: 140, width: context.width(), fit: BoxFit.cover)
                  .cornerRadiusWithClipRRectOnly(bottomLeft: SVAppCommonRadius.toInt(), bottomRight: SVAppCommonRadius.toInt()),
              Positioned(
                bottom: -40,
                child: Container(
                  decoration: BoxDecoration(
                    color: context.cardColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 2),
                    ],
                  ),
                  child: profileImage != null
                      ? CircleAvatar(
                          radius: 40,
                          backgroundImage: NetworkImage(profileImage!),
                        )
                      : CircleAvatar(
                          radius: 40,
                          child: Icon(Icons.person, size: 40),
                        ),
                ),
              ),
            ],
          ),
          50.height,
        ],
      ),
    );
  }
}