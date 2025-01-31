import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:image/image.dart' as image_lib;
import 'classifier.dart';
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

    List<Keypoint> keypoints = await _moveNetClassifier.processAndRunModel(imageInput);


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
  var (leftLowerArmAngle, rightLowerArmAngle) = PostureCalculator.calculateLowerArmAngle(
    leftElbow, leftWrist, leftShoulder,
    rightElbow, rightWrist, rightShoulder,
  );
  print('Left Lower Arm Angle: $leftLowerArmAngle°');
  print('Right Lower Arm Angle: $rightLowerArmAngle°');

  var (statusarmworkingoutside, workingoutsideangle) = PostureCalculator.calculateLowerArmOutside(
    leftElbow,leftShoulder, leftHip, rightElbow, rightShoulder, rightHip);

    print('Status $statusarmworkingoutside');
    print('Angle Outside: $workingoutsideangle');

  var (leftUpperArmAngle, rightupperArmAngle) = PostureCalculator.calculateUpperArmAngle(
    leftElbow, leftShoulder, leftHip,
    rightElbow, rightShoulder, rightHip,
  );
  print('Left Upper Arm Angle: $leftUpperArmAngle°');
  print('Right Upper Arm Angle: $rightupperArmAngle');

  var (statusshoulderraised, shoulderraiseddegree) = PostureCalculator.calculateShoulderRaised(leftShoulder, rightShoulder);
  print(statusshoulderraised);
  print('Diff: $shoulderraiseddegree');

  var (statusabducted, upperarmabducteddegree) = PostureCalculator.calculateUpperArmAbducted(leftShoulder, leftElbow, midShoulder, rightShoulder, rightElbow);
  print(statusabducted);
  print('Diff: $upperarmabducteddegree');

  double neckAngle = PostureCalculator.calculateNeckAngle(nose, midShoulder, midHip);
  print('Neck Angle: $neckAngle°');

  double neckTwisted = PostureCalculator.calculateNeckTwisted(nose, leftEye, rightEye);
  print('Neck Twisted : $neckTwisted');

  var (neckbendingleft, neckbendingright) = PostureCalculator.calculateNeckBending(leftEar, midShoulder, leftShoulder, rightEar, rightShoulder);
  print('Neck Bending Left: $neckbendingleft');
  print('Neck Bending Right: $neckbendingright');

  double trunkFlexion = PostureCalculator.calculateTrunkFlexion(midKnee, midHip, midShoulder);
  print('Trunk Flexion Angle: $trunkFlexion');

  double trunkTwisting = PostureCalculator.calculateTrunkTwisting(rightShoulder, midHip, rightHip, leftShoulder, leftHip);
  print('Trunk Twisting Angle: $trunkTwisting');

  var (leftbending, rightbending) = PostureCalculator.calculateTrunkBending(rightHip, midHip, midShoulder, leftHip);
  print('Trunk Bending Left Angle: $leftbending');
  print('Trunk Bending Right Angle: $rightbending');

  // TO DO

  // TRUNK FLEXION ANGLE
  // TRUNK TWISTING ANGLE
  // TRUNK BENDING ANGLE
  // LEGS

  // WRIST POSITION ??

  
  // INPUT
  // ADD FORCE INPUT
  // IF ARM IS SUPPORTED OR PERSON IS LEANING
  
  // DONE
  // UPPER ARM POSITION
  // SHOULDER RAISED
  // UPPER ARM ABDUCTED
  // LOWER ARM POSITION
  // LOWER ARM WORKING OUTSIDE
  // UPPER ARM

  // NEED CHECK
  // NECK ANGLE
  // NECK TWISTING ANGLE
  // NECK BENDING ANGLE

    setState(() {
      _keypointsMap[image] = keypoints;
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
                            color: Colors.white, // Background for padding
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
                          if (keypoints != null && _showKeypoints)
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
      if (keypoint.confidence > 0.1) {
        
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
  static (String, double) calculateLowerArmOutside(Vector2D leftElbow, Vector2D leftShoulder,
  Vector2D leftHip, Vector2D rightElbow, Vector2D rightShoulder, Vector2D rightHip) {
    double threshold = 30.0;
    double leftAngle = calculateAngle(leftElbow,leftHip, leftShoulder);
    double rightAngle = calculateAngle(rightElbow,rightHip, rightShoulder);
    double angle = max(leftAngle, rightAngle);
    String status = angle >= threshold ? "Arm Working Outside" : "Arm not Working Outside";
    return (status, angle);
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
    double neckbendingleft = (65- calculateAngle(leftEar, midShoulder, rightEar)).abs();
    double neckbendingright = (65- calculateAngle(rightEar, midShoulder, leftEar)).abs();
    
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

}