import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:image/image.dart' as image_lib;
import 'classifier.dart'; // Import your classifier
import 'keypoint_overlay.dart';
import 'dart:typed_data';
import 'dart:math';
// import 'package:flutter/material.dart';
class ImagePickerScreen extends StatefulWidget {
  @override
  _ImagePickerScreenState createState() => _ImagePickerScreenState();
}

class _ImagePickerScreenState extends State<ImagePickerScreen> {
  File? _image;
  Image? _imagewidget;

  final ImagePicker _picker = ImagePicker();
  late MoveNetClassifier _moveNetClassifier;
  bool _isModelReady = false; // Track model loading state
  List<Keypoint> _keypoints = []; // Updated to store keypoints directly

  @override
  void initState() {
    super.initState();
    _initializeClassifier();
  }

  Future<void> _initializeClassifier() async {
    _moveNetClassifier = MoveNetClassifier();
    try {
      print("Loading model...");
      await _moveNetClassifier.loadModel(); // Wait until the model is loaded
      setState(() {
        _isModelReady = true; // Once the model is loaded, set it to ready
      });
      if (_isModelReady) {
        print("Model is ready for use.");
      } else {
        print("Model initialization failed.");
      }
    } catch (e) {
      print("Error initializing model: $e");
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null && _isModelReady) {
      setState(() {
        _image = File(pickedFile.path);
      });
      _predict(_image!);
    } else if (!_isModelReady) {
      print("Model is not yet ready!");
    } else {
      print("No image selected.");
    }
  }

  Future<void> _predict(File image) async {
  
    final imageInput = image_lib.decodeImage(image.readAsBytesSync())!;
      final int originalWidth = imageInput.width;
    final int originalHeight = imageInput.height;

    List<Keypoint> keypoints = await _moveNetClassifier.processAndRunModel(imageInput);

    final mappedKeypoints = mapKeypointsToOriginalImage(
    keypoints: keypoints,
    originalWidth: originalWidth,
    originalHeight: originalHeight,
    inputSize: 256, // Model input size
  );

    setState(() {
      _keypoints = mappedKeypoints;
    });
  }

  List<Keypoint> mapKeypointsToOriginalImage({
  required List<Keypoint> keypoints,
  required int originalWidth,
  required int originalHeight,
  required int inputSize,
}) {
  final int padSize = max(originalWidth, originalHeight);
  final double scale = padSize / inputSize;

  final double xOffset = (padSize - originalWidth) / 2.0;
  final double yOffset = (padSize - originalHeight) / 2.0;

  return keypoints.map((keypoint) {
    final x = (keypoint.x * scale - xOffset);
    final y = (keypoint.y * scale - yOffset);
    return Keypoint(x, y, keypoint.confidence);
  }).toList();
}



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Image Picker and MoveNet'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_image == null)
              Text('No image selected.')
            else
              Stack(
                children: [
                  Container(
                    width: 256,
                    height: 256,
                    child: Image.file(_image!, fit: BoxFit.cover),
                  ),
                  if (_keypoints.isNotEmpty)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: KeypointsPainter(_keypoints,
                        image_lib.decodeImage(_image!.readAsBytesSync())!.width.toDouble(),
                        image_lib.decodeImage(_image!.readAsBytesSync())!.height.toDouble(),),
                                              ),
                    ),
                ],
              ),
            SizedBox(height: 20),
            _isModelReady
                ? ElevatedButton(
                    onPressed: _pickImage,
                    child: Text('Pick Image'),
                  )
                : CircularProgressIndicator(), // Show loading indicator while model loads
          ],
        ),
      ),
    );
  }
}

class Keypoint {
  final double x;
  final double y;
  final double confidence;

  Keypoint(this.x, this.y, this.confidence);
}

class KeypointsPainter extends CustomPainter {
  final List<Keypoint> keypoints;
  final double imageWidth;
  final double imageHeight;

  KeypointsPainter(this.keypoints, this.imageWidth, this.imageHeight);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFF0000) // Red color
      ..style = PaintingStyle.fill;
    final scaleX = size.width / imageWidth;
    final scaleY = size.height / imageHeight;

    print(size.width);
    debugPrint('image $imageWidth');

    for (var keypoint in keypoints) {
      if (keypoint.confidence > 0) { // Draw keypoints with confidence > 0.5
        final dx = keypoint.x * scaleX;
        final dy = keypoint.y * scaleY;
        canvas.drawCircle(Offset(dx, dy), 5.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

