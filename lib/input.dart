import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:image/image.dart' as image_lib;
import 'classifier.dart'; // Import your classifier
import 'keypoint_overlay.dart';
import 'dart:typed_data';
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
    List<Keypoint> keypoints = await _moveNetClassifier.processAndRunModel(imageInput);

    setState(() {
      _keypoints = keypoints;
    });
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
                    child: Image.file(_image!, fit: BoxFit.scaleDown),
                  ),
                  if (_keypoints.isNotEmpty)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: KeypointsPainter(_keypoints),
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

  KeypointsPainter(this.keypoints);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFF0000) // Red color
      ..style = PaintingStyle.fill;

    for (var keypoint in keypoints) {
      if (keypoint.confidence > 0) { // Only draw keypoints with confidence > 0.5
        canvas.drawCircle(Offset(keypoint.x, keypoint.y), 5.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
