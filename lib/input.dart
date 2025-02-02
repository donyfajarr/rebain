import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:image/image.dart' as image_lib;
import 'classifier.dart';
import 'handclassifier.dart';
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
  Map<File, List<Keypoint>> _keypointsMap = {};
  bool _showKeypoints = true;
  late HandClassifier _handClassifier;
  Map<File, List<Handkeypoint>> _handKeypoints = {};

  @override
  void initState() {
    super.initState();
    _initializeClassifier();
  }

  Future<void> _initializeClassifier() async {
    _moveNetClassifier = MoveNetClassifier();
    _handClassifier = HandClassifier(numThreads: 4);
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

    List<Keypoint> keypoints = await _moveNetClassifier.processAndRunModel(imageInput);
    await _handClassifier.loadModel();
    List<Handkeypoint> handkeypoints = await _handClassifier.processAndRunModel(imageInput);

  Vector2D nose = Vector2D(keypoints[0].x, keypoints[0].y);

    // Convert keypoints to Vector2D
  Vector2D leftEye = Vector2D(keypoints[1].x, keypoints[1].y);
  Vector2D leftEar = Vector2D(keypoints[3].x, keypoints[3].y);
  Vector2D leftShoulder = Vector2D(keypoints[5].x, keypoints[5].y);
  Vector2D leftElbow = Vector2D(keypoints[7].x, keypoints[7].y);
  Vector2D leftWrist = Vector2D(keypoints[9].x, keypoints[9].y);
  Vector2D leftHip = Vector2D(keypoints[11].x, keypoints[11].y);
  Vector2D leftKnee = Vector2D(keypoints[13].x, keypoints[13].y);
  Vector2D leftAnkle = Vector2D(keypoints[15].x, keypoints[15].y);

  Vector2D rightEye = Vector2D(keypoints[2].x, keypoints[2].y);
  Vector2D rightEar = Vector2D(keypoints[4].x, keypoints[4].y);
  Vector2D rightShoulder = Vector2D(keypoints[6].x, keypoints[6].y);
  Vector2D rightElbow = Vector2D(keypoints[8].x, keypoints[8].y);
  Vector2D rightWrist = Vector2D(keypoints[10].x, keypoints[10].y);
  Vector2D rightHip = Vector2D(keypoints[12].x, keypoints[12].y);
  Vector2D rightKnee = Vector2D(keypoints[14].x, keypoints[14].y);
  Vector2D rightAnkle = Vector2D(keypoints[16].x, keypoints[16].y);

  Vector2D midShoulder = (leftShoulder + rightShoulder) / 2;
  Vector2D midHip = (leftHip + rightHip) / 2;
  Vector2D midKnee = (leftKnee + rightKnee) /2;

  // Calculate angles
  // A. Neck, Trunk, and Leg Analysis
  // 1. Locate Neck Position (+1 jika 10-20, +2 jika 20 - infinite, +2 jika negatif infinite - 0)
  double neckAngle = PostureCalculator.calculateNeckAngle(nose, midShoulder, midHip);
  print('Neck Angle: $neckAngle°');
  // 1.1 If Neck is twisted (+1 jika 5-infinite)
  double neckTwisted = PostureCalculator.calculateNeckTwisted(nose, leftEye, rightEye);
  print('Neck Twisted : $neckTwisted');

  // 1.2 If Neck is side bending (+1 jika 5-infinite)
  var (neckbendingleft, neckbendingright) = PostureCalculator.calculateNeckBending(leftEar, midShoulder, leftShoulder, rightEar, rightShoulder);
  print('Neck Bending Left: $neckbendingleft');
  print('Neck Bending Right: $neckbendingright');

  // Calculate Total Neck Score

  // 2. Locate Trunk Position (+1 jika 0, +2 jika -infinite - 0, +2 jika 0 - 20, +3 jika 20 - 60, +4 jika 60 - infinite)
  double trunkFlexion = PostureCalculator.calculateTrunkFlexion(midKnee, midHip, midShoulder);
  print('Trunk Flexion Angle: $trunkFlexion');

  // 2.1 If trunk is twisted (+1 jika 100 - infinite)
  double trunkTwisting = PostureCalculator.calculateTrunkTwisting(rightShoulder, midHip, rightHip, leftShoulder, leftHip);
  print('Trunk Twisting Angle: $trunkTwisting');

  // 2.2 If trunk is bending (+1 jika -infinite - 85, +1 jika 95 - infinite)
  var (leftbending, rightbending) = PostureCalculator.calculateTrunkBending(rightHip, midHip, midShoulder, leftHip);
  print('Trunk Bending Left Angle: $leftbending');
  print('Trunk Bending Right Angle: $rightbending');

  // Calculate Total Trunk Score

  // 3. Legs (+1 jika -5 - 5, +2 jika 5-infinite, +1 jika 30-60, +2 jika 60-infinite)
  double legs = PostureCalculator.calculateLegs(leftHip, leftKnee, leftAnkle, rightHip, rightKnee, rightAnkle);
  print('Leg Angle $legs');

  // Calculate Total Legs Score 

  // 4. Total score from 1-3

  // 5. Input for load/lbs,
  // +0 jika load <11 lbs, +1 jika load 11-22 lbs, +2 jika load >22 lbs
  // +1 jika shock or rapid build up force

  // 6. Total score 4 + 5 

  // B. Arm and Wrist Analysis
  // 7. Locate Upper Arm Position (+1 jika -20 -20, +2 jika -infinite - -20, +2 jika 20-45, +3 jika 45-90, +4 jika 90 - infinite)
  var (leftUpperArmAngle, rightupperArmAngle) = PostureCalculator.calculateUpperArmAngle(
    leftElbow, leftShoulder, leftHip,
    rightElbow, rightShoulder, rightHip,
  );
  print('Left Upper Arm Angle: $leftUpperArmAngle°');
  print('Right Upper Arm Angle: $rightupperArmAngle');
  // 7.1 If shoulder is raised +1
  var (statusshoulderraised, shoulderraiseddegree) = PostureCalculator.calculateShoulderRaised(leftShoulder, rightShoulder);
  print(statusshoulderraised);
  print('Diff: $shoulderraiseddegree');
  // 7.2 If upper arm is abducted +1
  var (statusabducted, upperarmabducteddegree) = PostureCalculator.calculateUpperArmAbducted(leftShoulder, leftElbow, midShoulder, rightShoulder, rightElbow);
  print(statusabducted);
  print('Diff: $upperarmabducteddegree');
  // 7.3 If arm is supported or person is leaning +1

  // input

  // Calculate Total Upper Arm Score

  // 8. Locate Lower Arm Position (+1 jika 60-100, +2 jika -infinite - 60 + 2 jika 100 - infinite)
  var (leftLowerArmAngle, rightLowerArmAngle) = PostureCalculator.calculateLowerArmAngle(
    leftElbow, leftWrist, leftShoulder,
    rightElbow, rightWrist, rightShoulder,
  );
  print('Left Lower Arm Angle: $leftLowerArmAngle°');
  print('Right Lower Arm Angle: $rightLowerArmAngle°');


  // Calculate Total Lower Arm Score

  // 9. Locate Wrist Position (+1 jika -15 - 15, +2 jika 15 - infinite, +2 jika -infinite - -15)

  // double wristAngle  = PostureCalculator.calculateWristAngle(
  //   leftWrist, rightWrist);
  //   print('Left Wrist Angle: $leftWrist');
  //   print('Right Wrist Angle: $rightWrist');


    setState(() {
      _keypointsMap[image] = keypoints;
      _handKeypoints[image] = handkeypoints;
    });
  }


  void _toggleKeypointsVisibility() {
    setState(() {
      _showKeypoints = !_showKeypoints;
    });
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text('Multiple Image Picker and MoveNet'),
      actions: [
          IconButton(
            icon: Icon(_showKeypoints ? Icons.visibility : Icons.visibility_off),
            onPressed: _toggleKeypointsVisibility,
            tooltip: _showKeypoints ? 'Hide Keypoints' : 'Show Keypoints',
          ),
        ],
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
                    final handkeypoints = _handKeypoints[image];

                    // Original image dimensions
                    final int originalWidth = image_lib.decodeImage(image.readAsBytesSync())!.width;
                    final int originalHeight = image_lib.decodeImage(image.readAsBytesSync())!.height;

                    // Calculate scaling and padding
                    double scale = 256 / max(originalWidth, originalHeight);
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
                          // if (keypoints != null && _showKeypoints)
                          //   CustomPaint(
                          //     size: Size(256, 256),
                          //     painter: KeypointsPainter(
                          //       keypoints,
                          //       paddingX,
                          //       paddingY,
                          //     ),
                          //   ),
                          if (handkeypoints != null)
                            CustomPaint(
                              size: Size(256, 256),
                              painter: HandKeypointsPainter(
                                handkeypoints,
                                paddingX,
                                paddingY,
                              ),
                            )
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

class Handkeypoint {
  final double x;
  final double y;
  final double confidence;

  Handkeypoint(this.x, this.y, this.confidence);
}

class HandKeypointsPainter extends CustomPainter {
  final List<Handkeypoint> handkeypoints;
  final double paddingX;
  final double paddingY;

  HandKeypointsPainter(this.handkeypoints, this.paddingX, this.paddingY);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.fill;
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (var i = 0; i < handkeypoints.length; i++) {
      final keypoint = handkeypoints[i];
      if (keypoint.confidence != 0) {
        print(keypoint.x);
        final dx = (keypoint.x  * size.width);
        
        // print(size.width);
        // print(dx);
        final dy = (keypoint.y  * size.height);
      
        print('Keypoints X 224 : $dx - Keypoints Y 224 : $dy');

        // Draw the keypoint circle
        canvas.drawCircle(Offset(dx, dy), 2.0, paint);

        // Draw the keypoint label
        // final label = keypointLabels[i];
        final textSpan = TextSpan(
          // text: label,
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
    return false; // Or true, depending on the use case
  }
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
      if (keypoint.confidence > 0.1) {
        
        final dx = keypoint.x * size.width;
        final dy = keypoint.y * size.height;
        print('Keypoints X 256 : $dx - Keypoints Y 256 : $dy');
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
  static double calculateAngle (Vector2D pointA, Vector2D pointB, Vector2D pointC){
    Vector2D vectorBA = pointA - pointB;
    Vector2D vectorBC = pointC - pointB;

    double dotProduct = vectorBA.dot(vectorBC);
    double magnitudeBA = vectorBA.norm();
    double magnitudeBC = vectorBC.norm();

    double angleRadians = acos(dotProduct / (magnitudeBA * magnitudeBC));
    return angleRadians * (180 / pi);
  }
  
  static (double, double) calculateLowerArmAngle(
      Vector2D leftElbow, Vector2D leftWrist, Vector2D leftShoulder,
      Vector2D rightElbow, Vector2D rightWrist, Vector2D rightShoulder) {
    double leftAngle = calculateAngle(leftWrist, leftElbow, leftShoulder);
    double rightAngle = calculateAngle(rightWrist, rightElbow, rightShoulder);

    return (leftAngle, rightAngle);
  }

   static (double, double) calculateUpperArmAngle(
      Vector2D leftElbow, Vector2D leftShoulder, Vector2D leftHip,
      Vector2D rightElbow, Vector2D rightShoulder, Vector2D rightHip) {
    double leftAngle = calculateAngle(leftElbow, leftShoulder, leftHip);
    double rightAngle = calculateAngle(rightElbow, rightShoulder, rightHip);

    return (leftAngle, rightAngle);
  }
  
  static (String, double) calculateUpperArmAbducted(
    Vector2D leftShoulder, Vector2D leftElbow, Vector2D midShoulder, Vector2D rightShoulder, Vector2D rightElbow){
      double leftAngle = calculateAngle(leftElbow, leftShoulder, midShoulder);
      double rightAngle = calculateAngle(rightElbow, rightShoulder, midShoulder);
      print('left abducted $leftAngle');
      print('right abducted $rightAngle');
      double angle = max(leftAngle, rightAngle);
      String status = angle > 110.0 ? "Upper Arm is Abducted" : "Upper Arm is not Abducted";
      return (status, angle);
    }


  static (String, double) calculateShoulderRaised(Vector2D leftShoulder, Vector2D rightShoulder) {
    double threshold = 30.0;
    double shoulderdiff = (leftShoulder.y - rightShoulder.y).abs();
    String status = shoulderdiff > threshold ? "shoulder is raised" : "shoulder is not raised";

    return (status, shoulderdiff);
  }

  static double calculateNeckAngle(Vector2D nose, Vector2D midShoulder, Vector2D midHip) {

    return calculateAngle(nose, midShoulder, midHip);
  }

  static double calculateNeckTwisted(Vector2D nose, Vector2D leftEye, Vector2D rightEye){
    double angle =  (90 - calculateAngle(nose, leftEye, rightEye)).abs();

    return angle;

  }

  static (double,double) calculateNeckBending(Vector2D leftEar, Vector2D midShoulder, Vector2D leftShoulder,
  Vector2D rightEar, Vector2D rightShoulder){
    double neckbendingleft = (65- calculateAngle(leftEar, midShoulder, leftEar)).abs();
    double neckbendingright = (65- calculateAngle(rightEar, midShoulder, rightEar)).abs();
    
    return (neckbendingleft, neckbendingright);
}
  static double calculateTrunkFlexion(Vector2D midknee, Vector2D midhip, Vector2D midshoulder){
    return calculateAngle(midknee, midhip, midshoulder);
  }
  static double calculateTrunkTwisting(Vector2D rightshoulder, Vector2D midhip, Vector2D righthip, Vector2D leftshoulder, Vector2D lefthip){
    double angle = max(calculateAngle(rightshoulder, midhip, righthip), calculateAngle(leftshoulder, midhip, lefthip));
    return angle;
  }
  static (double,double) calculateTrunkBending(Vector2D righthip,Vector2D midhip,Vector2D midshoulder,Vector2D lefthip){
  double rightangle = calculateAngle(righthip, midhip, midshoulder);
  double leftangle = calculateAngle(lefthip, midhip, midshoulder);
  return (rightangle,leftangle);
  }

  static double calculateLegs(Vector2D leftHip, Vector2D leftKnee, Vector2D leftAnkle, Vector2D rightHip, Vector2D rightKnee, Vector2D rightAnkle){
    double leftlegs = calculateAngle(leftHip, leftKnee, leftAnkle);
    double rightlegs = calculateAngle(rightHip, rightKnee, rightAnkle);
    return (max(leftlegs, rightlegs));
  }

  // static double calculateWrist(Vector2D leftWrist, Vector2D rightWrist){
    
  // }
}