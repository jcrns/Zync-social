import 'dart:io';
import 'package:bbdsocial/services/UserService.dart';
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
  final bool showGrid;

  _CropPainter(this.cropRect, {this.showGrid = true});

  @override
  void paint(Canvas canvas, Size size) {
    final outsidePaint = Paint()..color = Colors.black54;
    final full = Rect.fromLTWH(0, 0, size.width, size.height);
    final path = Path()
      ..addRect(full)
      ..addRect(cropRect);
    canvas.drawPath(path, outsidePaint..style = PaintingStyle.fill);

    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawRect(cropRect, border);

    if (showGrid) {
      final gridPaint = Paint()
        ..color = Colors.white54
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

    // Draw corner indicators for better visibility
    final cornerPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0;
    
    final cornerSize = 20.0;
    // Top-left corner
    canvas.drawLine(cropRect.topLeft, cropRect.topLeft + Offset(cornerSize, 0), cornerPaint);
    canvas.drawLine(cropRect.topLeft, cropRect.topLeft + Offset(0, cornerSize), cornerPaint);
    
    // Top-right corner
    canvas.drawLine(cropRect.topRight, cropRect.topRight - Offset(cornerSize, 0), cornerPaint);
    canvas.drawLine(cropRect.topRight, cropRect.topRight + Offset(0, cornerSize), cornerPaint);
    
    // Bottom-left corner
    canvas.drawLine(cropRect.bottomLeft, cropRect.bottomLeft + Offset(cornerSize, 0), cornerPaint);
    canvas.drawLine(cropRect.bottomLeft, cropRect.bottomLeft - Offset(0, cornerSize), cornerPaint);
    
    // Bottom-right corner
    canvas.drawLine(cropRect.bottomRight, cropRect.bottomRight - Offset(cornerSize, 0), cornerPaint);
    canvas.drawLine(cropRect.bottomRight, cropRect.bottomRight - Offset(0, cornerSize), cornerPaint);
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

  // Enhanced Crop state
  bool _isCropping = false;
  Rect? _cropRect;
  CropData? _appliedCrop;
  String? _activeHandle;
  bool _isProcessingCrop = false;
  double? _fixedAspectRatio; // For maintaining aspect ratio during crop
  Offset? _dragStartPoint;
  Rect? _dragStartRect;

  // Trim state
  bool _isTrimming = false;
  bool _isProcessingTrim = false;

  bool _showCroppedIndicator = false;
  Color _selectedColor = Colors.white;
  double _selectedFontSize = 24.0;
  String _selectedFont = 'Roboto';
  FontWeight _selectedFontWeight = FontWeight.bold;
  bool _isUploading = false;
  String? _uploadError;
  bool _isPlaying = false;
  bool _showPlayButton = true;
  // late String _originalVideoPath;
  late String _currentVideoPath; // Add this
  // Aspect ratio presets
  final List<Map<String, dynamic>> _aspectRatios = [
    {'name': 'Free', 'ratio': null},
    {'name': '1:1', 'ratio': 1.0},
    {'name': '16:9', 'ratio': 16.0 / 9.0},
    {'name': '9:16', 'ratio': 9.0 / 16.0},
    {'name': '4:3', 'ratio': 4.0 / 3.0},
    {'name': '3:4', 'ratio': 3.0 / 4.0},
  ];

  @override
  void initState() {
    super.initState();
    _currentVideoPath = widget.videoPath; // Modify this line
    _initializeVideoController(_currentVideoPath); // Pass the path
  }


void _initializeVideoController(String path) { // Modify to accept a path
  _controller = VideoPlayerController.file(File(path))
      ..initialize().then((_) {
        setState(() {
          _controller.setLooping(true);
          _trimData = TrimData(
            startValueMs: 0,
            endValueMs: _controller.value.duration.inMilliseconds,
            maxDurationMs: _controller.value.duration.inMilliseconds,
          );
          _controller.play();
          _isPlaying = true;
          
          Future.delayed(Duration(seconds: 2), () {
            if (mounted && _isPlaying) {
              setState(() {
                _showPlayButton = false;
              });
            }
          });
        });
      });
    
    _controller.addListener(_videoListener);
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

  void _startCrop() {
    setState(() {
      _isCropping = true;
      _activeTool = EditorTool.crop;
      
      // Initialize crop rectangle with safe default size
      final renderBox = _aspectKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final videoRect = _getVideoDisplaySize(renderBox.size);
        
        // Start with a centered rectangle that's 80% of video size
        final defaultWidth = videoRect.width * 0.8;
        final defaultHeight = videoRect.height * 0.8;
        final left = videoRect.left + (videoRect.width - defaultWidth) / 2;
        final top = videoRect.top + (videoRect.height - defaultHeight) / 2;
        
        _cropRect = Rect.fromLTWH(
          left.clamp(videoRect.left, videoRect.right - defaultWidth),
          top.clamp(videoRect.top, videoRect.bottom - defaultHeight),
          defaultWidth,
          defaultHeight,
        );
      }
    });
  }


  Rect _getVideoDisplaySize(Size containerSize) {
    if (!_controller.value.isInitialized) {
      return Rect.fromLTWH(0, 0, containerSize.width, containerSize.height);
    }

    final videoAspect = _controller.value.aspectRatio;
    final containerAspect = containerSize.width / containerSize.height;
    
    double width, height, left, top;
    
    if (videoAspect > containerAspect) {
      // Video is wider than container - fit to width
      width = containerSize.width;
      height = containerSize.width / videoAspect;
      left = 0;
      top = (containerSize.height - height) / 2;
    } else {
      // Video is taller than container - fit to height
      height = containerSize.height;
      width = containerSize.height * videoAspect;
      left = (containerSize.width - width) / 2;
      top = 0;
    }
    
    return Rect.fromLTWH(left, top, width, height);
  }

  void _onPanStartCrop(DragStartDetails details, String handleType) {
    final renderBox = _aspectKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || _cropRect == null) return;

    final videoRect = _getVideoDisplaySize(renderBox.size);
    final localPos = details.localPosition;

    // Ensure we're within video bounds
    if (!videoRect.contains(localPos)) return;

    setState(() {
      _activeHandle = handleType;
      _dragStartPoint = localPos;
      _dragStartRect = _cropRect;
    });
  }

void _onPanUpdateCrop(DragUpdateDetails details) {
    if (_dragStartPoint == null || _dragStartRect == null || _cropRect == null) return;

    final renderBox = _aspectKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final videoRect = _getVideoDisplaySize(renderBox.size);
    final delta = details.localPosition - _dragStartPoint!;
    
    setState(() {
      _cropRect = _calculateNewCropRect(
        _dragStartRect!,
        delta,
        _activeHandle!,
        videoRect,
        _fixedAspectRatio,
      );
    });
  }

  Rect _calculateNewCropRect(Rect startRect, Offset delta, String handleType, Rect bounds, double? aspectRatio) {
    double newLeft = startRect.left;
    double newTop = startRect.top;
    double newRight = startRect.right;
    double newBottom = startRect.bottom;

    switch (handleType) {
      case 'move':
        newLeft = (startRect.left + delta.dx).clamp(bounds.left, bounds.right - startRect.width);
        newTop = (startRect.top + delta.dy).clamp(bounds.top, bounds.bottom - startRect.height);
        newRight = newLeft + startRect.width;
        newBottom = newTop + startRect.height;
        break;

      case 'tl':
        newLeft = (startRect.left + delta.dx).clamp(bounds.left, startRect.right - 50);
        newTop = (startRect.top + delta.dy).clamp(bounds.top, startRect.bottom - 50);
        if (aspectRatio != null) {
          final newWidth = startRect.right - newLeft;
          final newHeight = newWidth / aspectRatio;
          newTop = startRect.bottom - newHeight;
          newLeft = startRect.right - newWidth;
        }
        break;

      case 'tr':
        newRight = (startRect.right + delta.dx).clamp(startRect.left + 50, bounds.right);
        newTop = (startRect.top + delta.dy).clamp(bounds.top, startRect.bottom - 50);
        if (aspectRatio != null) {
          final newWidth = newRight - startRect.left;
          final newHeight = newWidth / aspectRatio;
          newTop = startRect.bottom - newHeight;
          newRight = startRect.left + newWidth;
        }
        break;

      case 'bl':
        newLeft = (startRect.left + delta.dx).clamp(bounds.left, startRect.right - 50);
        newBottom = (startRect.bottom + delta.dy).clamp(startRect.top + 50, bounds.bottom);
        if (aspectRatio != null) {
          final newWidth = startRect.right - newLeft;
          final newHeight = newWidth / aspectRatio;
          newBottom = startRect.top + newHeight;
          newLeft = startRect.right - newWidth;
        }
        break;

      case 'br':
        newRight = (startRect.right + delta.dx).clamp(startRect.left + 50, bounds.right);
        newBottom = (startRect.bottom + delta.dy).clamp(startRect.top + 50, bounds.bottom);
        if (aspectRatio != null) {
          final newWidth = newRight - startRect.left;
          final newHeight = newWidth / aspectRatio;
          newBottom = startRect.top + newHeight;
          newRight = startRect.left + newWidth;
        }
        break;

      case 't':
        newTop = (startRect.top + delta.dy).clamp(bounds.top, startRect.bottom - 50);
        if (aspectRatio != null) {
          final newHeight = startRect.bottom - newTop;
          final newWidth = newHeight * aspectRatio;
          newLeft = startRect.left + (startRect.width - newWidth) / 2;
          newRight = newLeft + newWidth;
        }
        break;

      case 'b':
        newBottom = (startRect.bottom + delta.dy).clamp(startRect.top + 50, bounds.bottom);
        if (aspectRatio != null) {
          final newHeight = newBottom - startRect.top;
          final newWidth = newHeight * aspectRatio;
          newLeft = startRect.left + (startRect.width - newWidth) / 2;
          newRight = newLeft + newWidth;
        }
        break;

      case 'l':
        newLeft = (startRect.left + delta.dx).clamp(bounds.left, startRect.right - 50);
        if (aspectRatio != null) {
          final newWidth = startRect.right - newLeft;
          final newHeight = newWidth / aspectRatio;
          newTop = startRect.top + (startRect.height - newHeight) / 2;
          newBottom = newTop + newHeight;
        }
        break;

      case 'r':
        newRight = (startRect.right + delta.dx).clamp(startRect.left + 50, bounds.right);
        if (aspectRatio != null) {
          final newWidth = newRight - startRect.left;
          final newHeight = newWidth / aspectRatio;
          newTop = startRect.top + (startRect.height - newHeight) / 2;
          newBottom = newTop + newHeight;
        }
        break;
    }

    // Ensure final rect is within bounds and has minimum size
    final rect = Rect.fromLTRB(newLeft, newTop, newRight, newBottom);
    return _clampRectToBounds(rect, bounds);
  }

  Rect _clampRectToBounds(Rect rect, Rect bounds) {
    double left = rect.left.clamp(bounds.left, bounds.right - 50);
    double top = rect.top.clamp(bounds.top, bounds.bottom - 50);
    double right = rect.right.clamp(left + 50, bounds.right);
    double bottom = rect.bottom.clamp(top + 50, bounds.bottom);
    
    return Rect.fromLTRB(left, top, right, bottom);
  }

  void _onPanEndCrop(DragEndDetails details) {
    setState(() {
      _activeHandle = null;
      _dragStartPoint = null;
      _dragStartRect = null;
    });
  }



  // Enhanced upload function that includes text overlays
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

      // If there are text overlays, we need to burn them into the video
      if (_textOverlays.isNotEmpty) {
        videoFile = await _burnTextOverlaysIntoVideo(videoFile);
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

  // Function to burn text overlays into the video
  Future<File> _burnTextOverlaysIntoVideo(File originalVideo) async {
    if (_textOverlays.isEmpty) return originalVideo;

    try {
      final tempDir = await getTemporaryDirectory();
      final outPath = '${tempDir.path}/video_with_text_${DateTime.now().millisecondsSinceEpoch}.mp4';

      // Get video dimensions from controller
      final videoWidth = _controller.value.size.width.toInt();
      final videoHeight = _controller.value.size.height.toInt();

      // Build FFmpeg drawtext filters for each overlay
      String drawtextFilters = '';
      for (int i = 0; i < _textOverlays.length; i++) {
        final overlay = _textOverlays[i];
        
        // Convert position from screen coordinates to video coordinates
        final renderBox = _videoKey.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox != null) {
          final screenSize = renderBox.size;
          final videoRect = _getVideoDisplaySize(screenSize);
          
          // Calculate relative position within video
          final relX = (overlay.position.dx - videoRect.left) / videoRect.width;
          final relY = (overlay.position.dy - videoRect.top) / videoRect.height;
          
          // Convert to video pixel coordinates
          final x = (relX * videoWidth).round();
          final y = (relY * videoHeight).round();
          
          // Prepare text and style parameters
          final text = overlay.text.replaceAll("'", "\\'");
          final fontSize = (overlay.style.fontSize! * (videoHeight / 720)).round(); // Scale font size
          final fontColor = _colorToHex(overlay.style.color!);
          final fontFile = _getFontFile(overlay.style.fontFamily ?? 'Arial');
          
          String fontWeight = 'normal';
          if (overlay.style.fontWeight == FontWeight.bold) {
            fontWeight = 'bold';
          } else if (overlay.style.fontWeight == FontWeight.w100) {
            fontWeight = '100';
          } else if (overlay.style.fontWeight == FontWeight.w200) {
            fontWeight = '200';
          } else if (overlay.style.fontWeight == FontWeight.w300) {
            fontWeight = '300';
          } else if (overlay.style.fontWeight == FontWeight.w400) {
            fontWeight = 'normal';
          } else if (overlay.style.fontWeight == FontWeight.w500) {
            fontWeight = '500';
          } else if (overlay.style.fontWeight == FontWeight.w600) {
            fontWeight = '600';
          } else if (overlay.style.fontWeight == FontWeight.w700) {
            fontWeight = 'bold';
          } else if (overlay.style.fontWeight == FontWeight.w800) {
            fontWeight = '800';
          } else if (overlay.style.fontWeight == FontWeight.w900) {
            fontWeight = '900';
          }
          
          drawtextFilters += 
            'drawtext=text=\'$text\':x=$x:y=$y:fontsize=$fontSize:fontcolor=$fontColor:fontweight=$fontWeight';
          
          if (fontFile.isNotEmpty) {
            drawtextFilters += ':fontfile=$fontFile';
          }
          
          // Add shadow if present
          if (overlay.style.shadows != null && overlay.style.shadows!.isNotEmpty) {
            final shadow = overlay.style.shadows!.first;
            drawtextFilters += ':shadowcolor=#${shadow.color.value.toRadixString(16).padLeft(8, '0')}';
            drawtextFilters += ':shadowx=${shadow.offset.dx.round()}';
            drawtextFilters += ':shadowy=${shadow.offset.dy.round()}';
          }
          
          if (i < _textOverlays.length - 1) {
            drawtextFilters += ',';
          }
        }
      }

      final cmd = '-i "${originalVideo.path}" -vf "$drawtextFilters" -c:a copy "$outPath"';
      
      final session = await FFmpegKit.execute(cmd);
      final returnCode = await session.getReturnCode();
      
      if (returnCode != null && returnCode.isValueSuccess()) {
        return File(outPath);
      } else {
        throw Exception('Failed to add text overlays to video');
      }
    } catch (e) {
      print('Error burning text overlays: $e');
      // If text overlay burning fails, return original video
      return originalVideo;
    }
  }

  // Helper function to convert color to hex
  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0')}';
  }

  // Helper function to get font file path
  String _getFontFile(String fontFamily) {
    // Map common font families to their file names
    final fontMap = {
      'Roboto': 'Roboto-Regular.ttf',
      'Arial': 'arial.ttf',
      'Times New Roman': 'times.ttf',
      'Courier New': 'cour.ttf',
    };
    
    final fileName = fontMap[fontFamily] ?? 'Arial.ttf';
    return '/system/fonts/$fileName'; // Android font path
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

      // Use _currentVideoPath instead of _originalVideoPath
      // final cmd = '-i "$_currentVideoPath" -ss $startSeconds -t $durationSeconds -c copy "$outPath"';
      // In _burnTextOverlaysIntoVideo function, update the command to use _currentVideoPath:
      final cmd = '-i "$_currentVideoPath" -ss $startSeconds -t $durationSeconds -c copy "$outPath"';

      toast('Trimming video...');
      
      await FFmpegKit.executeAsync(cmd, (session) async {
        final returnCode = await session.getReturnCode();
        if (returnCode != null && returnCode.isValueSuccess()) {
          await _controller.pause();
          await _controller.dispose();
          
          _currentVideoPath = outPath; // Update the current path
          
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

  // Enhanced Crop Application with vertical aspect ratio preservation
// Replace the entire _handleCrop function with this corrected version
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

    setState(() {
      _isProcessingCrop = true;
      _isCropping = false; // Hide the crop UI
    });

    try {
      // 1. Get all necessary dimensions
      final videoSize = _controller.value.size; // e.g., 1920x1080
      final displayRect = _getVideoDisplaySize(renderBox.size); // The video's rect on screen

      // 2. Convert screen crop coordinates to actual video pixel coordinates
      final scaleX = videoSize.width / displayRect.width;
      final scaleY = videoSize.height / displayRect.height;

      final cropX = (_cropRect!.left - displayRect.left) * scaleX;
      final cropY = (_cropRect!.top - displayRect.top) * scaleY;
      final cropW = _cropRect!.width * scaleX;
      final cropH = _cropRect!.height * scaleY;

      // Ensure calculated values are valid and within bounds
      final validCropX = cropX.clamp(0, videoSize.width - 1).round();
      final validCropY = cropY.clamp(0, videoSize.height - 1).round();
      final validCropW = cropW.clamp(1, videoSize.width - validCropX).round();
      final validCropH = cropH.clamp(1, videoSize.height - validCropY).round();

      if (validCropW <= 0 || validCropH <= 0) {
        throw Exception("Invalid crop dimensions.");
      }

      final tempDir = await getTemporaryDirectory();
      final outPath = '${tempDir.path}/cropped_padded_${DateTime.now().millisecondsSinceEpoch}.mp4';

      // 3. Define final output dimensions (9:16 aspect ratio)
      final int outWidth = 720;
      final int outHeight = 1280;

      // 4. Build the FFmpeg command
      // This command chains three filters:
      // - crop: Extracts the selected rectangle from the original video.
      // - scale: Resizes the cropped video to fit within the 720x1280 frame while maintaining aspect ratio.
      // - pad: Places the scaled video onto a 720x1280 black background, centering it.
      final String filterCommand =
          "crop=${validCropW}:${validCropH}:${validCropX}:${validCropY}," +
          "scale=$outWidth:$outHeight:force_original_aspect_ratio=decrease," +
          "pad=$outWidth:$outHeight:(ow-iw)/2:(oh-ih)/2:color=black";

      final String cmd = '-i "$_currentVideoPath" -vf "$filterCommand" -c:a copy "$outPath"';
      
      toast('Applying crop...');

      await FFmpegKit.executeAsync(cmd, (session) async {
        final returnCode = await session.getReturnCode();
        if (returnCode != null && returnCode.isValueSuccess()) {
          // Update the controller with the newly processed video
          await _controller.pause();
          await _controller.dispose();
          
          _currentVideoPath = outPath; // Update the path to the new file
          
          // Re-initialize with the new video
          _controller = VideoPlayerController.file(File(_currentVideoPath))
            ..initialize().then((_) {
              setState(() {
                _isProcessingCrop = false;
                _cropRect = null;
                _showCroppedIndicator = true;
                _isCropping = false;
                _activeTool = EditorTool.none;
                
                _trimData = TrimData(
                  startValueMs: 0,
                  endValueMs: _controller.value.duration.inMilliseconds,
                  maxDurationMs: _controller.value.duration.inMilliseconds,
                );
              });
              _controller.setLooping(true);
              _controller.play();
              _isPlaying = true;
              toast('Crop applied successfully!');
              
              Future.delayed(Duration(seconds: 3), () {
                if (mounted) {
                  setState(() => _showCroppedIndicator = false);
                }
              });
            });
        } else {
          final logs = await session.getLogsAsString();
          print("FFmpeg failed: $logs");
          if (mounted) {
            setState(() => _isProcessingCrop = false);
          }
          toast('Crop failed. Please try again.');
        }
      });
    } catch (e) {
      print("Error during crop: $e");
      if (mounted) {
        setState(() => _isProcessingCrop = false);
      }
      toast('An error occurred: $e');
    }
  }

  Future<void> _applyCroppedVideo(String outPath, int x, int y, int w, int h) async {
    final cropData = CropData(
      left: x.toDouble(),
      top: y.toDouble(),
      right: (x + w).toDouble(),
      bottom: (y + h).toDouble(),
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
          _isCropping = false;
          _activeTool = EditorTool.none;
          
          _trimData = TrimData(
            startValueMs: 0,
            endValueMs: _controller.value.duration.inMilliseconds,
            maxDurationMs: _controller.value.duration.inMilliseconds,
          );
        });
        _controller.setLooping(true);
        _controller.play();
        _isPlaying = true;
        toast('Crop applied successfully');
        
        Future.delayed(Duration(seconds: 3), () {
          if (mounted) {
            setState(() => _showCroppedIndicator = false);
          }
        });
      });
  }

    // Aspect Ratio Selection
  Widget _buildAspectRatioSelector() {
    if (!_isCropping) return SizedBox.shrink();

    return Container(
      height: 60,
      color: Colors.black.withOpacity(0.8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _aspectRatios.map((ratio) {
          final isSelected = _fixedAspectRatio == ratio['ratio'];
          return GestureDetector(
            onTap: () {
              setState(() {
                _fixedAspectRatio = ratio['ratio'];
                if (_cropRect != null && ratio['ratio'] != null) {
                  _applyAspectRatio(ratio['ratio']!);
                }
              });
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? SVAppColorPrimary : Colors.grey[800],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  ratio['name'],
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _applyAspectRatio(double ratio) {
    final renderBox = _aspectKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || _cropRect == null) return;

    final videoRect = _getVideoDisplaySize(renderBox.size);
    final center = _cropRect!.center;
    final newWidth = _cropRect!.width;
    final newHeight = newWidth / ratio;

    // Ensure the new rect stays within bounds
    final newRect = Rect.fromCenter(
      center: center,
      width: newWidth.clamp(50, videoRect.width),
      height: newHeight.clamp(50, videoRect.height),
    );

    setState(() {
      _cropRect = _clampRectToBounds(newRect, videoRect);
    });
  }

  // Reset Crop
  void _resetCrop() {
    setState(() {
      _cropRect = null;
      _fixedAspectRatio = null;
      _isCropping = false;
      _activeTool = EditorTool.none;
    });
  }

  // ... (Keep all your existing crop handle methods: _buildCropHandles, _buildCornerHandles, etc.)
  Widget _buildCropHandles(double width, double height) {
    if (_cropRect == null) return SizedBox.shrink();

    final videoRect = _getVideoDisplaySize(Size(width, height));

    return Stack(
      children: [
        // Move handle (entire crop area)
        Positioned(
          left: _cropRect!.left,
          top: _cropRect!.top,
          width: _cropRect!.width,
          height: _cropRect!.height,
          child: GestureDetector(
            onPanStart: (details) => _onPanStartCrop(details, 'move'),
            onPanUpdate: _onPanUpdateCrop,
            onPanEnd: _onPanEndCrop,
            child: Container(color: Colors.transparent),
          ),
        ),

        // Corner handles
        _buildHandle(_cropRect!.left - 15, _cropRect!.top - 15, 'tl', videoRect),
        _buildHandle(_cropRect!.right - 15, _cropRect!.top - 15, 'tr', videoRect),
        _buildHandle(_cropRect!.left - 15, _cropRect!.bottom - 15, 'bl', videoRect),
        _buildHandle(_cropRect!.right - 15, _cropRect!.bottom - 15, 'br', videoRect),

        // Edge handles
        _buildHandle(_cropRect!.left + _cropRect!.width / 2 - 15, _cropRect!.top - 15, 't', videoRect),
        _buildHandle(_cropRect!.left + _cropRect!.width / 2 - 15, _cropRect!.bottom - 15, 'b', videoRect),
        _buildHandle(_cropRect!.left - 15, _cropRect!.top + _cropRect!.height / 2 - 15, 'l', videoRect),
        _buildHandle(_cropRect!.right - 15, _cropRect!.top + _cropRect!.height / 2 - 15, 'r', videoRect),
      ],
    );
  }

  Widget _buildHandle(double left, double top, String handleType, Rect bounds) {
    return Positioned(
      left: left.clamp(bounds.left - 15, bounds.right + 15),
      top: top.clamp(bounds.top - 15, bounds.bottom + 15),
      child: GestureDetector(
        onPanStart: (details) => _onPanStartCrop(details, handleType),
        onPanUpdate: _onPanUpdateCrop,
        onPanEnd: _onPanEndCrop,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black, width: 2),
          ),
        ),
      ),
    );
  }


// Remove or comment out the old _buildCornerHandles and _buildEdgeHandles functions
// and replace them with these corrected versions:

List<Widget> _buildCornerHandles(double width, double height) {
  if (_cropRect == null) return [];
  
  final videoRect = _getVideoDisplaySize(Size(width, height));
  
  return [
    _buildHandle(_cropRect!.left - 12, _cropRect!.top - 12, 'tl', videoRect),
    _buildHandle(_cropRect!.right - 12, _cropRect!.top - 12, 'tr', videoRect),
    _buildHandle(_cropRect!.left - 12, _cropRect!.bottom - 12, 'bl', videoRect),
    _buildHandle(_cropRect!.right - 12, _cropRect!.bottom - 12, 'br', videoRect),
  ];
}

List<Widget> _buildEdgeHandles(double width, double height) {
  if (_cropRect == null) return [];
  
  final videoRect = _getVideoDisplaySize(Size(width, height));
  
  return [
    _buildHandle(_cropRect!.left + _cropRect!.width / 2 - 12, _cropRect!.top - 12, 't', videoRect),
    _buildHandle(_cropRect!.left + _cropRect!.width / 2 - 12, _cropRect!.bottom - 12, 'b', videoRect),
    _buildHandle(_cropRect!.left - 12, _cropRect!.top + _cropRect!.height / 2 - 12, 'l', videoRect),
    _buildHandle(_cropRect!.right - 12, _cropRect!.top + _cropRect!.height / 2 - 12, 'r', videoRect),
  ];
}

Widget _buildProcessingOverlay() {
  return Container(
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
      actions: _buildAppBarActions(),
    ),
    body: Column(
      children: [
        if (_isCropping) _buildAspectRatioSelector(),
        Expanded(
          child: Stack(
            children: [
              _buildVideoPreview(),
              if (_isProcessingCrop || _isProcessingTrim) _buildProcessingOverlay(),
            ],
          ),
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
              _controller.seekTo(Duration(milliseconds: start));
            },
          ),
        if (!_isProcessingCrop && !_isProcessingTrim) _buildEditingToolbar(),
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
          _buildToolButton(Icons.content_cut, 'Trim', EditorTool.trim, onTap: _handleTrimTool),
          _buildToolButton(Icons.text_fields, 'Text', EditorTool.text, onTap: _onAddText),
          _buildToolButton(Icons.music_note, 'Sound', EditorTool.none, onTap: _handleSoundTool),
          _buildToolButton(Icons.crop, 'Crop', EditorTool.crop, onTap: _startCrop),
        ],
      ),
    );
  }
  Widget _buildUploadingIndicator() {
    return Padding(
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
    );
  }

  Widget _buildPostButton() {
    return AppButton(
      shapeBorder: RoundedRectangleBorder(borderRadius: radius(4)),
      text: 'Post',
      textStyle: secondaryTextStyle(color: Colors.white, size: 10),
      onTap: _handlePost,
      elevation: 0,
      color: SVAppColorPrimary,
      width: 50,
      padding: EdgeInsets.all(0),
    ).paddingAll(16);
  }

  Widget _buildVideoPreview() {
  return _controller.value.isInitialized
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
      : Center(child: CircularProgressIndicator());
}


  List<Widget> _buildAppBarActions() {
    if (_isUploading) {
      return [_buildUploadingIndicator()];
    } else if (_isCropping) {
      return [
        TextButton(
          onPressed: _resetCrop,
          child: Text('Cancel', style: TextStyle(color: Colors.white)),
        ),
        TextButton(
          onPressed: _handleCrop,
          child: Text('Apply', style: TextStyle(color: Colors.white)),
        ),
      ];
    } else if (_isTrimming) {
      return [
        TextButton(
          onPressed: _resetTrim,
          child: Text('Cancel', style: TextStyle(color: Colors.white)),
        ),
        TextButton(
          onPressed: _handleTrim,
          child: Text('Apply', style: TextStyle(color: Colors.white)),
        ),
      ];
    } else if (!_isProcessingCrop && !_isProcessingTrim) {
      return [_buildPostButton()];
    }
    return [];
  }

    void _handleTrimTool() {
    setState(() {
      if (_activeTool == EditorTool.trim) {
        _isTrimming = false;
        _activeTool = EditorTool.none;
      } else {
        _activeTool = EditorTool.trim;
        _isTrimming = true;
        _isCropping = false;
        if (_trimData != null) {
          _controller.seekTo(Duration(milliseconds: _trimData!.startValueMs));
        }
      }
    });
  }

  void _handleSoundTool() async {
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