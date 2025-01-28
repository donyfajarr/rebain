import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:image/image.dart' as image_lib;
import 'classifier.dart'; // Import your classifier
import 'dart:math';

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
    calculatePosture(keypoints);
    Vector2D keypointToVector2D(Keypoint keypoint) {
  return Vector2D(keypoint.x, keypoint.y);
}
    // Convert keypoints to Vector2D
  Vector2D leftShoulder = keypointToVector2D(keypoints[5]);
  Vector2D leftElbow = keypointToVector2D(keypoints[7]);
  Vector2D leftWrist = keypointToVector2D(keypoints[9]);
  Vector2D leftHip = keypointToVector2D(keypoints[11]);

  Vector2D rightShoulder = keypointToVector2D(keypoints[6]);
  Vector2D rightElbow = keypointToVector2D(keypoints[8]);
  Vector2D rightWrist = keypointToVector2D(keypoints[10]);
  Vector2D rightHip = keypointToVector2D(keypoints[12]);

  // Calculate lower arm angles
  var (leftLowerArmAngle, rightLowerArmAngle) = PostureCalculator.calculateLowerArmAngle(
    leftElbow, leftWrist, leftShoulder,
    rightElbow, rightWrist, rightShoulder,
  );
  print('Left Lower Arm Angle: $leftLowerArmAngle°');
  print('Right Lower Arm Angle: $rightLowerArmAngle°');

  // Calculate lower arm outside angle
  double angleOutside = PostureCalculator.calculateLowerArmOutside(
    leftElbow, leftShoulder, leftHip,
    rightElbow, rightShoulder, rightHip,
  );
  print('Arm Working Outside Angle: $angleOutside°');
    setState(() {
      _keypointsMap[image] = keypoints;
    });
  }

  void calculatePosture(List<Keypoint> keypoints) {
    calculateUpperArmAngle(keypoints);
    calculateTrunkAngle(keypoints);
    calculateNeckAngle(keypoints);
    calculateLegAngle(keypoints);
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

                    // Original image dimensions
                    final int originalWidth = image_lib.decodeImage(image.readAsBytesSync())!.width;
                    final int originalHeight = image_lib.decodeImage(image.readAsBytesSync())!.height;

                    // Calculate scaling and padding
                    double scale = 256 / max(originalWidth, originalHeight); // Assuming inputSize is 256
                    double newWidth = originalWidth * scale;
                    double newHeight = originalHeight * scale;
                    double paddingX = 256 - newWidth;
                    double paddingY = 256 - newHeight;

                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Display image with padding
                          Container(
                            width: 256,
                            height: 256,
                            color: Colors.black, // Background for padding
                            child: Center(
                              child: Image.file(
                                image,
                                width: newWidth,
                                height: newHeight,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          // Draw keypoints on top of the image
                          if (keypoints != null)
                            CustomPaint(
                              size: Size(256, 256),
                              painter: KeypointsPainter(
                                keypoints,
                                paddingX,
                                paddingY,
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
  final double paddingX;
  final double paddingY;
  
  static const List<String> keypointLabels = [
    "Nose",
    "Left Eye",
    "Right Eye",
    "Left Ear",
    "Right Ear",
    "Left Shoulder",
    "Right Shoulder",
    "Left Elbow",
    "Right Elbow",
    "Left Wrist",
    "Right Wrist",
    "Left Hip",
    "Right Hip",
    "Left Knee",
    "Right Knee",
    "Left Ankle",
    "Right Ankle",
  ];

  KeypointsPainter(this.keypoints, this.paddingX, this.paddingY);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (var i = 0; i < keypoints.length; i++) {
      final keypoint = keypoints[i];
      if (keypoint.confidence > 0.4) {
        // Map normalized keypoints to 256x256 image
        final dx = keypoint.x * size.width;
        final dy = keypoint.y * size.height;

        // Draw the keypoint circle
        canvas.drawCircle(Offset(dx, dy), 2.0, paint);

        // Draw the keypoint label
        final label = keypointLabels[i];
        final textSpan = TextSpan(
          text: label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 8,
            fontWeight: FontWeight.bold,
          ),
        );
        textPainter.text = textSpan;
        textPainter.layout();

        // Position the text slightly above the keypoint
        textPainter.paint(
          canvas,
          Offset(dx - textPainter.width / 2, dy - 20), // Adjust position as needed
        );
      }
    }
  }


  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
double calculateAngle(
    Map<String, double> pointA, Map<String, double> pointB, Map<String, double> pointC) {
  final ax = pointA['x']!;
  final ay = pointA['y']!;
  final bx = pointB['x']!;
  final by = pointB['y']!;
  final cx = pointC['x']!;
  final cy = pointC['y']!;

  // Vectors AB and BC
  final AB = [ax - bx, ay - by];
  final BC = [cx - bx, cy - by];

  // Dot product and magnitudes
  final dotProduct = AB[0] * BC[0] + AB[1] * BC[1];
  final magnitudeAB = sqrt(AB[0] * AB[0] + AB[1] * AB[1]);
  final magnitudeBC = sqrt(BC[0] * BC[0] + BC[1] * BC[1]);

  // Calculate angle in radians
  double angle = acos(dotProduct / (magnitudeAB * magnitudeBC));

  // Convert to degrees
  return angle * (180 / pi);
}

void calculateUpperArmAngle(List<Keypoint> keypoints) {
  // Extract keypoints
  final leftShoulder = {
    'x': keypoints[5].x,
    'y': keypoints[5].y,
  };
  final leftElbow = {
    'x': keypoints[7].x,
    'y': keypoints[7].y,
  };
  final leftHip = {
    'x': keypoints[11].x,
    'y': keypoints[11].y,
  };

  final rightShoulder = {
    'x': keypoints[6].x,
    'y': keypoints[6].y,
  };
  final rightElbow = {
    'x': keypoints[8].x,
    'y': keypoints[8].y,
  };
  final rightHip = {
    'x': keypoints[12].x,
    'y': keypoints[12].y,
  };

  // Calculate angles
  final leftArmAngle = calculateAngle(leftElbow, leftShoulder, leftHip);
  final rightArmAngle = calculateAngle(rightElbow, rightShoulder, rightHip);

  print('Left Arm Angle: $leftArmAngle');
  print('Right Arm Angle: $rightArmAngle');
}

void calculateTrunkAngle(List<Keypoint> keypoints) {
  final leftShoulder = {
    'x': keypoints[5].x,
    'y': keypoints[5].y,
  };
  final rightShoulder = {
    'x': keypoints[6].x,
    'y': keypoints[6].y,
  };
  final leftHip = {
    'x': keypoints[11].x,
    'y': keypoints[11].y,
  };
  final rightHip = {
    'x': keypoints[12].x,
    'y': keypoints[12].y,
  };

  final midShoulder = {
    'x': (leftShoulder['x']! + rightShoulder['x']!) / 2,
    'y': (leftShoulder['y']! + rightShoulder['y']!) / 2,
  };
  final midHip = {
    'x': (leftHip['x']! + rightHip['x']!) / 2,
    'y': (leftHip['y']! + rightHip['y']!) / 2,
  };

  final trunkAngle = calculateAngle(midShoulder, midHip, {'x': midHip['x']!, 'y': midHip['y']! - 1}); // Vertical reference
  print('Trunk Angle: $trunkAngle');
}

void calculateNeckAngle(List<Keypoint> keypoints) {
  final leftEar = {
    'x': keypoints[3].x,
    'y': keypoints[3].y,
  };
  final rightEar = {
    'x': keypoints[4].x,
    'y': keypoints[4].y,
  };
  final leftShoulder = {
    'x': keypoints[5].x,
    'y': keypoints[5].y,
  };
  final rightShoulder = {
    'x': keypoints[6].x,
    'y': keypoints[6].y,
  };

  final midEar = {
    'x': (leftEar['x']! + rightEar['x']!) / 2,
    'y': (leftEar['y']! + rightEar['y']!) / 2,
  };
  final midShoulder = {
    'x': (leftShoulder['x']! + rightShoulder['x']!) / 2,
    'y': (leftShoulder['y']! + rightShoulder['y']!) / 2,
  };

  final neckAngle = calculateAngle(midEar, midShoulder, {'x': midShoulder['x']!, 'y': midShoulder['y']! - 1}); // Vertical reference
  print('Neck Angle: $neckAngle');
}

void calculateLegAngle(List<Keypoint> keypoints) {
  final leftHip = {
    'x': keypoints[11].x,
    'y': keypoints[11].y,
  };
  final leftKnee = {
    'x': keypoints[13].x,
    'y': keypoints[13].y,
  };
  final leftAnkle = {
    'x': keypoints[15].x,
    'y': keypoints[15].y,
  };

  final rightHip = {
    'x': keypoints[12].x,
    'y': keypoints[12].y,
  };
  final rightKnee = {
    'x': keypoints[14].x,
    'y': keypoints[14].y,
  };
  final rightAnkle = {
    'x': keypoints[16].x,
    'y': keypoints[16].y,
  };

  final leftLegAngle = calculateAngle(leftHip, leftKnee, leftAnkle);
  final rightLegAngle = calculateAngle(rightHip, rightKnee, rightAnkle);

  print('Left Leg Angle: $leftLegAngle');
  print('Right Leg Angle: $rightLegAngle');
}

class Vector2D {
  final double x;
  final double y;

  Vector2D(this.x, this.y);

  Vector2D operator +(Vector2D other) => Vector2D(x + other.x, y + other.y);
  Vector2D operator -(Vector2D other) => Vector2D(x - other.x, y - other.y);
  Vector2D operator /(double scalar) => Vector2D(x / scalar, y / scalar);
  double dot(Vector2D other) => x * other.x + y * other.y;
  double norm() => sqrt(x * x + y * y);
}

class PostureCalculator {
  static (double, double) calculateLowerArmAngle(
      Vector2D leftElbow, Vector2D leftWrist, Vector2D leftShoulder,
      Vector2D rightElbow, Vector2D rightWrist, Vector2D rightShoulder) {
    // LEFT ARM
    Vector2D vectorESLeft = leftElbow - leftShoulder;
    Vector2D vectorEWLeft = leftWrist - leftElbow;

    double normESLeft = vectorESLeft.norm();
    double normEWLeft = vectorEWLeft.norm();
    double dotProductLeft = vectorESLeft.dot(vectorEWLeft);

    double leftLowerArmDegrees = 0;
    if (normESLeft != 0 && normEWLeft != 0) {
      double lowerArmRadiansLeft = acos(dotProductLeft / (normESLeft * normEWLeft));
      leftLowerArmDegrees = lowerArmRadiansLeft * (180 / pi);
      print('Lower arm left angle: $leftLowerArmDegrees°');
    }

    // RIGHT ARM
    Vector2D vectorESRight = rightElbow - rightShoulder;
    Vector2D vectorEWRight = rightWrist - rightElbow;

    double normESRight = vectorESRight.norm();
    double normEWRight = vectorEWRight.norm();
    double dotProductRight = vectorESRight.dot(vectorEWRight);

    double rightLowerArmDegrees = 0;
    if (normESRight != 0 && normEWRight != 0) {
      double lowerArmRadiansRight = acos(dotProductRight / (normESRight * normEWRight));
      rightLowerArmDegrees = lowerArmRadiansRight * (180 / pi);
      print('Lower arm right angle: $rightLowerArmDegrees°');
    }

    return (leftLowerArmDegrees, rightLowerArmDegrees);
  }

  static double calculateLowerArmOutside(
      Vector2D leftElbow, Vector2D leftShoulder, Vector2D leftHip,
      Vector2D rightElbow, Vector2D rightShoulder, Vector2D rightHip) {
    Vector2D midShoulder = Vector2D(
      (leftShoulder.x + rightShoulder.x) / 2,
      (leftShoulder.y + rightShoulder.y) / 2,
    );

    // LEFT ARM
    Vector2D vectorESLeft = leftElbow - leftShoulder;
    Vector2D vectorHSLeft = leftHip - leftShoulder;

    double normESLeft = vectorESLeft.norm();
    double normHSLeft = vectorHSLeft.norm();
    double dotProductLeft = vectorESLeft.dot(vectorHSLeft);

    double leftAngleDegrees = 0;
    if (normESLeft != 0 && normHSLeft != 0) {
      double leftRadians = acos(dotProductLeft / (normESLeft * normHSLeft));
      leftAngleDegrees = leftRadians * (180 / pi);
    }

    // RIGHT ARM
    Vector2D vectorESRight = rightElbow - rightShoulder;
    Vector2D vectorHSRight = rightHip - rightShoulder;

    double normESRight = vectorESRight.norm();
    double normHSRight = vectorHSRight.norm();
    double dotProductRight = vectorESRight.dot(vectorHSRight);

    double rightAngleDegrees = 0;
    if (normESRight != 0 && normHSRight != 0) {
      double rightRadians = acos(dotProductRight / (normESRight * normHSRight));
      rightAngleDegrees = rightRadians * (180 / pi);
    }

    double angleOutside = max(leftAngleDegrees, rightAngleDegrees);
    if (angleOutside >= 30) {
      print('Arm working outside: $angleOutside°');
    } else {
      print('Arm not working outside: $angleOutside°');
    }

    return angleOutside;
  }

  static double calculateNeckAngle(
      Vector2D leftEar, Vector2D leftShoulder, Vector2D leftHip,
      Vector2D rightEar, Vector2D rightShoulder, Vector2D rightHip) {
    // Calculate midpoints
    Vector2D midEar = (leftEar + rightEar) / 2;
    Vector2D midShoulder = (leftShoulder + rightShoulder) / 2;
    Vector2D midHip = (leftHip + rightHip) / 2;

    // Calculate vectors
    Vector2D vectorES = midEar - midShoulder;
    Vector2D vectorSH = midShoulder - midHip;

    // Calculate norms
    double normES = vectorES.norm();
    double normSH = vectorSH.norm();

    // Calculate dot product
    double dotProduct = vectorES.dot(vectorSH);

    // Calculate neck angle in radians
    double neckAngleRadians = acos(dotProduct / (normES * normSH));

    // Convert to degrees
    double neckAngleDegrees = neckAngleRadians * (180 / pi);

    print('Neck Angle: $neckAngleDegrees°');
    return neckAngleDegrees;
  }
}

void main() {
  // Example usage
  Vector2D leftElbow = Vector2D(1, 2);
  Vector2D leftWrist = Vector2D(1, 3);
  Vector2D leftShoulder = Vector2D(0, 0);
  Vector2D rightElbow = Vector2D(-1, 2);
  Vector2D rightWrist = Vector2D(-1, 3);
  Vector2D rightShoulder = Vector2D(0, 0);

  Vector2D leftHip = Vector2D(0, 4);
  Vector2D rightHip = Vector2D(0, 4);

  // Calculate lower arm angles
  var (leftLowerArmAngle, rightLowerArmAngle) = PostureCalculator.calculateLowerArmAngle(
    leftElbow, leftWrist, leftShoulder,
    rightElbow, rightWrist, rightShoulder,
  );
  print('Left Lower Arm Angle: $leftLowerArmAngle°');
  print('Right Lower Arm Angle: $rightLowerArmAngle°');

  // Calculate lower arm outside angle
  double angleOutside = PostureCalculator.calculateLowerArmOutside(
    leftElbow, leftShoulder, leftHip,
    rightElbow, rightShoulder, rightHip,
  );
  print('Arm Working Outside Angle: $angleOutside°');
  
  
}