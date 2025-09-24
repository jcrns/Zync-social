import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:bbdsocial/main.dart';
import 'package:bbdsocial/screens/home/components/VideoEditorScreen.dart';
import 'package:bbdsocial/utils/SVColors.dart';
import 'package:camera/camera.dart';

class SVAddPostFragment extends StatefulWidget {
  const SVAddPostFragment({Key? key}) : super(key: key);

  @override
  State<SVAddPostFragment> createState() => _SVAddPostFragmentState();
}

class _SVAddPostFragmentState extends State<SVAddPostFragment> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isRecording = false;
  bool _showOptions = false;
  XFile? _videoFile;

  @override
  void initState() {
    super.initState();
    afterBuildCreated(() {
      setStatusBarColor(context.cardColor);
      _initializeCamera();
    });
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    if (_cameras != null && _cameras!.isNotEmpty) {
      _cameraController = CameraController(
        _cameras![0],
        ResolutionPreset.high,
        enableAudio: true,
      );
      await _cameraController!.initialize();
      setState(() {});
    }
  }

  Future<void> _startRecording() async {
    if (!_cameraController!.value.isInitialized || _isRecording) return;

    try {
      await _cameraController!.startVideoRecording();
      setState(() {
        _isRecording = true;
      });
    } catch (e) {
      toast('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    try {
      XFile videoFile = await _cameraController!.stopVideoRecording();
      setState(() {
        _isRecording = false;
        _videoFile = videoFile;
      });

      // Navigate to editor screen
      if (_videoFile != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => SVVideoEditorScreen(videoPath: _videoFile!.path),
          ),
        );
      }
    } catch (e) {
      toast('Error stopping recording: $e');
    }
  }

  Future<void> _pickVideo() async {
    final ImagePicker picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);

    if (video != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => SVVideoEditorScreen(videoPath: video.path),
        ),
      );
    } else {
      toast('Video selection cancelled.');
    }
  }

  Widget _buildCameraPreview() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: SVAppColorPrimary),
            16.height,
            Text('Initializing Camera...', style: secondaryTextStyle()),
          ],
        ),
      );
    }
    return CameraPreview(_cameraController!);
  }

  Widget _buildOverlayButtons() {
    return Stack(
      children: [
        // Arrow Button (Top Left)
        Positioned(
          top: 50,
          left: 16,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _showOptions = !_showOptions;
              });
            },
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _showOptions ? Icons.close : Icons.arrow_forward,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),

        // Options Buttons (Top Right) - Only show when arrow is pressed
        if (_showOptions) ...[
          Positioned(
            top: 50,
            right: 16,
            child: Column(
              children: [
                _buildOptionButton(Icons.filter, 'Filters'),
                8.height,
                _buildOptionButton(Icons.grid_on, 'Layout'),
                8.height,
                _buildOptionButton(Icons.timer, 'Timer'),
              ],
            ),
          ),
        ],

        // Record Button (Bottom Center)
        Positioned(
          bottom: 30,
          left: MediaQuery.of(context).size.width / 2 - 30,
          child: GestureDetector(
            onTap: _isRecording ? _stopRecording : _startRecording,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.withOpacity(0.8),
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: Icon(
                _isRecording ? Icons.stop : Icons.fiber_manual_record,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
        ),

        // Gallery Button (Bottom Right)
        Positioned(
          bottom: 40,
          right: 16,
          child: GestureDetector(
            onTap: _pickVideo,
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.photo_library,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionButton(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          4.height,
          Text(label, style: secondaryTextStyle(size: 10, color: Colors.white)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    setStatusBarColor(
        appStore.isDarkMode ? appBackgroundColorDark : SVAppLayoutBackground);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Camera Preview
            _buildCameraPreview(),
            
            // Overlay Buttons
            _buildOverlayButtons(),
          ],
        ),
      ),
    );
  }
}