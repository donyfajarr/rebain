import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:image/image.dart' as image_lib;
import 'classifier.dart'; // Import your classifier

class ImagePickerScreen extends StatefulWidget {
  @override
  _ImagePickerScreenState createState() => _ImagePickerScreenState();
}

class _ImagePickerScreenState extends State<ImagePickerScreen> {
  List<File> _images = [];
  final ImagePicker _picker = ImagePicker();
  late MoveNetClassifier _moveNetClassifier;
  bool _isModelReady = false;
  Map<File, List<Keypoint>> _keypointsMap = {}; // Map to store keypoints for each image

  @override
  void initState() {
    super.initState();
    _initializeClassifier();
  }

  Future<void> _initializeClassifier() async {
    _moveNetClassifier = MoveNetClassifier();
    try {
      print("Loading model...");
      await _moveNetClassifier.loadModel();
      setState(() {
        _isModelReady = true;
      });
      print("Model is ready for use.");
    } catch (e) {
      print("Error initializing model: $e");
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);

    if (pickedFile != null && _isModelReady) {
      final image = File(pickedFile.path);
      setState(() {
        _images.add(image);
      });
      await _predict(image);
    } else if (!_isModelReady) {
      print("Model is not ready yet!");
    } else {
      print("No image selected.");
    }
  }

  Future<void> _predict(File image) async {
    final imageInput = image_lib.decodeImage(image.readAsBytesSync())!;
    final int originalWidth = imageInput.width;
    final int originalHeight = imageInput.height;

    List<Keypoint> keypoints = await _moveNetClassifier.processAndRunModel(imageInput);

    setState(() {
      _keypointsMap[image] = keypoints;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Multiple Image Picker and MoveNet'),
      ),
      body: Column(
        children: [
          Expanded(
            child: _images.isEmpty
                ? Center(child: Text('No images selected or captured.'))
                : ListView.builder(
                    itemCount: _images.length,
                    itemBuilder: (context, index) {
                      final image = _images[index];
                      final keypoints = _keypointsMap[image];
                      return Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            Image.file(
                              image,
                              width: 256,
                              height: 256,
                              fit: BoxFit.cover,
                            ),
                            if (keypoints != null)
                              CustomPaint(
                                size: Size(256, 256),
                                painter: KeypointsPainter(
                                  keypoints,
                                  image_lib.decodeImage(image.readAsBytesSync())!.width.toDouble(),
                                  image_lib.decodeImage(image.readAsBytesSync())!.height.toDouble(),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _isModelReady
                    ? () => _pickImage(ImageSource.gallery)
                    : null,
                child: Text('Add from Gallery'),
              ),
              SizedBox(width: 10),
              ElevatedButton(
                onPressed: _isModelReady
                    ? () => _pickImage(ImageSource.camera)
                    : null,
                child: Text('Add from Camera'),
              ),
            ],
          ),
        ],
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
