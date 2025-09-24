import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:bbdsocial/models/VideoEditorModel.dart';
import 'package:video_player/video_player.dart';

class SVVideoTimeline extends StatefulWidget {
  final VideoPlayerController controller;
  final TrimData trimData;
  final Function(int start, int end) onTrimChanged;

  const SVVideoTimeline({
    Key? key,
    required this.controller,
    required this.trimData,
    required this.onTrimChanged,
  }) : super(key: key);

  @override
  _SVVideoTimelineState createState() => _SVVideoTimelineState();
}

class _SVVideoTimelineState extends State<SVVideoTimeline> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      height: 100,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(Duration(milliseconds: widget.trimData.startValueMs)),
                style: secondaryTextStyle(color: Colors.white),
              ),
              Text(
                _formatDuration(Duration(milliseconds: widget.trimData.endValueMs)),
                style: secondaryTextStyle(color: Colors.white),
              ),
            ],
          ),
          8.height,
          Expanded(
            child: RangeSlider(
              values: RangeValues(
                widget.trimData.startValueMs.toDouble(),
                widget.trimData.endValueMs.toDouble(),
              ),
              min: 0,
              max: widget.trimData.maxDurationMs.toDouble(),
              onChanged: (values) {
                widget.onTrimChanged(values.start.toInt(), values.end.toInt());
                widget.controller.seekTo(Duration(milliseconds: values.start.toInt()));
              },
              activeColor: context.primaryColor,
              inactiveColor: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}