// lib/screens/home/components/SVPostInputWidget.dart
import 'package:bbdsocial/utils/SVCommon.dart';
import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:bbdsocial/utils/SVColors.dart';
import 'package:bbdsocial/utils/SVConstants.dart';

class SVPostInputWidget extends StatefulWidget {
  final String? replyingToUsername;
  final int? replyingToPostId;
  final Function(String content, {int? parentId}) onCreatePost;
  final VoidCallback onCancelReply;
  final FocusNode? focusNode;
  final bool showOptions;

  const SVPostInputWidget({
    Key? key,
    this.replyingToUsername,
    this.replyingToPostId,
    required this.onCreatePost,
    required this.onCancelReply,
    this.focusNode,
    this.showOptions = false,
  }) : super(key: key);

  @override
  _SVPostInputWidgetState createState() => _SVPostInputWidgetState();
}

class _SVPostInputWidgetState extends State<SVPostInputWidget> {
  final TextEditingController _postController = TextEditingController();
  final FocusNode _internalFocusNode = FocusNode();

  FocusNode get _effectiveFocusNode => widget.focusNode ?? _internalFocusNode;

  @override
  void initState() {
    super.initState();
    _setupReplyText();
  }

  @override
  void didUpdateWidget(covariant SVPostInputWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.replyingToUsername != oldWidget.replyingToUsername) {
      _setupReplyText();
    }
  }

  void _setupReplyText() {
    if (widget.replyingToUsername != null && widget.replyingToUsername!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_postController.text.isEmpty || !_postController.text.startsWith('@${widget.replyingToUsername}')) {
          _postController.text = '@${widget.replyingToUsername} ';
          _postController.selection = TextSelection.fromPosition(
            TextPosition(offset: _postController.text.length),
          );
        }
      });
    }
  }

  void _handlePostCreation() {
    final content = _postController.text.trim();
    print('Creating post with content: $content');
    if (content.isEmpty) {
      toast('Please enter some text');
      return;
    }

    widget.onCreatePost(
      content,
      parentId: widget.replyingToPostId,
    );
    
    _postController.clear();
    widget.onCancelReply();
  }

  void _handleTextChange(String text) {
    // Auto-remove @username if user deletes it
    if (widget.replyingToUsername != null && 
        widget.replyingToUsername!.isNotEmpty &&
        !text.startsWith('@${widget.replyingToUsername}')) {
      widget.onCancelReply();
    }
  }

  String get _hintText {
    if (widget.replyingToUsername != null && widget.replyingToUsername!.isNotEmpty) {
      return "Replying to @${widget.replyingToUsername}";
    }
    return "What's on your mind?";
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Reply Header Banner
        if (widget.replyingToUsername != null && widget.replyingToUsername!.isNotEmpty)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: SVAppColorPrimary.withOpacity(0.1),
              border: Border(
                bottom: BorderSide(color: SVAppColorPrimary.withOpacity(0.2)),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.reply, size: 16, color: SVAppColorPrimary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Replying to @${widget.replyingToUsername}",
                    style: TextStyle(
                      fontSize: 14,
                      color: SVAppColorPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: widget.onCancelReply,
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 14,
                      color: SVAppColorPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Main Input Area
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 2,
                blurRadius: 5,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _postController,
                      focus: _effectiveFocusNode,
                      textFieldType: TextFieldType.MULTILINE,
                      decoration: InputDecoration(
                        hintText: _hintText,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(SVAppCommonRadius),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(SVAppCommonRadius),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(SVAppCommonRadius),
                          borderSide: BorderSide(color: SVAppColorPrimary, width: 2),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        filled: true,
                        fillColor: context.scaffoldBackgroundColor,
                      ),
                      minLines: 1,
                      maxLines: 5,
                      onChanged: _handleTextChange,
                      onFieldSubmitted: (value) {
                        if (value.trim().isNotEmpty) {
                          _handlePostCreation();
                        }
                      },
                    ),
                  ),
                  SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: SVAppColorPrimary,
                      borderRadius: radius(SVAppCommonRadius),
                      boxShadow: [
                        BoxShadow(
                          color: SVAppColorPrimary.withOpacity(0.3),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(Icons.send, color: Colors.white, size: 24),
                      onPressed: _handlePostCreation,
                      tooltip: 'Post',
                    ),
                  ),
                ],
              ),
              
              // Additional options can be added here
              if (widget.showOptions) ..._buildAdditionalOptions(),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildAdditionalOptions() {
    return [
      SizedBox(height: 12),
      Row(
        children: [
          _buildOptionButton(Icons.photo_library, 'Photo'),
          SizedBox(width: 12),
          _buildOptionButton(Icons.videocam, 'Video'),
          SizedBox(width: 12),
          _buildOptionButton(Icons.emoji_emotions, 'Emoji'),
          Spacer(),
          _buildOptionButton(Icons.more_horiz, 'More'),
        ],
      ),
    ];
  }

  Widget _buildOptionButton(IconData icon, String label) {
    return GestureDetector(
      onTap: () {
        // Handle option tap
        toast('$label feature coming soon');
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: svGetBodyColor()),
            SizedBox(width: 4),
            Text(
              label,
              style: secondaryTextStyle(size: 12, color: svGetBodyColor()),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _postController.dispose();
    _internalFocusNode.dispose();
    super.dispose();
  }
}