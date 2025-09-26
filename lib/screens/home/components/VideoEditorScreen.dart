import 'dart:io';
import 'package:bbdsocial/services/UserService.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:bbdsocial/models/VideoEditorModel.dart' show TextOverlay, TrimData, CropData;
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:bbdsocial/screens/home/components/SoundSelection.dart';
import 'package:bbdsocial/screens/home/components/VideoTimeline.dart';
import 'package:bbdsocial/utils/SVColors.dart';
import 'package:video_player/video_player.dart';

enum EditorTool { none, trim, text, crop }

class _CropPainter extends CustomPainter {
  final Rect cropRect;

  _CropPainter(this.cropRect);

  @override
  void paint(Canvas canvas, Size size) {
    final outsidePaint = Paint()..color = Colors.black45;
    final full = Rect.fromLTWH(0, 0, size.width, size.height);
    final path = Path()
      ..addRect(full)
      ..addRect(cropRect);
    canvas.drawPath(path, outsidePaint..style = PaintingStyle.fill);

    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRect(cropRect, border);

    final gridPaint = Paint()
      ..color = Colors.white70
      ..strokeWidth = 1.0;

    final dx = cropRect.width / 3;
    final dy = cropRect.height / 3;
    for (int i = 1; i <= 2; i++) {
      final x = cropRect.left + dx * i;
      canvas.drawLine(Offset(x, cropRect.top), Offset(x, cropRect.bottom), gridPaint);
      final y = cropRect.top + dy * i;
      canvas.drawLine(Offset(cropRect.left, y), Offset(cropRect.right, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class SVVideoEditorScreen extends StatefulWidget {
  final String videoPath;

  const SVVideoEditorScreen({Key? key, required this.videoPath}) : super(key: key);

  @override
  _SVVideoEditorScreenState createState() => _SVVideoEditorScreenState();
}

class _SVVideoEditorScreenState extends State<SVVideoEditorScreen> {
  late VideoPlayerController _controller;
  EditorTool _activeTool = EditorTool.none;
  List<TextOverlay> _textOverlays = [];
  TrimData? _trimData;
  Map<String, String>? _selectedSound;

  GlobalKey _videoKey = GlobalKey();
  GlobalKey _aspectKey = GlobalKey();

  // Crop state
  bool _isCropping = false;
  Rect? _cropRect;
  CropData? _appliedCrop;
  String? _activeHandle;
  bool _isProcessingCrop = false;

  // Trim state
  bool _isTrimming = false;
  bool _isProcessingTrim = false;

  // State variable to control the visibility of the indicator
  bool _showCroppedIndicator = false;

  // Text formatting
  Color _selectedColor = Colors.white;
  double _selectedFontSize = 24.0;
  String _selectedFont = 'Roboto';
  FontWeight _selectedFontWeight = FontWeight.bold;

  bool _isUploading = false;
  String? _uploadError;

  // New state variable to track if video is playing
  bool _isPlaying = false;
  bool _showPlayButton = true;

  // Store original video path for resetting trim
  late String _originalVideoPath;

  @override
  void initState() {
    super.initState();
    _originalVideoPath = widget.videoPath;
    _controller = VideoPlayerController.file(File(widget.videoPath))
      ..initialize().then((_) {
        setState(() {
          _controller.setLooping(true);
          _trimData = TrimData(
            startValueMs: 0,
            endValueMs: _controller.value.duration.inMilliseconds,
            maxDurationMs: _controller.value.duration.inMilliseconds,
          );
          // Auto-play the video when initialized
          _controller.play();
          _isPlaying = true;
          
          // Hide play button after 2 seconds if video is playing
          Future.delayed(Duration(seconds: 2), () {
            if (mounted && _isPlaying) {
              setState(() {
                _showPlayButton = false;
              });
            }
          });
        });
      });
    
    // Listen to video player state changes
    _controller.addListener(_videoListener);
    _checkAndStartTimer();
  }

  void _videoListener() {
    if (_controller.value.isInitialized) {
      final isPlaying = _controller.value.isPlaying;
      if (isPlaying != _isPlaying) {
        setState(() {
          _isPlaying = isPlaying;
          if (!isPlaying) {
            _showPlayButton = true;
          } else {
            Future.delayed(Duration(milliseconds: 500), () {
              if (mounted && _isPlaying) {
                setState(() {
                  _showPlayButton = false;
                });
              }
            });
          }
        });
      }

      // Handle trim playback
      if (_isTrimming && _trimData != null && isPlaying) {
        final currentPosition = _controller.value.position.inMilliseconds;
        if (currentPosition >= _trimData!.endValueMs) {
          _controller.seekTo(Duration(milliseconds: _trimData!.startValueMs));
        }
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_videoListener);
    _controller.dispose();
    super.dispose();
  }

  // Toggle play/pause function
  void _togglePlayPause() {
    if (_isProcessingCrop || _isProcessingTrim) return;
    
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
        _showPlayButton = true;
      } else {
        _controller.play();
        _showPlayButton = false;
        
        Future.delayed(Duration(seconds: 2), () {
          if (mounted && _controller.value.isPlaying) {
            setState(() {
              _showPlayButton = false;
            });
          }
        });
      }
    });
  }

  // Simplified upload method using UserService
  Future<void> _uploadVideo() async {
    if (_isUploading) return;

    setState(() {
      _isUploading = true;
      _uploadError = null;
    });

    try {
      String videoPath = _controller.dataSource;
      if (videoPath.startsWith('file://')) {
        videoPath = videoPath.substring(7);
      }

      File videoFile = File(videoPath);
      
      if (!await videoFile.exists()) {
        throw Exception('Video file not found at path: $videoPath');
      }

      // Use UserService for API call
      final result = await UserService.uploadVideo(videoFile);
      print("result: $result");
      
      toast('Video uploaded successfully!');
      
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      print('Upload error: $e');
      setState(() {
        _uploadError = e.toString();
      });
      toast('Upload failed: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _handlePost() async {
    bool confirmUpload = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Upload Video'),
        content: Text('Are you sure you want to upload this video?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Upload'),
          ),
        ],
      ),
    ) ?? false;

    if (confirmUpload) {
      await _uploadVideo();
    }
  }

  void _checkAndStartTimer() {
    if (_appliedCrop != null && !_isProcessingCrop) {
      setState(() {
        _showCroppedIndicator = true;
      });

      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            _showCroppedIndicator = false;
          });
        }
      });
    }
  }

  // Handle trim application
  void _handleTrim() async {
    if (_trimData == null) return;

    setState(() {
      _isProcessingTrim = true;
      _isTrimming = false;
    });

    try {
      final tempDir = await getTemporaryDirectory();
      final outPath = '${tempDir.path}/trimmed_${DateTime.now().millisecondsSinceEpoch}.mp4';

      final startSeconds = _trimData!.startValueMs / 1000;
      final durationSeconds = (_trimData!.endValueMs - _trimData!.startValueMs) / 1000;

      final cmd = '-i "$_originalVideoPath" -ss $startSeconds -t $durationSeconds -c copy "$outPath"';
      toast('Trimming video...');
      
      await FFmpegKit.executeAsync(cmd, (session) async {
        final returnCode = await session.getReturnCode();
        if (returnCode != null && returnCode.isValueSuccess()) {
          await _controller.pause();
          await _controller.dispose();
          
          _controller = VideoPlayerController.file(File(outPath))
            ..initialize().then((_) {
              setState(() {
                _isProcessingTrim = false;
                _trimData = TrimData(
                  startValueMs: 0,
                  endValueMs: _controller.value.duration.inMilliseconds,
                  maxDurationMs: _controller.value.duration.inMilliseconds,
                );
              });
              _controller.setLooping(true);
              _controller.play();
              _isPlaying = true;
              toast('Trim finished successfully');
            });
        } else {
          setState(() => _isProcessingTrim = false);
          toast('Trim failed. Please try again.');
        }
      });
    } catch (e) {
      setState(() => _isProcessingTrim = false);
      toast('Trim error: $e');
    }
  }

  // Reset trim to original video
  void _resetTrim() {
    setState(() {
      _isTrimming = false;
      if (_controller.value.isInitialized) {
        _trimData = TrimData(
          startValueMs: 0,
          endValueMs: _controller.value.duration.inMilliseconds,
          maxDurationMs: _controller.value.duration.inMilliseconds,
        );
      }
      _activeTool = EditorTool.none;
    });
  }

  // ... (Keep all your existing helper methods: _onAddText, _buildColorSelector, etc.)
  // These remain the same as in your original code
  void _onAddText() {
    String newText = 'Your Text Here';
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String currentText = newText;
        Color currentColor = _selectedColor;
        double currentFontSize = _selectedFontSize;
        String currentFont = _selectedFont;
        FontWeight currentFontWeight = _selectedFontWeight;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Add Text'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: InputDecoration(hintText: 'Enter text'),
                      onChanged: (value) => currentText = value,
                    ),
                    SizedBox(height: 16),
                    _buildColorSelector(setState, currentColor, (color) => currentColor = color),
                    SizedBox(height: 16),
                    _buildFontSizeSelector(setState, currentFontSize, (size) => currentFontSize = size),
                    SizedBox(height: 16),
                    _buildFontSelector(setState, currentFont, (font) => currentFont = font),
                    SizedBox(height: 16),
                    _buildFontWeightSelector(setState, currentFontWeight, (weight) => currentFontWeight = weight),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedColor = currentColor;
                      _selectedFontSize = currentFontSize;
                      _selectedFont = currentFont;
                      _selectedFontWeight = currentFontWeight;
                    });
                    
                    setState(() {
                      _textOverlays.add(TextOverlay(
                        text: currentText,
                        position: Offset(MediaQuery.of(context).size.width * 0.1, 
                                        MediaQuery.of(context).size.height * 0.1),
                        style: TextStyle(
                          color: currentColor,
                          fontSize: currentFontSize,
                          fontWeight: currentFontWeight,
                          fontFamily: currentFont,
                          shadows: [Shadow(blurRadius: 2, color: Colors.black, offset: Offset(1, 1))],
                        ),
                      ));
                    });
                    
                    Navigator.of(context).pop();
                  },
                  child: Text('Add'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      setState(() {
        _activeTool = EditorTool.none;
      });
    });
  }

  // ... (Keep all your existing helper methods: _buildColorSelector, _buildFontSizeSelector, etc.)
  Widget _buildColorSelector(void Function(void Function()) setState, Color currentColor, Function(Color) onChanged) {
    return Row(
      children: [
        Text('Color: '),
        DropdownButton<Color>(
          value: currentColor,
          onChanged: (Color? newValue) {
            setState(() {});
            onChanged(newValue!);
          },
          items: [
            Colors.white, Colors.black, Colors.red, 
            Colors.green, Colors.blue, Colors.yellow,
          ].map<DropdownMenuItem<Color>>((Color value) {
            return DropdownMenuItem<Color>(
              value: value,
              child: Row(
                children: [
                  Container(width: 20, height: 20, color: value),
                  SizedBox(width: 8),
                  Text(_colorLabel(value)),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFontSizeSelector(void Function(void Function()) setState, double currentFontSize, Function(double) onChanged) {
    return Row(
      children: [
        Text('Font Size: '),
        Expanded(
          child: Slider(
            value: currentFontSize,
            min: 12,
            max: 48,
            divisions: 9,
            onChanged: (double value) {
              setState(() {});
              onChanged(value);
            },
          ),
        ),
        SizedBox(width: 8),
        SizedBox(width: 40, child: Text('${currentFontSize.round()}', textAlign: TextAlign.center)),
      ],
    );
  }

  Widget _buildFontSelector(void Function(void Function()) setState, String currentFont, Function(String) onChanged) {
    return Row(
      children: [
        Text('Font: '),
        DropdownButton<String>(
          value: currentFont,
          onChanged: (String? newValue) {
            setState(() {});
            onChanged(newValue!);
          },
          items: <String>['Roboto', 'Arial', 'Times New Roman', 'Courier New']
              .map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(value: value, child: Text(value));
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFontWeightSelector(void Function(void Function()) setState, FontWeight currentFontWeight, Function(FontWeight) onChanged) {
    return Row(
      children: [
        Text('Font Weight: '),
        DropdownButton<FontWeight>(
          value: currentFontWeight,
          onChanged: (FontWeight? newValue) {
            setState(() {});
            onChanged(newValue!);
          },
          items: [
            FontWeight.w100, FontWeight.w200, FontWeight.w300,
            FontWeight.w400, FontWeight.w500, FontWeight.w600,
            FontWeight.w700, FontWeight.w800, FontWeight.w900,
          ].map<DropdownMenuItem<FontWeight>>((FontWeight value) {
            return DropdownMenuItem<FontWeight>(
              value: value,
              child: Text(_fontWeightLabel(value)),
            );
          }).toList(),
        ),
      ],
    );
  }

  String _fontWeightLabel(FontWeight w) {
    switch (w) {
      case FontWeight.w100: return 'Thin';
      case FontWeight.w200: return 'Extra Light';
      case FontWeight.w300: return 'Light';
      case FontWeight.w400: return 'Regular';
      case FontWeight.w500: return 'Medium';
      case FontWeight.w600: return 'Semi Bold';
      case FontWeight.w700: return 'Bold';
      case FontWeight.w800: return 'Extra Bold';
      case FontWeight.w900: return 'Black';
      default: return w.toString().split('.').last;
    }
  }

  String _colorLabel(Color c) {
    if (c == Colors.white) return 'White';
    if (c == Colors.black) return 'Black';
    if (c == Colors.red) return 'Red';
    if (c == Colors.green) return 'Green';
    if (c == Colors.blue) return 'Blue';
    if (c == Colors.yellow) return 'Yellow';
    return '#${c.value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

  void _handleCrop() async {
    if (_cropRect == null) {
      setState(() => _isCropping = false);
      return;
    }

    final renderBox = _aspectKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      setState(() => _isCropping = false);
      return;
    }

    final videoWidth = _controller.value.size.width;
    final videoHeight = _controller.value.size.height;
    
    final displaySize = renderBox.size;
    
    final videoAspect = videoWidth / videoHeight;
    final displayAspect = displaySize.width / displaySize.height;
    
    double contentWidth, contentHeight, contentX, contentY;
    
    if (videoAspect > displayAspect) {
      contentWidth = displaySize.width;
      contentHeight = displaySize.width / videoAspect;
      contentX = 0;
      contentY = (displaySize.height - contentHeight) / 2;
    } else {
      contentHeight = displaySize.height;
      contentWidth = displaySize.height * videoAspect;
      contentX = (displaySize.width - contentWidth) / 2;
      contentY = 0;
    }
    
    final clampedLeft = _cropRect!.left.clamp(contentX, contentX + contentWidth);
    final clampedTop = _cropRect!.top.clamp(contentY, contentY + contentHeight);
    final clampedRight = _cropRect!.right.clamp(contentX, contentX + contentWidth);
    final clampedBottom = _cropRect!.bottom.clamp(contentY, contentY + contentHeight);
    
    final relativeLeft = (clampedLeft - contentX) / contentWidth;
    final relativeTop = (clampedTop - contentY) / contentHeight;
    final relativeRight = (clampedRight - contentX) / contentWidth;
    final relativeBottom = (clampedBottom - contentY) / contentHeight;
    
    final cropX = (relativeLeft * videoWidth).round();
    final cropY = (relativeTop * videoHeight).round();
    final cropW = ((relativeRight - relativeLeft) * videoWidth).round();
    final cropH = ((relativeBottom - relativeTop) * videoHeight).round();

    if (cropW <= 0 || cropH <= 0 || cropX < 0 || cropY < 0 || 
        cropX + cropW > videoWidth || cropY + cropH > videoHeight) {
      toast('Invalid crop area. Please select a smaller area.');
      setState(() => _isCropping = false);
      return;
    }

    if (cropW < 50 || cropH < 50) {
      toast('Crop area is too small. Please select a larger area.');
      setState(() => _isCropping = false);
      return;
    }

    setState(() {
      _isProcessingCrop = true;
      _isCropping = false;
    });

    try {
      final tempDir = await getTemporaryDirectory();
      final outPath = '${tempDir.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.mp4';

      final cmd = '-i "$_originalVideoPath" -filter:v "crop=$cropW:$cropH:$cropX:$cropY" -c:a copy "$outPath"';
      toast('Cropping video...');
      
      await FFmpegKit.executeAsync(cmd, (session) async {
        final returnCode = await session.getReturnCode();
        if (returnCode != null && returnCode.isValueSuccess()) {
          final cropData = CropData(
            left: relativeLeft,
            top: relativeTop,
            right: relativeRight,
            bottom: relativeBottom,
          );
          
          await _controller.pause();
          await _controller.dispose();
          
          _controller = VideoPlayerController.file(File(outPath))
            ..initialize().then((_) {
              setState(() {
                _isProcessingCrop = false;
                _cropRect = null;
                _appliedCrop = cropData;
                _showCroppedIndicator = true;
                // Update trim data for new video
                _trimData = TrimData(
                  startValueMs: 0,
                  endValueMs: _controller.value.duration.inMilliseconds,
                  maxDurationMs: _controller.value.duration.inMilliseconds,
                );
              });
              _controller.setLooping(true);
              _controller.play();
              _isPlaying = true;
              toast('Crop finished successfully');
              
              Future.delayed(Duration(seconds: 5), () {
                if (mounted) {
                  setState(() {
                    _showCroppedIndicator = false;
                  });
                }
              });
            });
        } else {
          setState(() => _isProcessingCrop = false);
          toast('Crop failed. Please try again.');
        }
      });
    } catch (e) {
      setState(() => _isProcessingCrop = false);
      toast('Crop error: $e');
    }
  }

  // ... (Keep all your existing crop handle methods: _buildCropHandles, _buildCornerHandles, etc.)
  Widget _buildCropHandles(double width, double height) {
    if (_cropRect == null) return SizedBox.shrink();

    return Stack(
      children: [
        ..._buildCornerHandles(width, height),
        ..._buildEdgeHandles(width, height),
        Positioned(
          left: _cropRect!.left + 10,
          top: _cropRect!.top + 10,
          width: _cropRect!.width - 20,
          height: _cropRect!.height - 20,
          child: GestureDetector(
            onPanStart: (_) => setState(() => _activeHandle = 'move'),
            onPanUpdate: (details) {
              setState(() {
                final dx = details.delta.dx;
                final dy = details.delta.dy;
                final newLeft = (_cropRect!.left + dx).clamp(0.0, width - _cropRect!.width);
                final newTop = (_cropRect!.top + dy).clamp(0.0, height - _cropRect!.height);
                _cropRect = Rect.fromLTWH(newLeft, newTop, _cropRect!.width, _cropRect!.height);
              });
            },
            onPanEnd: (_) => setState(() => _activeHandle = null),
            child: Container(color: Colors.transparent),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildCornerHandles(double width, double height) {
    return [
      _buildHandle(_cropRect!.left - 12, _cropRect!.top - 12, 'tl', width, height),
      _buildHandle(_cropRect!.right - 12, _cropRect!.top - 12, 'tr', width, height),
      _buildHandle(_cropRect!.left - 12, _cropRect!.bottom - 12, 'bl', width, height),
      _buildHandle(_cropRect!.right - 12, _cropRect!.bottom - 12, 'br', width, height),
    ];
  }

  List<Widget> _buildEdgeHandles(double width, double height) {
    return [
      _buildHandle(_cropRect!.left + _cropRect!.width / 2 - 12, _cropRect!.top - 12, 't', width, height),
      _buildHandle(_cropRect!.left + _cropRect!.width / 2 - 12, _cropRect!.bottom - 12, 'b', width, height),
      _buildHandle(_cropRect!.left - 12, _cropRect!.top + _cropRect!.height / 2 - 12, 'l', width, height),
      _buildHandle(_cropRect!.right - 12, _cropRect!.top + _cropRect!.height / 2 - 12, 'r', width, height),
    ];
  }

  Widget _buildHandle(double left, double top, String handleType, double maxWidth, double maxHeight) {
    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onPanStart: (_) => setState(() => _activeHandle = handleType),
        onPanUpdate: (details) {
          setState(() {
            switch (handleType) {
              case 'tl':
                _cropRect = Rect.fromLTRB(
                  (_cropRect!.left + details.delta.dx).clamp(0.0, _cropRect!.right - 10),
                  (_cropRect!.top + details.delta.dy).clamp(0.0, _cropRect!.bottom - 10),
                  _cropRect!.right,
                  _cropRect!.bottom,
                );
                break;
              case 'tr':
                _cropRect = Rect.fromLTRB(
                  _cropRect!.left,
                  (_cropRect!.top + details.delta.dy).clamp(0.0, _cropRect!.bottom - 10),
                  (_cropRect!.right + details.delta.dx).clamp(_cropRect!.left + 10, maxWidth),
                  _cropRect!.bottom,
                );
                break;
              case 'bl':
                _cropRect = Rect.fromLTRB(
                  (_cropRect!.left + details.delta.dx).clamp(0.0, _cropRect!.right - 10),
                  _cropRect!.top,
                  _cropRect!.right,
                  (_cropRect!.bottom + details.delta.dy).clamp(_cropRect!.top + 10, maxHeight),
                );
                break;
              case 'br':
                _cropRect = Rect.fromLTRB(
                  _cropRect!.left,
                  _cropRect!.top,
                  (_cropRect!.right + details.delta.dx).clamp(_cropRect!.left + 10, maxWidth),
                  (_cropRect!.bottom + details.delta.dy).clamp(_cropRect!.top + 10, maxHeight),
                );
                break;
              case 't':
                _cropRect = Rect.fromLTRB(
                  _cropRect!.left,
                  (_cropRect!.top + details.delta.dy).clamp(0.0, _cropRect!.bottom - 10),
                  _cropRect!.right,
                  _cropRect!.bottom,
                );
                break;
              case 'b':
                _cropRect = Rect.fromLTRB(
                  _cropRect!.left,
                  _cropRect!.top,
                  _cropRect!.right,
                  (_cropRect!.bottom + details.delta.dy).clamp(_cropRect!.top + 10, maxHeight),
                );
                break;
              case 'l':
                _cropRect = Rect.fromLTRB(
                  (_cropRect!.left + details.delta.dx).clamp(0.0, _cropRect!.right - 10),
                  _cropRect!.top,
                  _cropRect!.right,
                  _cropRect!.bottom,
                );
                break;
              case 'r':
                _cropRect = Rect.fromLTRB(
                  _cropRect!.left,
                  _cropRect!.top,
                  (_cropRect!.right + details.delta.dx).clamp(_cropRect!.left + 10, maxWidth),
                  _cropRect!.bottom,
                );
                break;
            }
          });
        },
        onPanEnd: (_) => setState(() => _activeHandle = null),
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Editor', style: boldTextStyle(color: Colors.white)),
        centerTitle: true,
        actions: [
          if (_isUploading) ...[
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text('Uploading...', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ] else if (_isTrimming) ...[
            TextButton(
              onPressed: _resetTrim,
              child: Text('Cancel', style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: _handleTrim,
              child: Text('Apply', style: TextStyle(color: Colors.white)),
            ),
          ] else if (_isCropping) ...[
            TextButton(
              onPressed: () => setState(() {
                _isCropping = false;
                _cropRect = null;
              }),
              child: Text('Cancel', style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: _handleCrop,
              child: Text('Done', style: TextStyle(color: Colors.white)),
            ),
          ] else if (!_isProcessingCrop && !_isProcessingTrim) ...[
            AppButton(
              shapeBorder: RoundedRectangleBorder(borderRadius: radius(4)),
              text: 'Post',
              textStyle: secondaryTextStyle(color: Colors.white, size: 10),
              onTap: _handlePost,
              elevation: 0,
              color: SVAppColorPrimary,
              width: 50,
              padding: EdgeInsets.all(0),
            ).paddingAll(16),
          ],
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: _controller.value.isInitialized
                    ? Container(
                        color: Colors.black,
                        child: Stack(
                          key: _videoKey,
                          fit: StackFit.expand,
                          children: [
                            Center(
                              child: LayoutBuilder(
                                key: _aspectKey,
                                builder: (context, constraints) {
                                  final videoAspect = _controller.value.aspectRatio;
                                  double width = constraints.maxWidth;
                                  double height = width / videoAspect;
                                  
                                  if (height > constraints.maxHeight) {
                                    height = constraints.maxHeight;
                                    width = height * videoAspect;
                                  }
                                  
                                  final left = (constraints.maxWidth - width) / 2;
                                  final top = (constraints.maxHeight - height) / 2;

                                  return Stack(
                                    children: [
                                      if (_uploadError != null && !_isUploading)
                                        Positioned(
                                          top: 100,
                                          left: 20,
                                          right: 20,
                                          child: Container(
                                            padding: EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withOpacity(0.8),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(Icons.error, color: Colors.white),
                                                SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    _uploadError!,
                                                    style: TextStyle(color: Colors.white),
                                                    maxLines: 2,
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: Icon(Icons.close, color: Colors.white),
                                                  onPressed: () => setState(() => _uploadError = null),
                                                  padding: EdgeInsets.zero,
                                                  iconSize: 20,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      Positioned(
                                        left: left,
                                        top: top,
                                        width: width,
                                        height: height,
                                        child: GestureDetector(
                                          onTap: () {
                                            // Only toggle play/pause if not cropping and not processing
                                            if (!_isCropping && !_isProcessingCrop && !_isProcessingTrim) {
                                              _togglePlayPause();
                                            }
                                          },
                                          onTapDown: (details) {
                                            if (_activeTool == EditorTool.crop && !_isProcessingCrop && !_isProcessingTrim) {
                                              final local = details.localPosition;
                                              if (_cropRect == null) {
                                                setState(() {
                                                  _isCropping = true;
                                                  final defaultW = width * 0.7;
                                                  final defaultH = height * 0.7;
                                                  final leftPos = (local.dx - defaultW / 2).clamp(0.0, width - defaultW);
                                                  final topPos = (local.dy - defaultH / 2).clamp(0.0, height - defaultH);
                                                  _cropRect = Rect.fromLTWH(leftPos, topPos, defaultW, defaultH);
                                                });
                                              }
                                            }
                                          },
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              VideoPlayer(_controller),
                                              // Transparent play button overlay
                                              if (_showPlayButton && !_isCropping && !_isProcessingCrop && !_isProcessingTrim)
                                                Container(
                                                  color: Colors.black.withOpacity(0.3),
                                                  child: Center(
                                                    child: Container(
                                                      width: 80,
                                                      height: 80,
                                                      decoration: BoxDecoration(
                                                        color: Colors.black.withOpacity(0.5),
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: Icon(
                                                        _isPlaying ? Icons.pause : Icons.play_arrow,
                                                        size: 40,
                                                        color: Colors.white.withOpacity(0.8),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              if (_cropRect != null && !_isProcessingCrop) ...[
                                                CustomPaint(painter: _CropPainter(_cropRect!)),
                                                _buildCropHandles(width, height),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            ..._textOverlays.asMap().entries.map((entry) {
                              final i = entry.key;
                              final overlay = entry.value;
                              return Positioned(
                                left: overlay.position.dx,
                                top: overlay.position.dy,
                                child: GestureDetector(
                                  onPanUpdate: (details) {
                                    final renderBox = _videoKey.currentContext?.findRenderObject() as RenderBox?;
                                    final newPos = Offset(
                                      overlay.position.dx + details.delta.dx,
                                      overlay.position.dy + details.delta.dy,
                                    );

                                    if (renderBox != null) {
                                      final size = renderBox.size;
                                      const removeThreshold = 30.0;
                                      if (newPos.dx < -removeThreshold || newPos.dx > size.width + removeThreshold || 
                                          newPos.dy < -removeThreshold || newPos.dy > size.height + removeThreshold) {
                                        setState(() => _textOverlays.removeAt(i));
                                        return;
                                      }
                                    }

                                    setState(() {
                                      _textOverlays[i] = TextOverlay(
                                        text: overlay.text,
                                        position: newPos,
                                        style: overlay.style,
                                      );
                                    });
                                  },
                                  child: Container(
                                    padding: EdgeInsets.all(8),
                                    color: Colors.black.withOpacity(0.3),
                                    child: Text(overlay.text, style: overlay.style),
                                  ),
                                ),
                              );
                            }).toList(),
                            if (_selectedSound != null && !_isProcessingCrop && !_isProcessingTrim)
                              Positioned(
                                top: 12,
                                left: 12,
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.music_note, size: 16, color: Colors.white70),
                                      SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _selectedSound!['title'] ?? '',
                                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            _selectedSound!['artist'] ?? '',
                                            style: TextStyle(color: Colors.white70, fontSize: 10),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                      SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () => setState(() => _selectedSound = null),
                                        child: Container(
                                          width: 22,
                                          height: 22,
                                          decoration: BoxDecoration(
                                            color: Colors.white12,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(Icons.close, size: 14, color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            if (_showCroppedIndicator)
                              Positioned(
                                top: _selectedSound != null ? 70 : 12,
                                right: 12,
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.crop, size: 16, color: Colors.white70),
                                      SizedBox(width: 8),
                                      Text('Cropped', style: TextStyle(color: Colors.white, fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      )
                    : Center(child: CircularProgressIndicator()),
              ),
              // Show timeline only when trim tool is active
              if (_controller.value.isInitialized && _trimData != null && _isTrimming && !_isProcessingTrim)
                SVVideoTimeline(
                  controller: _controller,
                  trimData: _trimData!,
                  onTrimChanged: (start, end) {
                    setState(() {
                      _trimData!.startValueMs = start;
                      _trimData!.endValueMs = end;
                    });
                    // Seek to start position when trim changes
                    _controller.seekTo(Duration(milliseconds: start));
                  },
                ),
              if (!_isProcessingCrop && !_isProcessingTrim) _buildEditingToolbar(),
            ],
          ),
          if (_isProcessingCrop || _isProcessingTrim)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(SVAppColorPrimary)),
                    SizedBox(height: 16),
                    Text(
                      _isProcessingCrop ? 'Processing crop...' : 'Processing trim...', 
                      style: TextStyle(color: Colors.white)
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEditingToolbar() {
    return Container(
      color: Colors.black,
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildToolButton(Icons.content_cut, 'Trim', EditorTool.trim, onTap: () {
            setState(() {
              if (_activeTool == EditorTool.trim) {
                // If already in trim mode, exit it
                _isTrimming = false;
                _activeTool = EditorTool.none;
              } else {
                // Enter trim mode
                _activeTool = EditorTool.trim;
                _isTrimming = true;
                _isCropping = false;
                // Seek to start of trim range
                if (_trimData != null) {
                  _controller.seekTo(Duration(milliseconds: _trimData!.startValueMs));
                }
              }
            });
          }),
          _buildToolButton(Icons.text_fields, 'Text', EditorTool.text, onTap: _onAddText),
          _buildToolButton(Icons.music_note, 'Sound', EditorTool.none, onTap: () async {
            final result = await showModalBottomSheet<Map<String, String>>(
              context: context,
              builder: (bCtx) => SVSoundSelectionComponent(),
            );
            if (result != null) {
              setState(() {
                _selectedSound = result;
                _activeTool = EditorTool.none;
                _isTrimming = false;
                _isCropping = false;
              });
            }
          }),
          _buildToolButton(Icons.crop, 'Crop', EditorTool.crop, onTap: () {
            setState(() {
              if (_activeTool == EditorTool.crop) {
                // If already in crop mode, exit it
                _isCropping = false;
                _cropRect = null;
                _activeTool = EditorTool.none;
              } else {
                // Enter crop mode
                _activeTool = EditorTool.crop;
                _isCropping = false; // Will be set to true when user taps on video
                _isTrimming = false;
              }
            });
          }),
        ],
      ),
    );
  }

  Widget _buildToolButton(IconData icon, String label, EditorTool tool, {VoidCallback? onTap}) {
    bool isSelected = _activeTool == tool;
    bool isActive = false;
    
    // Special handling for trim and crop to show active state when in their modes
    if (tool == EditorTool.trim && _isTrimming) {
      isSelected = true;
      isActive = true;
    } else if (tool == EditorTool.crop && _isCropping) {
      isSelected = true;
      isActive = true;
    }
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon, color: isSelected ? SVAppColorPrimary : Colors.white),
          onPressed: onTap ?? () => setState(() => _activeTool = tool),
        ),
        Text(label, style: secondaryTextStyle(
          color: isActive ? SVAppColorPrimary : (isSelected ? SVAppColorPrimary : Colors.white70)
        )),
      ],
    );
  }
}