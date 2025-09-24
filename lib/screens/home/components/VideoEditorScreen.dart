import 'dart:io';
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

  // State variable to control the visibility of the indicator
  bool _showCroppedIndicator = false;

  // Text formatting
  Color _selectedColor = Colors.white;
  double _selectedFontSize = 24.0;
  String _selectedFont = 'Roboto';
  FontWeight _selectedFontWeight = FontWeight.bold;

  bool _isUploading = false;
  String? _uploadError;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.videoPath))
      ..initialize().then((_) {
        setState(() {
          _controller.setLooping(true);
          _trimData = TrimData(
            startValueMs: 0,
            endValueMs: _controller.value.duration.inMilliseconds,
            maxDurationMs: _controller.value.duration.inMilliseconds,
          );
        });
      });
    _checkAndStartTimer();

  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Method to get authentication token
  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token'); // Adjust this based on your auth storage
  }

  // Method to upload the final edited video
  Future<void> _uploadVideo() async {
    if (_isUploading) return;

    setState(() {
      _isUploading = true;
      _uploadError = null;
    });

    try {
      // Get the current video file path
      String videoPath = _controller.dataSource;
      if (videoPath.startsWith('file://')) {
        videoPath = videoPath.substring(7);
      }

      File videoFile = File(videoPath);
      
      if (!await videoFile.exists()) {
        throw Exception('Video file not found');
      }

      // Get authentication token
      String? token = await _getAuthToken();
      if (token == null) {
        throw Exception('Please login to upload video');
      }

      // Create multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://your-domain.com/api/videos/upload/'), // Replace with your actual API URL
      );

      // To track progress, you can use a StreamedRequest and listen to its progress
      final streamedRequest = request.send();
      streamedRequest.asStream().listen((response) {
        response.stream.listen((chunk) {
          // Handle progress updates here if needed
        });
      });

      // Add headers
      request.headers['Authorization'] = 'Bearer $token';

      // Add video file
      request.files.add(await http.MultipartFile.fromPath(
        'video',
        videoPath,
        filename: 'edited_video_${DateTime.now().millisecondsSinceEpoch}.mp4',
      ));

      // Add other form data
      request.fields['title'] = 'Edited Video ${DateTime.now().toString()}';
      request.fields['description'] = 'Video edited in BBDSocial app';

      // Send request
      final response = await request.send();

      if (response.statusCode == 201) {
        final responseData = await response.stream.bytesToString();
        final jsonResponse = json.decode(responseData);
        
        toast('Video uploaded successfully!');
        
        // Navigate back or to success screen
        if (mounted) {
          Navigator.of(context).pop(true); // Pass success result
        }
      } else {
        final errorData = await response.stream.bytesToString();
        throw Exception('Upload failed: ${response.statusCode} - $errorData');
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

  // Updated _handlePost method
  void _handlePost() async {
    // Show confirmation dialog before uploading
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
      // Set state to true to immediately show the indicator
      setState(() {
        _showCroppedIndicator = true;
      });

      // Start a 5-second timer
      Future.delayed(const Duration(seconds: 5), () {
        // Only update the state if the widget is still in the widget tree
        if (mounted) {
          setState(() {
            _showCroppedIndicator = false;
          });
        }
      });
    }
  }
void _onAddText() {
  String newText = 'Your Text Here';
  
  // Use rootNavigator: true to ensure the dialog is shown above all other content
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
                  // Update the main state variables before popping
                  setState(() {
                    _selectedColor = currentColor;
                    _selectedFontSize = currentFontSize;
                    _selectedFont = currentFont;
                    _selectedFontWeight = currentFontWeight;
                  });
                  
                  // Add the text overlay and then pop the dialog
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
    // Reset active tool after dialog is closed
    setState(() {
      _activeTool = EditorTool.none;
    });
  });
}

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

    // Get the actual video dimensions from the controller
    final videoWidth = _controller.value.size.width;
    final videoHeight = _controller.value.size.height;
    print('Video dimensions: width=$videoWidth, height=$videoHeight');
    
    // Get the displayed video container dimensions
    final displaySize = renderBox.size;
    print('Display dimensions: width=${displaySize.width}, height=${displaySize.height}');
    
    // Calculate the actual video content area within the display
    final videoAspect = videoWidth / videoHeight;
    final displayAspect = displaySize.width / displaySize.height;
    
    double contentWidth, contentHeight, contentX, contentY;
    
    if (videoAspect > displayAspect) {
      // Video is wider than display - letterboxing on top and bottom
      contentWidth = displaySize.width;
      contentHeight = displaySize.width / videoAspect;
      contentX = 0;
      contentY = (displaySize.height - contentHeight) / 2;
    } else {
      // Video is taller than display - pillarboxing on sides
      contentHeight = displaySize.height;
      contentWidth = displaySize.height * videoAspect;
      contentX = (displaySize.width - contentWidth) / 2;
      contentY = 0;
    }
    
    print('Content area: x=$contentX, y=$contentY, width=$contentWidth, height=$contentHeight');
    print('Crop rect: left=${_cropRect!.left}, top=${_cropRect!.top}, right=${_cropRect!.right}, bottom=${_cropRect!.bottom}');
    
    // Ensure crop rectangle is within the video content area
    final clampedLeft = _cropRect!.left.clamp(contentX, contentX + contentWidth);
    final clampedTop = _cropRect!.top.clamp(contentY, contentY + contentHeight);
    final clampedRight = _cropRect!.right.clamp(contentX, contentX + contentWidth);
    final clampedBottom = _cropRect!.bottom.clamp(contentY, contentY + contentHeight);
    
    // Convert to relative coordinates within the video content area
    final relativeLeft = (clampedLeft - contentX) / contentWidth;
    final relativeTop = (clampedTop - contentY) / contentHeight;
    final relativeRight = (clampedRight - contentX) / contentWidth;
    final relativeBottom = (clampedBottom - contentY) / contentHeight;
    
    print('Relative coordinates: left=$relativeLeft, top=$relativeTop, right=$relativeRight, bottom=$relativeBottom');
    
    // Convert to actual video coordinates
    final cropX = (relativeLeft * videoWidth).round();
    final cropY = (relativeTop * videoHeight).round();
    final cropW = ((relativeRight - relativeLeft) * videoWidth).round();
    final cropH = ((relativeBottom - relativeTop) * videoHeight).round();

    print('Final crop coordinates: x=$cropX, y=$cropY, width=$cropW, height=$cropH');
    print('Video bounds: width=$videoWidth, height=$videoHeight');

    // Validate crop dimensions
    if (cropW <= 0 || cropH <= 0 || cropX < 0 || cropY < 0 || 
        cropX + cropW > videoWidth || cropY + cropH > videoHeight) {
      print('Invalid crop area: width=$cropW, height=$cropH, x=$cropX, y=$cropY');
      toast('Invalid crop area. Please select a smaller area.');
      setState(() => _isCropping = false);
      return;
    }

    // Ensure minimum crop size
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

      final cmd = '-i "${widget.videoPath}" -filter:v "crop=$cropW:$cropH:$cropX:$cropY" -c:a copy "$outPath"';
      print('FFmpeg command: $cmd');
      toast('Cropping video...');
      
      await FFmpegKit.executeAsync(cmd, (session) async {
        final returnCode = await session.getReturnCode();
        if (returnCode != null && returnCode.isValueSuccess()) {
          // Store crop data for reference
          final cropData = CropData(
            left: relativeLeft,
            top: relativeTop,
            right: relativeRight,
            bottom: relativeBottom,
          );
          
          print('Crop successful. Data: $cropData');
          
          await _controller.pause();
          await _controller.dispose();
          
          _controller = VideoPlayerController.file(File(outPath))
            ..initialize().then((_) {
              setState(() {
                _isProcessingCrop = false;
                _cropRect = null;
                _appliedCrop = cropData;
                _showCroppedIndicator = true;
              });
              _controller.setLooping(true);
              _controller.play();
              toast('Crop finished successfully');
              
              // Hide indicator after 5 seconds
              Future.delayed(Duration(seconds: 5), () {
                if (mounted) {
                  setState(() {
                    _showCroppedIndicator = false;
                  });
                }
              });
            });
        } else {
          final log = await session.getLogs();
          print('FFmpeg error: $log');
          setState(() => _isProcessingCrop = false);
          toast('Crop failed. Please try again.');
        }
      });
    } catch (e) {
      print('Crop error: $e');
      setState(() => _isProcessingCrop = false);
      toast('Crop error: $e');
    }
  }

  Widget _buildCropHandles(double width, double height) {
    if (_cropRect == null) return SizedBox.shrink();

    return Stack(
      children: [
        // Corner handles
        ..._buildCornerHandles(width, height),
        // Edge handles
        ..._buildEdgeHandles(width, height),
        // Move area
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
      // Top-left
      _buildHandle(_cropRect!.left - 12, _cropRect!.top - 12, 'tl', width, height),
      // Top-right
      _buildHandle(_cropRect!.right - 12, _cropRect!.top - 12, 'tr', width, height),
      // Bottom-left
      _buildHandle(_cropRect!.left - 12, _cropRect!.bottom - 12, 'bl', width, height),
      // Bottom-right
      _buildHandle(_cropRect!.right - 12, _cropRect!.bottom - 12, 'br', width, height),
    ];
  }

  List<Widget> _buildEdgeHandles(double width, double height) {
    return [
      // Top
      _buildHandle(_cropRect!.left + _cropRect!.width / 2 - 12, _cropRect!.top - 12, 't', width, height),
      // Bottom
      _buildHandle(_cropRect!.left + _cropRect!.width / 2 - 12, _cropRect!.bottom - 12, 'b', width, height),
      // Left
      _buildHandle(_cropRect!.left - 12, _cropRect!.top + _cropRect!.height / 2 - 12, 'l', width, height),
      // Right
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
          ] else if (!_isProcessingCrop) ...[
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
                                        // Add this to your Stack children in the build method, right before the processing crop overlay:
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
                                          onTapDown: (details) {
                                            if (_activeTool == EditorTool.crop && !_isProcessingCrop) {
                                              final local = details.localPosition;
                                              if (_cropRect == null) {
                                                setState(() {
                                                  _isCropping = true;
                                                  // Use proportional sizing based on video dimensions
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
                            // FIX: Show sound bar regardless of active tool, only check if sound is selected
                            if (_selectedSound != null && !_isProcessingCrop)
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
                                top: _selectedSound != null ? 70 : 12, // Adjust position if sound bar is visible
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
              if (_controller.value.isInitialized && _trimData != null && !_isProcessingCrop)
                SVVideoTimeline(
                  controller: _controller,
                  trimData: _trimData!,
                  onTrimChanged: (start, end) {
                    setState(() {
                      _trimData!.startValueMs = start;
                      _trimData!.endValueMs = end;
                    });
                  },
                ),
              if (!_isProcessingCrop) _buildEditingToolbar(),
            ],
          ),
          if (_isProcessingCrop)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(SVAppColorPrimary)),
                    SizedBox(height: 16),
                    Text('Processing crop...', style: TextStyle(color: Colors.white)),
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
        _buildToolButton(Icons.content_cut, 'Trim', EditorTool.trim),
        
        _buildToolButton(Icons.text_fields, 'Text', EditorTool.text, onTap: () {
          // Ensure we're using the correct context and not popping any routes accidentally
          // WidgetsBinding.instance.addPostFrameCallback((_) {
          //   _onAddText();
          // });
          _onAddText();

        }),
        // _buildToolButton(Icons.text_fields, 'Text', EditorTool.text, onTap: _onAddText),

        _buildToolButton(Icons.music_note, 'Sound', EditorTool.none, onTap: () async {
          final result = await showModalBottomSheet<Map<String, String>>(
            context: context,
            builder: (bCtx) => SVSoundSelectionComponent(),
          );
          if (result != null) {
            setState(() {
              _selectedSound = result;
              // Reset active tool after selecting sound
              _activeTool = EditorTool.none;
            });
          }
        }),
        _buildToolButton(Icons.crop, 'Crop', EditorTool.crop),
      ],
    ),
  );
}

  Widget _buildToolButton(IconData icon, String label, EditorTool tool, {VoidCallback? onTap}) {
    bool isSelected = _activeTool == tool;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon, color: isSelected ? SVAppColorPrimary : Colors.white),
          onPressed: onTap ?? () => setState(() => _activeTool = tool),
        ),
        Text(label, style: secondaryTextStyle(color: isSelected ? SVAppColorPrimary : Colors.white70)),
      ],
    );
  }
}