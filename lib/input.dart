import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:image/image.dart' as image_lib;
import 'classifier.dart'; // Import your classifier
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
    final rotateimage = image_lib.copyRotate(imageInput, 270);
      final int originalWidth = imageInput.width;
    final int originalHeight = imageInput.height;

    // List<Keypoint> keypoints = await _moveNetClassifier.processAndRunModel(rotateimage);
    List<Keypoint> keypoints = await _moveNetClassifier.processAndRunModel(imageInput);

    final mappedKeypoints = mapKeypointsToOriginalImage(
    keypoints: keypoints,
    originalWidth: originalWidth,
    originalHeight: originalHeight,
    inputSize: 256, // Model input size
  );

    for (var keypoint in mappedKeypoints) {
  print('Keypoint: (${keypoint.x}, ${keypoint.y}) with confidence: ${keypoint.confidence}');
}

    // print(mappedKeypoints[0].x);
    // print(mappedKeypoints[0].y);

    setState(() {
      _keypoints = mappedKeypoints;
    });
  }

  Future<void> _captureImageFromCamera() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null && _isModelReady) {
      setState(() {
        _image = File(pickedFile.path);
      });
      _predict(_image!);
    } else if (!_isModelReady) {
      print("Model is not yet ready!");
    } else {
      print("No image captured.");
    }
  }

List<Keypoint> mapKeypointsToOriginalImage({
  required List<Keypoint> keypoints,
  required int originalWidth,
  required int originalHeight,
  required int inputSize,
}) {
  return keypoints.map((keypoint) {
    final x = keypoint.x * originalWidth;
    final y = keypoint.y * originalHeight;
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _isModelReady ? _pickImage : null,
                  child: Text('Pick from Gallery'),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _isModelReady ? _captureImageFromCamera : null,
                  child: Text('Capture from Camera'),
                ),
              ],
            ),
            if (!_isModelReady) CircularProgressIndicator(), // Show loading indicator while model loads
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
  final double originalWidth;
  final double originalHeight;

  KeypointsPainter(this.keypoints, this.originalWidth, this.originalHeight);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    for (var keypoint in keypoints) {
      if (keypoint.confidence > 0.4) {
        final dx = (keypoint.x / originalWidth) * size.width;
        final dy = (keypoint.y / originalHeight) * size.height;
        canvas.drawCircle(Offset(dx, dy), 5.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}


