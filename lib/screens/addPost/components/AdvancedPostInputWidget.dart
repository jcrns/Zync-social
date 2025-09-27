// lib/screens/home/components/SVAdvancedPostInputWidget.dart
// ignore_for_file: unused_field

import 'package:bbdsocial/utils/SVCommon.dart';
import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:bbdsocial/utils/SVColors.dart';
import 'package:bbdsocial/utils/SVConstants.dart';

class SVAdvancedPostInputWidget extends StatefulWidget {
  final String? replyingToUsername;
  final int? replyingToPostId;
  final Function(String content, {int? parentId}) onCreatePost;
  final VoidCallback onCancelReply;
  final FocusNode? focusNode;
  final bool showOptions;
  final List<String>? mentionSuggestions;
  final Function(String query)? onMentionQuery;

  const SVAdvancedPostInputWidget({
    Key? key,
    this.replyingToUsername,
    this.replyingToPostId,
    required this.onCreatePost,
    required this.onCancelReply,
    this.focusNode,
    this.showOptions = false,
    this.mentionSuggestions,
    this.onMentionQuery,
  }) : super(key: key);

  @override
  _SVAdvancedPostInputWidgetState createState() => _SVAdvancedPostInputWidgetState();
}

class _SVAdvancedPostInputWidgetState extends State<SVAdvancedPostInputWidget> {
  final TextEditingController _postController = TextEditingController();
  final FocusNode _internalFocusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _showMentionSuggestions = false;
  List<String> _filteredSuggestions = [];

  FocusNode get _effectiveFocusNode => widget.focusNode ?? _internalFocusNode;

  @override
  void initState() {
    super.initState();
    _setupReplyText();
    _postController.addListener(_handleTextChanges);
  }

  @override
  void didUpdateWidget(covariant SVAdvancedPostInputWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.replyingToUsername != oldWidget.replyingToUsername) {
      _setupReplyText();
    }
    
    if (widget.mentionSuggestions != oldWidget.mentionSuggestions) {
      _filterMentionSuggestions(_postController.text);
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

  void _handleTextChanges() {
    final text = _postController.text;
    
    // Handle @mention detection
    _handleMentionDetection(text);
    
    // Auto-remove @username if user deletes it
    if (widget.replyingToUsername != null && 
        widget.replyingToUsername!.isNotEmpty &&
        !text.startsWith('@${widget.replyingToUsername}')) {
      widget.onCancelReply();
    }
  }

  void _handleMentionDetection(String text) {
    final lastWord = text.split(' ').last;
    
    if (lastWord.startsWith('@') && lastWord.length > 1) {
      final query = lastWord.substring(1);
      _showMentionOverlay();
      _filterMentionSuggestions(query);
      
      if (widget.onMentionQuery != null) {
        widget.onMentionQuery!(query);
      }
    } else {
      _hideMentionOverlay();
    }
  }

  void _filterMentionSuggestions(String query) {
    if (widget.mentionSuggestions == null) return;
    
    setState(() {
      _filteredSuggestions = widget.mentionSuggestions!
          .where((username) => username.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  void _showMentionOverlay() {
    if (_overlayEntry != null) return;
    
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: MediaQuery.of(context).size.width * 0.8,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, 50),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _filteredSuggestions.length,
                itemBuilder: (context, index) {
                  final username = _filteredSuggestions[index];
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 16,
                      child: Text(username[0].toUpperCase()),
                    ),
                    title: Text('@$username'),
                    onTap: () => _insertMention(username),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    
    if (_overlayEntry != null) {
      Overlay.of(context).insert(_overlayEntry!);
      setState(() => _showMentionSuggestions = true);
    }
  }

  void _hideMentionOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
      setState(() => _showMentionSuggestions = false);
    }
  }

  void _insertMention(String username) {
    final text = _postController.text;
    final lastAtPos = text.lastIndexOf('@');
    
    if (lastAtPos != -1) {
      final newText = text.substring(0, lastAtPos) + '@$username ';
      _postController.text = newText;
      _postController.selection = TextSelection.fromPosition(
        TextPosition(offset: newText.length),
      );
    }
    
    _hideMentionOverlay();
  }

  void _handlePostCreation() {
    final content = _postController.text.trim();
    if (content.isEmpty) return;

    widget.onCreatePost(
      content,
      parentId: widget.replyingToPostId,
    );
    
    _postController.clear();
    _hideMentionOverlay();
    widget.onCancelReply();
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
                  onPressed: () {
                    _hideMentionOverlay();
                    widget.onCancelReply();
                  },
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
        CompositedTransformTarget(
          link: _layerLink,
          child: Container(
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
                
                if (widget.showOptions) ..._buildAdditionalOptions(),
              ],
            ),
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
      onTap: () => toast('$label feature coming soon'),
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
    _postController.removeListener(_handleTextChanges);
    _postController.dispose();
    _internalFocusNode.dispose();
    _hideMentionOverlay();
    super.dispose();
  }
}