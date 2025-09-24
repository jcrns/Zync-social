import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:bbdsocial/utils/SVColors.dart';

class SVSoundSelectionComponent extends StatelessWidget {
  const SVSoundSelectionComponent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // In a real app, this list would come from your Django API
    final mockSounds = [
      {'title': 'Epic Cinematic', 'artist': 'SoundFX Pro', 'duration': '2:30'},
      {'title': 'Chill Lo-fi Beat', 'artist': 'StudyVibes', 'duration': '3:15'},
      {'title': 'Upbeat Pop', 'artist': 'HappyTunes', 'duration': '1:45'},
      {'title': 'Acoustic Guitar', 'artist': 'IndieFolk', 'duration': '2:55'},
    ];

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: radiusOnly(topLeft: 16, topRight: 16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Choose a Sound', style: boldTextStyle(size: 20)).center(),
          16.height,
          AppTextField(
            textFieldType: TextFieldType.OTHER,
            decoration: InputDecoration(
              hintText: 'Search for sounds...',
              prefixIcon: Icon(Icons.search, color: context.iconColor),
              border: OutlineInputBorder(borderRadius: radius(8)),
            ),
          ),
          16.height,
          Expanded(
            child: ListView.builder(
              itemCount: mockSounds.length,
              itemBuilder: (context, index) {
                final sound = mockSounds[index];
                return ListTile(
                  leading: Icon(Icons.music_note, color: SVAppColorPrimary),
                  title: Text(sound['title']!, style: primaryTextStyle()),
                  subtitle: Text(sound['artist']!, style: secondaryTextStyle()),
                  trailing: Text(sound['duration']!, style: secondaryTextStyle()),
                  onTap: () {
                    toast('Selected ${sound['title']}');
                    // Return the selected sound to the caller
                    Navigator.pop(context, sound);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}