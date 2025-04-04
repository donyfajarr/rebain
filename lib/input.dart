import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:image/image.dart' as image_lib;
import 'classifier.dart';
import 'dart:math';
import 'report.dart';
late TextEditingController _loadController;

Map<String, int> segmentScores = {};

class Keypoint {
  final double x;
  final double y;
  final double confidence;

  Keypoint(this.x, this.y, this.confidence);

}

class VectorPainter extends CustomPainter {
  final List<Keypoint> keypoints;
  final String segmentName;
  final double paddingX;
  final double paddingY;
  final String? _selectedSide;
  

    VectorPainter(this.keypoints, this.segmentName, this.paddingX, this.paddingY, this._selectedSide);
    @override
    void paint(Canvas canvas, Size size) {
      final paintKeypoints = Paint()
        ..color = Colors.red
        ..style = PaintingStyle.fill;
      final paintLines = Paint()
        ..color = Colors.blue
        ..strokeWidth = 2.0;

      final textPainter = TextPainter(
        textDirection: TextDirection.ltr,
      );

    List<List<int>> connections = [];
    List<int> relevantKeypoints = [];
    Offset? midShoulder, midHip, midKnee, midEar;
     switch (segmentName.toLowerCase()) {
      case "neck":
        relevantKeypoints = [3, 4, 5, 6, 11, 12];
        midEar = _calculateMidpoint(keypoints, 3, 4, size);
        midShoulder = _calculateMidpoint(keypoints, 5, 6, size);
        midHip = _calculateMidpoint(keypoints, 11, 12, size);
        connections = [[-4, -1], [-1, -2]];
        break;

      case "trunk":
        relevantKeypoints = [11, 12, 5, 6];
        midShoulder = _calculateMidpoint(keypoints, 5, 6, size);
        midHip = _calculateMidpoint(keypoints, 11, 12, size);
        double virtualY = midHip!.dy + 50; // Adjust +50 as needed
        midKnee = Offset(midHip!.dx, virtualY);
        connections = [[-1, -2], [-2, -3]];
        break;

      case "legs & posture":
        
        if (_selectedSide == "left"){
          connections = [
          [11, 13], [13, 15],];
          relevantKeypoints = [11, 13, 15];
        }
        else {
          connections = [
          [12, 14], [14, 16] 
        ];
        relevantKeypoints = [12, 14, 16];
        }
        break;

      case "upper arm":
        if (_selectedSide == "left"){
          connections = [
          [7, 5], [5, 11]];
          relevantKeypoints = [5,7,11];
        }
        else {
          connections = [
          [8, 6], [6, 12]];
        relevantKeypoints = [6,8,12];
        }

        break;

      case "lower arm":
        if (_selectedSide == "left"){
          connections = [
          [9, 7], [7, 5]];
          relevantKeypoints = [7,9,5];
        }
        else {
          connections = [
          [10, 8], [8, 6]];
        relevantKeypoints = [6,8,10];
        }

        break;

      case "wrist":
        if (keypoints.isEmpty) return;
        if (_selectedSide == "left"){
          connections = [
          [7, 9], [9, 17]];
          relevantKeypoints = [7,9,17];
        }
        else {
          connections = [
          [8, 10], [10, 17]];
        relevantKeypoints = [8,10,17];
        }
        break;

    }
   
    // Draw individual keypoints
    for (var index in relevantKeypoints) {
      final keypoint = keypoints[index];
      if (keypoint.confidence > 0) {
        final dx = keypoint.x * size.width;
        final dy = keypoint.y * size.height;
        canvas.drawCircle(Offset(dx, dy), 4.0, paintKeypoints);
      }
    }

    
    // Draw midpoints
    if (midShoulder != null) canvas.drawCircle(midShoulder!, 4.0, paintKeypoints);
    if (midHip != null) canvas.drawCircle(midHip!, 4.0, paintKeypoints);
    if (midKnee != null) canvas.drawCircle(midKnee!, 4.0, paintKeypoints);
    if (midEar != null) canvas.drawCircle(midEar!,4.0, paintKeypoints);
    // Draw connections
    for (var pair in connections) {
      Offset? p1, p2;

      if (pair[0] == -1) p1 = midShoulder;
      else if (pair[0] == -2) p1 = midHip;
      else if (pair[0] == -3) p1 = midKnee;
      else if (pair[0] == -4) p1 = midEar;
      else p1 = keypoints[pair[0]].confidence > 0
          ? Offset(keypoints[pair[0]].x * size.width, keypoints[pair[0]].y * size.height)
          : null;

      if (pair[1] == -1) p2 = midShoulder;
      else if (pair[1] == -2) p2 = midHip;
      else if (pair[1] == -3) p2 = midKnee;
      else if (pair[1] == -4) p2 = midEar;
      else p2 = keypoints[pair[1]].confidence > 0
          ? Offset(keypoints[pair[1]].x * size.width, keypoints[pair[1]].y * size.height)
          : null;
      
      if (p1 != null && p2 != null) {
        canvas.drawLine(p1, p2, paintLines);
      }
    }
  }

  /// Calculates the midpoint between two keypoints
  Offset? _calculateMidpoint(List<Keypoint> keypoints, int kp1, int kp2, Size size) {
    if (keypoints[kp1].confidence < 0 || keypoints[kp2].confidence < 0) return null;
    double x = (keypoints[kp1].x + keypoints[kp2].x) / 2;
    double y = (keypoints[kp1].y + keypoints[kp2].y) / 2;
    return Offset(x * size.width, y * size.height);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class Vector2D {
  final double x;
  final double y;

  Vector2D(this.x, this.y);

  double distanceTo(Vector2D other) {
    return sqrt(pow(other.x - x, 2) + pow(other.y - y, 2));
  }

  Vector2D? getKeypoint(List<Keypoint> keypoints, int index) {
    if (index >= 0 && index < keypoints.length && keypoints[index].confidence > 0) {
      return Vector2D(keypoints[index].x, keypoints[index].y);
    }
    return null;
  }

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
  static (double,double) calculateUpperArmAbducted(
    Vector2D leftShoulder, Vector2D leftElbow, Vector2D midShoulder, Vector2D rightShoulder, Vector2D rightElbow){
      double leftAngle = calculateAngle(leftElbow, leftShoulder, midShoulder);
      double rightAngle = calculateAngle(rightElbow, rightShoulder, midShoulder);
      return (leftAngle, rightAngle);
    }
  static double calculateShoulderRaised(Vector2D leftShoulder, Vector2D rightShoulder) {
    double shoulderdiff = (leftShoulder.y - rightShoulder.y).abs();
    return (shoulderdiff);
  }

  static double calculateNeckAngle(Vector2D midEar, Vector2D midShoulder, Vector2D midHip) {

    return calculateAngle(midEar, midShoulder, midHip);
  }
  static double calculateNeckTwisted(Vector2D nose, Vector2D leftShoulder, Vector2D rightShoulder) {
    Vector2D midShoulder = (leftShoulder + rightShoulder) / 2;
     // Corrected: Check angle in the horizontal plane
    double verticalDiff = (nose.x - midShoulder.x).abs();

    return verticalDiff;
  }
  
  static double calculateNeckBending(Vector2D leftEar, Vector2D midShoulder, Vector2D leftShoulder,
  Vector2D rightEar, Vector2D rightShoulder){
    double neckBendingLeft = (65- calculateAngle(leftEar, midShoulder, leftShoulder)).abs();
    double neckBendingRight = (65- calculateAngle(rightEar, midShoulder, rightShoulder)).abs();
    double meanNeckBending = (neckBendingLeft + neckBendingRight) / 2;
    
    return (65 - meanNeckBending).abs();
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
  static (double,double) calculateLegs(Vector2D leftHip, Vector2D leftKnee, Vector2D leftAnkle, Vector2D rightHip, Vector2D rightKnee, Vector2D rightAnkle){
    double leftlegs = calculateAngle(leftHip, leftKnee, leftAnkle);
    double rightlegs = calculateAngle(rightHip, rightKnee, rightAnkle);
    return (leftlegs, rightlegs);
  }
  static double calculateWristAngle(Vector2D chosenWrist, Vector2D chosenElbow, Vector2D chosen){
    double angle = calculateAngle(chosenElbow, chosenWrist, chosen);
    return angle;
  // }
  }
}

class ImagePickerScreen extends StatefulWidget {
  @override
  _ImagePickerScreenState createState() => _ImagePickerScreenState();
}

class _ImagePickerScreenState extends State<ImagePickerScreen> {
  final ImagePicker _picker = ImagePicker();
  late MoveNetClassifier _moveNetClassifier;
  bool _isModelReady = false;
  bool _showSelectionUI = false;
  bool _isProcessing = false; 
  Offset? _selectedPoint;
  int originalWidth = 0;
  int originalHeight = 0;
  int _currentStep = 0; 

  File? _capturedImage; // Single image for all segments
  Map<String, File?> _capturedImages = {}; // Each body part gets one image
  Map<String, List<Keypoint>> _keypointsMap = {};
  Map<String, Map<String, List<double>>> _anglesMap = {};
  String? _selectedSide;
  


  List<String> _bodySegments = [
    "All",
    "Neck",
    "Trunk",
    "Legs & Posture",
    "Force Load Score",
    "Upper Arm",
    "Arm Supported",
    "Lower Arm",
    "Wrist",
    "Coupling Score",
    "Activity Score",
  ];



  @override
  void initState() {
    super.initState();
    _initializeClassifier();
    _loadController = TextEditingController(
  );
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

  Future<void> _pickAll(ImageSource source) async {
  final pickedFile = await _picker.pickImage(source: source);
  if (pickedFile != null && _isModelReady) {
    final image = File(pickedFile.path);
    final image_lib.Image? decodedImage = image_lib.decodeImage(image.readAsBytesSync());

    if (decodedImage != null) {
      setState(() {
        _capturedImage = image;
        for (String segment in ["Neck", "Trunk", "Legs & Posture", "Upper Arm", "Lower Arm"]) {
          _capturedImages[segment] = image;
        }
        _capturedImages["Wrist"] = image;
        originalWidth = decodedImage.width;
        originalHeight = decodedImage.height;
        _selectedSide = null;
        _showSelectionUI = true;
      });
    } else {
      print("❌ Failed to decode image.");
    }
  } else if (!_isModelReady) {
    print("⚠️ Model is not ready yet!");
  } else {
    print("⚠️ No image selected.");
  }
}

  Future<void> _pickImage(ImageSource source) async {
  final pickedFile = await _picker.pickImage(source: source);
  if (pickedFile != null && _isModelReady) {
    final image = File(pickedFile.path);
    final image_lib.Image? decodedImage = image_lib.decodeImage(image.readAsBytesSync());

    if (decodedImage != null) {
      setState(() {
        _capturedImages[_bodySegments[_currentStep]] = image;
        originalWidth = decodedImage.width;
        originalHeight = decodedImage.height; // ✅ Ensure dimensions are set

        if (_bodySegments[_currentStep].toLowerCase() == "wrist" ) {
          _showSelectionUI = true; // Enable point selection for wrist
          _selectedPoint = null; // Reset previous selection
        }
      });
        if (_bodySegments[_currentStep].toLowerCase() != "wrist" ){
        await _predict(image, _bodySegments[_currentStep]);}
    } else {
      print("❌ Failed to decode image.");
    }
  } else if (!_isModelReady) {
    print("⚠️ Model is not ready yet!");
  } else {
    print("⚠️ No image selected.");
  }
}

  Future<void> _predict(File image, String segment, [List<Keypoint>? existingKeypoints]) async {
    final imageInput = image_lib.decodeImage(image.readAsBytesSync())!;
    List<Keypoint> keypoints = await _moveNetClassifier.processAndRunModel(imageInput);
    
    print('Segment $segment');

    setState(() {
    _keypointsMap[segment] = keypoints;
     if (segment.toLowerCase() == "wrist" && existingKeypoints != null) {
      print('asup');
      if (existingKeypoints.isNotEmpty) { 
        print(existingKeypoints[0].x); // Debug: Check the passed keypoints
        print('✅ Manually added wrist keypoint included');

        // Ensure we append it as the 18th keypoint
        if (_keypointsMap[segment]!.length == 17) { 
          _keypointsMap[segment]!.add(existingKeypoints[0]); // ✅ Add manually selected keypoint as the 18th
        } else {
          print("⚠️ WARNING: Unexpected keypoint length for wrist.");
        }
      } else {
        print("⚠️ WARNING: No manually selected keypoints provided.");
      }
    }
    
    print('Keypoint for $segment : ${_keypointsMap[segment]}');
    if (_keypointsMap[segment] == null || _keypointsMap[segment]!.isEmpty) {
      print("❌ ERROR: No keypoints detected for segment: $segment");
      return;
    }
  });

    // Convert keypoints to Vector2D
  Vector2D nose = Vector2D(keypoints[0].x, keypoints[0].y);
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
  Vector2D midEar = (leftEar + rightEar) /2;
  Vector2D virtualY = Vector2D(midHip.x, midHip.y + 50);

  // Calculate angles
  // A. Neck, Trunk, and Leg Analysis
  // 1. Locate Neck Position (+1 jika 10-20, +2 jika 20 - infinite, +2 jika negatif infinite - 0)
  if (segment.toLowerCase() == "neck") {
  int neckScore = 0;

  // 1️⃣ Calculate Neck Flexion/Extension Score
  double neckAngle = 180.0 - PostureCalculator.calculateNeckAngle(midEar, midShoulder, midHip);

  print('Neck Angle: $neckAngle°');
  

  if (neckAngle >= 10 && neckAngle < 20) {
    neckScore += 1;
  } else if (neckAngle > 20 || neckAngle <= 0) {
    neckScore += 2;
  }

  // 2️⃣ Check for Twisting and Bending (Only Add +1 Once)
  double neckTwisted = PostureCalculator.calculateNeckTwisted(nose, leftShoulder, rightShoulder);
  var neckBend = PostureCalculator.calculateNeckBending(
    leftEar, midShoulder, leftShoulder, rightEar, rightShoulder
  );

  
  print("Neck Bending : $neckBend");
  // print("Neck Bending Right : $neckBendingRight");
  print("Neck Twisted : $neckTwisted");
  // If either twisting or bending exists, add only +1
  // double neckBend = (neckBendingLeft - neckBendingRight).abs();

  segmentScores["neckTwisted"] = 0;
  segmentScores["neckBended"] = 0;

  if (neckTwisted >= 10) {
    segmentScores["neckTwisted"] = 1;
    }
  if (neckBend>= 10) {
    segmentScores["neckBended"] = 1;
  }
  // if (neckTwisted >= 10 || neckBend >= 10) {
    // neckScore += 1;
  // };

  if (!_anglesMap.containsKey(segment)) {
  _anglesMap[segment] = {};
}

// Add Neck Twisting and Bending to the _anglesMap
  _anglesMap[segment]!["Neck Angle"] = [neckAngle];
  _anglesMap[segment]!["Neck Twist"] = [neckTwisted];
  _anglesMap[segment]!["Neck Bending"] = [neckBend];

  
  segmentScores["neckScore"] = neckScore;
  print('Total Neck Score: $neckScore');
}

  // 2. Locate Trunk Position (+1 jika 0, +2 jika -infinite - 0, +2 jika 0 - 20, +3 jika 20 - 60, +4 jika 60 - infinite)
  if (segment.toLowerCase() == "trunk") {
  int trunkScore = 0;

  // Calculate Trunk Flexion/Extension Score
  double trunkFlexion = 180.0 - PostureCalculator.calculateTrunkFlexion(virtualY, midHip, midShoulder);
  print('Trunk Flexion Angle: $trunkFlexion');

   if (trunkFlexion >= -5 && trunkFlexion <= 5) {
    trunkScore += 1;
  } else if (trunkFlexion < -5) {
    trunkScore += 2;
  } else if (trunkFlexion > 5 && trunkFlexion <= 20) {
    trunkScore += 2;
  } else if (trunkFlexion > 20 && trunkFlexion <= 60) {
    trunkScore += 3;
  } else if (trunkFlexion > 60) {
    trunkScore += 4;
  }
 
  // 2️⃣ Check for Twisting and Bending (Only Add +1 Once)
  double trunkTwisting = PostureCalculator.calculateTrunkTwisting(
    rightShoulder, midHip, rightHip, leftShoulder, leftHip
  );
  var (leftBending, rightBending) = PostureCalculator.calculateTrunkBending(
    rightHip, midHip, midShoulder, leftHip
  );

  print('Trunk Twisting Angle: $trunkTwisting');
  print('Trunk Bending Left Angle: $leftBending');
  print('Trunk Bending Right Angle: $rightBending');

  double trunkBend = max(leftBending, rightBending);
  segmentScores["trunkTwisted"] = 0;
  segmentScores["trunkBended"] = 0;
  // Initialize trunkScore
  if (trunkTwisting >= 100) {
    segmentScores["trunkTwisted"] = 1;
    // trunkScore += 1;
  }
  if (leftBending <= 85 || leftBending >= 95 || rightBending <= 85 || rightBending >= 95) {
    segmentScores["trunkBended"] = 1;
    // trunkScore += 1;
  }

  if (!_anglesMap.containsKey(segment)) {
  _anglesMap[segment] = {};
}


  _anglesMap[segment]!["Trunk Angle"] = [trunkFlexion];
  _anglesMap[segment]!["Trunk Twist"] = [trunkTwisting];
  _anglesMap[segment]!["Trunk Bending"] = [trunkBend];




  // 3️⃣ Store Final Trunk Score
  segmentScores["trunkScore"] = trunkScore;
 
  print('Total Trunk Score: $trunkScore');
}
 
  // 3. Legs (+1 jika -5 - 5, +2 jika 5-infinite, +1 jika 30-60, +2 jika 60-infinite)

  if (segment.toLowerCase() == "legs & posture"){
  int legScore = 0;

  var(leftLegs, rightLegs) = PostureCalculator.calculateLegs(leftHip, leftKnee, leftAnkle, rightHip, rightKnee, rightAnkle);
  double legs = 0;
  if (_selectedSide == "left"){
    legs = leftLegs;
    _anglesMap[segment] = {
        "Legs & Posture": [leftLegs]
      };
  }
  else {
    legs = rightLegs;
    _anglesMap[segment] = {
      "Legs & Posture" : [rightLegs]
    };
  }
  print('Leg Angle $leftLegs');
  print('RLeg Angle $rightLegs');
  
    
  if (legs >=30 && legs<=60){
    legScore +=1;
  } else if (legs >60){
    legScore +=2;
  }

    // Calculate Total Legs Score 
    segmentScores['legRaised'] = 1;
    segmentScores['legScore'] = legScore;
    print('Total Leg Score : $legScore');
  }

  // B. Arm and Wrist Analysis
  // 7. Locate Upper Arm Position (+1 jika -20 -20, +2 jika -infinite - -20, +2 jika 20-45, +3 jika 45-90, +4 jika 90 - infinite)
  if (segment.toLowerCase() == "upper arm"){
  int upperArmScore = 0;
  double selectedUpper = 0;
  

  var (leftUpperArmAngle, rightupperArmAngle) = PostureCalculator.calculateUpperArmAngle(
    leftElbow, leftShoulder, leftHip,
    rightElbow, rightShoulder, rightHip,
  );
  print('Left Upper Arm Angle: $leftUpperArmAngle°');
  print('Right Upper Arm Angle: $rightupperArmAngle');

  if(_selectedSide == "left"){
    selectedUpper = leftUpperArmAngle;

   if (leftUpperArmAngle >= -20 && leftUpperArmAngle <= 20){
      upperArmScore += 1;
    }
    else if (rightupperArmAngle <-20){
      upperArmScore +=2;
    }
    else if (leftUpperArmAngle>20 && leftUpperArmAngle<=45){
      upperArmScore +=2;
    }
    else if (leftUpperArmAngle>45 && leftUpperArmAngle <= 90){
      upperArmScore +=3;
    }
    else if (leftUpperArmAngle > 90){
      upperArmScore +=4;
    }
  }
  else{
    selectedUpper = rightupperArmAngle;

    if (rightupperArmAngle >= -20 && rightupperArmAngle <= 20){
      upperArmScore += 1;
    }
    else if (rightupperArmAngle <-20){
      upperArmScore +=2;
    }
    else if (rightupperArmAngle>20 && rightupperArmAngle<=45){
      upperArmScore +=2;
    }
    else if (rightupperArmAngle>45 && rightupperArmAngle <= 90){
      upperArmScore +=3;
    }
    else if (rightupperArmAngle > 90){
      upperArmScore +=4;
    }
  }

  // 7.1 If shoulder is raised +1 >30
  var shoulderraiseddegree = PostureCalculator.calculateShoulderRaised(leftShoulder, rightShoulder);

  print('Shoulder Raised: $shoulderraiseddegree');

  segmentScores['shoulderRaised'] = 0;
  if (shoulderraiseddegree >=30){
  //  upperArmScore +=1;
   segmentScores['shoulderRaised'] = 1;
  }

  // 7.2 If upper arm is abducted +1 >110
  var (leftUpperArmAbducted, rightUpperArmAbducted) = PostureCalculator.calculateUpperArmAbducted(leftShoulder, leftElbow, midShoulder, rightShoulder, rightElbow);
  
  print('Left Upper Arm Abducted : $leftUpperArmAbducted');
  print('Right Upper Arm Abducted : $rightUpperArmAbducted');
  segmentScores['upperArmAbducted'] = 0;
  segmentScores['armSupport'] = 0;
  if (max(leftUpperArmAbducted, rightUpperArmAbducted) >=110){
    // upperArmScore +=1;
    segmentScores['upperArmAbducted'] = 1;
  }
  
    if (!_anglesMap.containsKey(segment)) {
  _anglesMap[segment] = {};
}


  _anglesMap[segment]!["Upper Arm Angle"] = [selectedUpper];
  _anglesMap[segment]!["Shoulder Raised"] = [shoulderraiseddegree];
  _anglesMap[segment]!["Shoulder Abducted"] = [max(leftUpperArmAbducted, rightUpperArmAbducted)];


  segmentScores ['upperArmScore'] = upperArmScore;
  print('Total Upper Arm Score: $upperArmScore');

  // Calculate Total Upper Arm Score
  }
  // 8. Locate Lower Arm Position (+1 jika 60-100, +2 jika -infinite - 60 + 2 jika 100 - infinite)
  if (segment.toLowerCase() == "lower arm") {
  int lowerArmScore = 0;
  var (leftLowerArmAngle, rightLowerArmAngle) = PostureCalculator.calculateLowerArmAngle(
    leftElbow, leftWrist, leftShoulder,
    rightElbow, rightWrist, rightShoulder,
  );
  leftLowerArmAngle = 180.0 - leftLowerArmAngle;
  rightLowerArmAngle = 180.0 - rightLowerArmAngle;

  print('Left Lower Arm Angle: $leftLowerArmAngle°');
  print('Right Lower Arm Angle: $rightLowerArmAngle°');
  

  if (_selectedSide == "Left"){
    _anglesMap[segment] = {
      "Lower Arm": [leftLowerArmAngle],
    };

    if (leftLowerArmAngle >= 60 && leftLowerArmAngle <= 100) {
      lowerArmScore += 1;
    } else if (leftLowerArmAngle < 60) {
      lowerArmScore += 2;
    } else if (leftLowerArmAngle > 100) {
      lowerArmScore += 2;
    }
  }
  else {
    _anglesMap[segment] = {
      "Lower Arm": [rightLowerArmAngle],
    };

    if (rightLowerArmAngle >= 60 && rightLowerArmAngle <= 100) {
      lowerArmScore += 1;
    } else if (rightLowerArmAngle < 60) {
      lowerArmScore += 2;
    } else if (rightLowerArmAngle > 100) {
      lowerArmScore += 2;
    }
  }

  

  // Calculate Total Lower Arm Score
  segmentScores ['lowerArmScore'] = lowerArmScore;
  print('Total Lower Arm Score: $lowerArmScore');

  }
  // 9. Locate Wrist Position (+1 jika -15 - 15, +2 jika 15 - infinite, +2 jika -infinite - -15)

    if (segment.toLowerCase() == 'wrist'){
      Vector2D chosen = Vector2D(keypoints[17].x, keypoints[17].y);
      double wristAngle = 180.0 - PostureCalculator.calculateWristAngle(leftWrist, leftElbow, chosen);
      
      print('Wrist Angle: $wristAngle');
      _anglesMap[segment] = {
          "Wrist": [wristAngle],
        };

      int wristScore = 0;
      if (wristAngle >=-15 && wristAngle <=15){
        wristScore +=1;
      } else if (wristAngle <-15 || wristAngle >15){
        wristScore +=2;
      }
      segmentScores['wristScore'] = wristScore;
      print('Total Wrist Score: $wristScore');
      segmentScores['activityScore'] = 0;
      segmentScores['unstableBase'] = 0;
      segmentScores['staticPosture'] = 0;
      segmentScores['repeatedAction'] = 0;
      segmentScores['coupling'] = 0;
      
    }
    }

  void _submitAndProcess() async {
  if (_selectedSide == null) {
    return;
  }

  for (String segment in ["Neck", "Trunk", "Legs & Posture", "Upper Arm", "Lower Arm"]) {
    if (_capturedImages[segment] != null) {
      await _predict(_capturedImages[segment]!, segment, []);
    }
  }

  _nextSegment();
}

  void _nextSegment() {
    if (_currentStep < _bodySegments.length - 1) {
      setState(() {
        _currentStep++;
      });
    } else {
    print(segmentScores);
    print('sdssssssssssss');
    // Navigate to the REBA report screen when reaching the last segment
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RebaReportScreen(
          bodyPartScores: segmentScores,
          capturedImages: _capturedImages,
          keypoints: _keypointsMap,
          side : _selectedSide,
        ),
      ),
    );
  }
}

  void _previousSegment() {
  if (_currentStep > 0) {
    setState(() {
      _currentStep--;
    });
  }
}
  
  @override
  Widget build(BuildContext context) {
    String currentSegment = _bodySegments[_currentStep];

    return Scaffold(
      appBar: AppBar(
        title: Text('REBA Assessment', style:TextStyle(fontSize:16, fontFamily:'Poppins', fontWeight: FontWeight.w600)),
        leading: IconButton(
      icon: Icon(Icons.arrow_back),
      onPressed: _previousSegment, // Navigates back to the last segment
    ),
      ),
      body: Padding(
    padding: const EdgeInsets.all(8.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (currentSegment.toLowerCase() == "all") ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                child: Text(
                  "Take a photo or import an existing image to evaluate posture.",
                  style: TextStyle(fontSize: 12, fontFamily: 'Poppins'),
                ),
              ),
              SizedBox(height: 10),

              // Image Display Area
              Container(
                margin: EdgeInsets.symmetric(horizontal: 16),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 256,
                      height: 256,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.green, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _capturedImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                _capturedImage!,
                                width: 256,
                                height: 256,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Center(
                              child: Text(
                                "No image captured.",
                                style: TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'Poppins'),
                                textAlign: TextAlign.center,
                              ),
                            ),
                    ),
                    SizedBox(height: 20),

                    // Left/Right Selection Buttons
                    if (_capturedImage != null) ...[
                      Text("Select the side to analyze:", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: () => setState(() => _selectedSide = "Left"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _selectedSide == "Left" ? Color.fromRGBO(55, 149, 112, 1) : Colors.white,
                              side: BorderSide(color: Color.fromRGBO(55, 149, 112, 1)),
                            ),
                            child: Text(
                              "Left",
                              style: TextStyle(
                                color: _selectedSide == "Left" ? Colors.white : Color.fromRGBO(55, 149, 112, 1),
                              ),
                            ),
                          ),
                          SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: () => setState(() => _selectedSide = "Right"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _selectedSide == "Right" ? Color.fromRGBO(55, 149, 112, 1) : Colors.white,
                              side: BorderSide(color: Color.fromRGBO(55, 149, 112, 1)),
                            ),
                            child: Text(
                              "Right",
                              style: TextStyle(
                                color: _selectedSide == "Right" ? Colors.white : Color.fromRGBO(55, 149, 112, 1),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                    ],

                    // Submit Button (Only visible after selecting side)
                    if (_capturedImage != null && _selectedSide != null)
                      ElevatedButton(
                        onPressed: _isProcessing ? null : _submitAndProcess, // Disable when processing
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isProcessing ? Colors.grey : Color.fromRGBO(55, 149, 112, 1), // Grey when loading
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        child: _isProcessing
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text("Submit", style: TextStyle(color: Colors.white)),
                      ),
                  ],
                ),
              ),

              SizedBox(height: 20),

              // Image Upload Buttons
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          side: BorderSide(color: Color.fromRGBO(55, 149, 112, 1)),
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        onPressed: _isModelReady ? () => _pickAll(ImageSource.gallery) : null,
                        child: Text(
                          'Gallery',
                          style: TextStyle(color: Color.fromRGBO(55, 149, 112, 1), fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                      SizedBox(width: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          side: BorderSide(color: Color.fromRGBO(55, 149, 112, 1)),
                        ),
                        onPressed: _isModelReady ? () => _pickAll(ImageSource.camera) : null,
                        child: Text(
                          'Scan',
                          style: TextStyle(color: Color.fromRGBO(55, 149, 112, 1), fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ]
        else if (currentSegment.toLowerCase() == "force load score") ...[
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(8), // Add padding to prevent cut-off
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Grey Background Container with Centered Image
                  Container(
                    height: 256, // Adjust as needed
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Color.fromRGBO(244, 246, 245, 1), // Light grey background
                      borderRadius: BorderRadius.circular(12), // Rounded corners
                    ),
                    child: Center(
                      child: Image.asset(
                        'assets/forceload.png', // Ensure this path is correct
                        height: 100, // Adjust image size as needed
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  SizedBox(height: 10),

                  // Centered Text Below the Image
                  Text(
                    "Force/Load Analysis",
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 15),

                  Text(
                    "Enter Force/Load (kg):",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
                    textAlign: TextAlign.left,
                  ),
                  SizedBox(height: 8),

                  TextField(
                    controller: _loadController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "Load in kg",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (value) {
                      setState(() {
                        double load = double.tryParse(value) ?? 0;
                        segmentScores["forceLoad"] = (load == 0) ? 0 : (load <= 5) ? 0 : (load <= 10) ? 1 : 2;
                        segmentScores["weight"] = load.toInt();
                      });
                    },
                  ),
                  SizedBox(height: 15),

                  Text(
                    "Is there a shock or rapid build-up of force?",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
                    textAlign: TextAlign.start,
                  ),
                  CheckboxListTile(
                    title: Text("Yes (+1)", style: TextStyle(fontFamily: 'Poppins'),),
                    value: segmentScores["shockAdded"] == 1,
                    activeColor: Color.fromRGBO(55, 149, 112, 1),
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          segmentScores["shockAdded"] = 1;
                        } else {
                          segmentScores["shockAdded"] = 0;
                        }
                  
                      });
                    },
                  ),
                  SizedBox(height: 20),

                  Center(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color.fromRGBO(55, 149, 112, 1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      ),
                      onPressed: (){
                        if (_loadController.text.isEmpty || double.tryParse(_loadController.text) == null) {
                          // Show alert if input is empty or invalid
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Text("Input Required"),
                                content: Text("Please enter a valid Force/Load (kg) before proceeding."),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop(); // Close dialog
                                    },
                                    child: Text("OK"),
                                  ),
                                ],
                              );
                            },
                          );
                        } else {
                          _nextSegment();
                        }
                      },
                      child: Text(
                        'Next',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white, fontFamily: 'Poppins'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ]
        else if (currentSegment.toLowerCase() == "arm supported") ...[
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Grey Background Box with Centered Image
                  Container(
                    height: 250,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Color.fromRGBO(244, 246, 245, 1), // Light grey background
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Image.asset(
                        'assets/arm_support.png', // Update path if needed
                        height: 50,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  SizedBox(height: 10),

                  // Centered Text Below the Image
                  Text(
                    "Arm Support Analysis",
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 15),

                  // Question
                  Text(
                    "Is the arm supported or is the person leaning?",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
                    textAlign: TextAlign.left,
                  ),
                  SizedBox(height: 10),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Radio(
                        value: -1, 
                        groupValue: segmentScores["armSupport"] ?? 0,
                        onChanged: (int? value) {
                          setState(() {
                            segmentScores["armSupport"] = value ?? 0;
                          });
                        },
                      ),
                      Text("Yes", style: TextStyle(fontFamily: 'Poppins')),
                      SizedBox(width: 20),
                      Radio(
                        value: 0, 
                        groupValue: segmentScores["armSupport"] ?? 0,
                        onChanged: (int? value) {
                          setState(() {
                            segmentScores["armSupport"] = value ?? 0;
                          });
                        },
                      ),
                      Text("No", style: TextStyle(fontFamily: 'Poppins')),
                    ],
                  ),
                  SizedBox(height: 20),

                  // Next and Back Buttons
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color.fromRGBO(55, 149, 112, 1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    ),
                    onPressed: _nextSegment,
                    child: Text(
                      'Next',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white, fontFamily: 'Poppins'),
                    ),
                  ),
                  SizedBox(height: 10),  
                ],
              ),
            ),
          ),
        ]
        else if (currentSegment.toLowerCase() == "coupling score") ...[
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Grey Background Box with Centered Image
                  Container(
                    height: 250,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Image.asset(
                        'assets/arm_support.png', // Update with actual path
                        height: 50,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  SizedBox(height: 10),

                  // Title
                  Text(
                    "Coupling Score Analysis",
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 15),

                  // Explanation Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                        Text(
                          "Coupling Score Description:",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
                        ),
                        SizedBox(height: 5),

                        // ✅ Using RichText for bold formatting
                        RichText(
                          text: TextSpan(
                            style: TextStyle(fontSize: 12, fontFamily: 'Poppins', color: Colors.black),
                            children: [
                              TextSpan(text: "• ", style: TextStyle(fontWeight: FontWeight.w600)),
                              TextSpan(text: "0 (Good): ", style: TextStyle(fontWeight: FontWeight.bold)),
                              TextSpan(text: "Well-fitting handle, mid-range power grip."),
                            ],
                          ),
                        ),
                        RichText(
                          text: TextSpan(
                            style: TextStyle(fontSize: 12, fontFamily: 'Poppins', color: Colors.black),
                            children: [
                              TextSpan(text: "• ", style: TextStyle(fontWeight: FontWeight.w600)),
                              TextSpan(text: "1 (Fair): ", style: TextStyle(fontWeight: FontWeight.bold)),
                              TextSpan(text: "Acceptable but not ideal handhold or coupling."),
                            ],
                          ),
                        ),
                        RichText(
                          text: TextSpan(
                            style: TextStyle(fontSize: 12, fontFamily: 'Poppins', color: Colors.black),
                            children: [
                              TextSpan(text: "• ", style: TextStyle(fontWeight: FontWeight.w600)),
                              TextSpan(text: "2 (Poor): ", style: TextStyle(fontWeight: FontWeight.bold)),
                              TextSpan(text: "Handhold not acceptable but possible."),
                            ],
                          ),
                        ),
                        RichText(
                          text: TextSpan(
                            style: TextStyle(fontSize: 12, fontFamily: 'Poppins', color: Colors.black),
                            children: [
                              TextSpan(text: "• ", style: TextStyle(fontWeight: FontWeight.w600)),
                              TextSpan(text: "3 (Unacceptable): ", style: TextStyle(fontWeight: FontWeight.bold)),
                              TextSpan(text: "No handles, awkward, unsafe with any body part."),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 15),

                  // Dropdown Selection
                  Text("Select Coupling Quality:",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
                  DropdownButton<int>(
                    value: segmentScores["coupling"] ?? 0,
                    items: [
                      DropdownMenuItem(value: 0, child: Text("Good - Well-fitting handle")),
                      DropdownMenuItem(value: 1, child: Text("Fair - Acceptable handhold")),
                      DropdownMenuItem(value: 2, child: Text("Poor - Handhold not acceptable")),
                      DropdownMenuItem(value: 3, child: Text("Unacceptable - No handle, unsafe")),
                    ],
                    onChanged: (value) {
                      setState(() {
                        segmentScores["coupling"] = value!;
                        
                      });
                    },
                  ),
                  SizedBox(height: 20),

                  // Buttons
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color.fromRGBO(55, 149, 112, 1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    ),
                    onPressed: _nextSegment,
                    child: Text(
                      'Next',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white, fontFamily: 'Poppins'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ]
       else if (currentSegment.toLowerCase() == "activity score") ...[
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Grey Background Box with Centered Image
                Container(
                  height: 250,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Color.fromRGBO(244, 246, 245, 1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/activity_score.png',
                      height: 100,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                SizedBox(height: 10),

                // Centered Text Below the Image
                Text(
                  "Activity Score",
                  style: TextStyle(
                    fontSize: 16,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 15),

                // Condition 1
                Text(
                  "1 or more body parts are held for longer than 1 minute (static)",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
                ),
                CheckboxListTile(
                  title: Text("Yes (+1)", style: TextStyle(fontFamily: 'Poppins')),
                  value: segmentScores["staticPosture"] == 1,
                  activeColor: Color.fromRGBO(55, 149, 112, 1),
                  onChanged: (bool? value) {
                    setState(() {
                      segmentScores["staticPosture"] = value! ? 1 : 0;
                    });
                  },
                ),
                SizedBox(height: 10),

                // Condition 2
                Text(
                  "Repeated small range actions (more than 4x per minute)",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
                ),
                CheckboxListTile(
                  title: Text("Yes (+1)", style: TextStyle(fontFamily: 'Poppins')),
                  activeColor: Color.fromRGBO(55, 149, 112, 1),
                  value: segmentScores["repeatedAction"] == 1,
                  onChanged: (bool? value) {
                    setState(() {
                      segmentScores["repeatedAction"] = value! ? 1 : 0;
                    });
                  },
                ),
                SizedBox(height: 10),

                // Condition 3
                Text(
                  "Action causes rapid large range changes in postures or unstable base",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
                ),
                CheckboxListTile(
                  title: Text("Yes (+1)", style: TextStyle(fontFamily: 'Poppins')),
                  activeColor: Color.fromRGBO(55, 149, 112, 1),
                  value: segmentScores["unstableBase"] == 1,
                  onChanged: (bool? value) {
                    setState(() {
                      segmentScores["unstableBase"] = value! ? 1 : 0;
                    });
                  },
                ),
                SizedBox(height: 20),

                // Confirm & Review Button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color.fromRGBO(55, 149, 112, 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                  onPressed: () {
                    // Navigate without calculating activityScore
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RebaReportScreen(
                          bodyPartScores: segmentScores,
                          capturedImages: _capturedImages,
                          keypoints: _keypointsMap,
                          side: _selectedSide
                        ),
                      ),
                    );
                  },
                  child: Text("Confirm & Review Assessment",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontFamily: 'Poppins')),
                ),
              ],
            ),
          ),
        ),
      ]


        else if (currentSegment.toLowerCase() == "wrist" && _showSelectionUI) ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                child: Text(
                  "Tap on the middle fingertip to set its position for evaluation.",
                  style: TextStyle(fontSize: 12, fontFamily: 'Poppins'),
                ),
              ),

              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    GestureDetector(
                      onTapDown: (TapDownDetails details) {
                        final RenderBox box = context.findRenderObject() as RenderBox;
                        final Offset localPosition = box.globalToLocal(details.localPosition);

                        // Ensure tap is within bounds
                        double adjustedX = localPosition.dx.clamp(0, 256);
                        double adjustedY = localPosition.dy.clamp(0, 256);

                        setState(() {
                          _selectedPoint = Offset(adjustedX, adjustedY);
                        });
                      },
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 256,
                            height: 256,
                            color: Colors.transparent, // Tap detection area
                            child: Image.file(
                              _capturedImages[currentSegment]!,
                              width: 256,
                              height: 256,
                              fit: BoxFit.cover, // Ensure it fills exactly
                            ),
                          ),
                          if (_selectedPoint != null)
                            Positioned(
                              left: _selectedPoint!.dx - 2.5,
                              top: _selectedPoint!.dy - 2.5,
                              child: Icon(Icons.circle, color: Colors.red, size: 5),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 20),

              Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            Text(
              "Is the wrist bent from midline or twisted?",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10),

            // ✅ Yes/No Selection (Styled Buttons)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      segmentScores["wristBent"] = 1;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: segmentScores["wristBent"] == 1
                        ? Color.fromRGBO(55, 149, 112, 1) // ✅ Green when selected
                        : Colors.white,
                    side: BorderSide(color: Color.fromRGBO(55, 149, 112, 1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: Text(
                    "Yes",
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      color: segmentScores["wristBent"] == 1 ? Colors.white : Color.fromRGBO(55, 149, 112, 1),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      segmentScores["wristBent"] = 0;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: segmentScores["wristBent"] == 0
                        ? Color.fromRGBO(55, 149, 112, 1) // ✅ Green when selected
                        : Colors.white,
                    side: BorderSide(color: Color.fromRGBO(55, 149, 112, 1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: Text(
                    "No",
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      color: segmentScores["wristBent"] == 0 ? Colors.white : Color.fromRGBO(55, 149, 112, 1),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),

      SizedBox(height: 20),

      // ✅ Confirm Selection Button (Centered & Small)
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Align(
          alignment: Alignment.center,
          child: ElevatedButton(
            onPressed: () async {
              if (_selectedPoint == null) {
                // ✅ Show alert if no point is selected
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text("Selection Required"),
                      content: Text("Please tap on the image to mark the wrist position before confirming."),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text("OK"),
                        ),
                      ],
                    );
                  },
                );
                return;
              }

              if (_capturedImages["Wrist"] != null) {
                // Normalize tapped keypoint
                double normalizedX = _selectedPoint!.dx / 256;
                double normalizedY = _selectedPoint!.dy / 256;
                Keypoint wristKeypoint = Keypoint(normalizedX, normalizedY, 1.0);

                List<Keypoint> manualKeypoints = [wristKeypoint];
                await _predict(_capturedImages["Wrist"]!, "Wrist", manualKeypoints);

                setState(() {
                  _showSelectionUI = false; // Hide selection UI after confirming
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color.fromRGBO(55, 149, 112, 1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), // ✅ Smaller radius
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10), // ✅ Smaller button
              minimumSize: Size(120, 32), // ✅ Fixed small size
            ),
            child: Text(
              "Confirm Selection",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white, fontFamily: 'Poppins'),
            ),
          ),
        ),
      ),
    ],
  ),
]
        else if(currentSegment.toLowerCase() == "neck")...[
           Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                child: Text(
                  "Take a photo or import an existing image to evaluate posture.",
                  style: TextStyle(fontSize: 12, fontFamily: 'Poppins'),
                ),
              ),

              SizedBox(height: 10),

              // Image Display Area (with VectorPainter & Angle Measurements)
              Container(
                margin: EdgeInsets.symmetric(horizontal: 16),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Segment: $currentSegment",
                      style: TextStyle(fontSize: 16, fontFamily: 'Poppins', fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 10),

                    _capturedImages[currentSegment] != null
                        ? Column(
                            children: [
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  Image.file(
                                    _capturedImages[currentSegment]!,
                                    width: 256,
                                    height: 256,
                                    fit: BoxFit.cover,
                                  ),
                                  if (_keypointsMap[currentSegment] != null)
                                    CustomPaint(
                                      size: Size(256, 256),
                                      painter: VectorPainter(
                                        _keypointsMap[currentSegment]!,
                                        currentSegment,
                                        0,  // No padding needed
                                        0,
                                        _selectedSide,
                                      ),
                                    ),
                                ],
                              ),
                              SizedBox(height: 8), // Space between image and text

                              // ✅ Small Angle Measurements Below the Image
                              if (_anglesMap[currentSegment] != null)
                                Column(
                                  children: _anglesMap[currentSegment]!.entries.map((entry) {
                                    List<double> values = entry.value;
                                    String formattedText = values.length == 2
                                        ? "${entry.key}: L ${values[0].toStringAsFixed(2)}° | R ${values[1].toStringAsFixed(2)}°"
                                        : values.length == 1
                                            ? "${entry.key}: ${values[0].toStringAsFixed(2)}°"
                                            : "${entry.key}: No data available";

                                    return Text(
                                      formattedText,
                                      style: TextStyle(
                                        fontSize: 10, // ✅ Small text
                                        fontFamily: 'Poppins',
                                        color: Colors.black87,
                                      ),
                                      textAlign: TextAlign.center,
                                    );
                                  }).toList(),
                                ),
                            ],
                          )
                        : Container(
                            width: 256,
                            height: 256,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.green, width: 2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                "No image captured for $currentSegment",
                                style: TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'Poppins'),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                  ],
                ),
              ),

              SizedBox(height: 10),

              // ✅ Centered Question Box
             // Checkbox Section with Left & Right Padding
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0), // ✅ Adds balanced left & right padding
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween, // ✅ Left & Right Alignment
                      children: [
                        Text("Is the neck twisted?", style: TextStyle(fontSize: 14)),
                        Checkbox(
                          value: segmentScores["neckTwisted"] == 1,
                          onChanged: (bool? value) {
                            setState(() {
                              segmentScores["neckTwisted"] = value! ? 1 : 0;
                            });
                          },
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween, // ✅ Left & Right Alignment
                      children: [
                        Text("Is the neck bended?", style: TextStyle(fontSize: 14)),
                        Checkbox(
                          value: segmentScores["neckBended"] == 1,
                          onChanged: (bool? value) {
                            setState(() {
                              segmentScores["neckBended"] = value! ? 1 : 0;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20),

              // ✅ Image Upload Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        side: BorderSide(color: Color.fromRGBO(55, 149, 112, 1)),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: _isModelReady ? () => _pickImage(ImageSource.gallery) : null,
                      child: Text(
                        'Gallery',
                        style: TextStyle(color: Color.fromRGBO(55, 149, 112, 1), fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        side: BorderSide(color: Color.fromRGBO(55, 149, 112, 1)),
                      ),
                      onPressed: _isModelReady ? () => _pickImage(ImageSource.camera) : null,
                      child: Text(
                        'Scan',
                        style: TextStyle(color: Color.fromRGBO(55, 149, 112, 1), fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 10),

              // ✅ Navigation Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    SizedBox(height: 10),
                    Align(
                      alignment: Alignment.center,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color.fromRGBO(55, 149, 112, 1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        onPressed: _capturedImages[currentSegment] != null ? _nextSegment : null,
                        child: Text(
                          _currentStep == _bodySegments.length - 1 ? "Confirm & View Report" : "Next",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white, fontFamily: 'Poppins'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ]
        else if(currentSegment.toLowerCase() == "trunk")...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                child: Text(
                  "Take a photo or import an existing image to evaluate posture.",
                  style: TextStyle(fontSize: 12, fontFamily: 'Poppins'),
                ),
              ),

              SizedBox(height: 10),

              // Image Display Area (with VectorPainter & Angle Measurements)
              Container(
                margin: EdgeInsets.symmetric(horizontal: 16),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Segment: $currentSegment",
                      style: TextStyle(fontSize: 16, fontFamily: 'Poppins', fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 10),

                    _capturedImages[currentSegment] != null
                        ? Column(
                            children: [
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  Image.file(
                                    _capturedImages[currentSegment]!,
                                    width: 256,
                                    height: 256,
                                    fit: BoxFit.cover,
                                  ),
                                  if (_keypointsMap[currentSegment] != null)
                                    CustomPaint(
                                      size: Size(256, 256),
                                      painter: VectorPainter(
                                        _keypointsMap[currentSegment]!,
                                        currentSegment,
                                        0,  // No padding needed
                                        0,
                                        _selectedSide,
                                      ),
                                    ),
                                ],
                              ),
                              SizedBox(height: 8), // Space between image and text

                              // ✅ Small Angle Measurements Below the Image
                              if (_anglesMap[currentSegment] != null)
                                Column(
                                  children: _anglesMap[currentSegment]!.entries.map((entry) {
                                    List<double> values = entry.value;
                                    String formattedText = values.length == 2
                                        ? "${entry.key}: L ${values[0].toStringAsFixed(2)}° | R ${values[1].toStringAsFixed(2)}°"
                                        : values.length == 1
                                            ? "${entry.key}: ${values[0].toStringAsFixed(2)}°"
                                            : "${entry.key}: No data available";

                                    return Text(
                                      formattedText,
                                      style: TextStyle(
                                        fontSize: 10, // ✅ Small text
                                        fontFamily: 'Poppins',
                                        color: Colors.black87,
                                      ),
                                      textAlign: TextAlign.center,
                                    );
                                  }).toList(),
                                ),
                            ],
                          )
                        : Container(
                            width: 256,
                            height: 256,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.green, width: 2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                "No image captured for $currentSegment",
                                style: TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'Poppins'),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                  ],
                ),
              ),

              SizedBox(height: 10),

              // ✅ Centered Question Box
             // Checkbox Section with Left & Right Padding
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0), // ✅ Adds balanced left & right padding
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween, // ✅ Left & Right Alignment
                      children: [
                        Text("Is the trunk twisted?", style: TextStyle(fontSize: 14)),
                        Checkbox(
                          value: segmentScores["trunkTwisted"] == 1,
                          onChanged: (bool? value) {
                            setState(() {
                              segmentScores["trunkTwisted"] = value! ? 1 : 0;
                            });
                          },
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween, // ✅ Left & Right Alignment
                      children: [
                        Text("Is the trunk bended?", style: TextStyle(fontSize: 14)),
                        Checkbox(
                          value: segmentScores["trunkBended"] == 1,
                          onChanged: (bool? value) {
                            setState(() {
                              segmentScores["trunkBended"] = value! ? 1 : 0;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20),

              // ✅ Image Upload Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        side: BorderSide(color: Color.fromRGBO(55, 149, 112, 1)),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: _isModelReady ? () => _pickImage(ImageSource.gallery) : null,
                      child: Text(
                        'Gallery',
                        style: TextStyle(color: Color.fromRGBO(55, 149, 112, 1), fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        side: BorderSide(color: Color.fromRGBO(55, 149, 112, 1)),
                      ),
                      onPressed: _isModelReady ? () => _pickImage(ImageSource.camera) : null,
                      child: Text(
                        'Scan',
                        style: TextStyle(color: Color.fromRGBO(55, 149, 112, 1), fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 10),

              // ✅ Navigation Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    SizedBox(height: 10),
                    Align(
                      alignment: Alignment.center,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color.fromRGBO(55, 149, 112, 1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        onPressed: _capturedImages[currentSegment] != null ? _nextSegment : null,
                        child: Text(
                          _currentStep == _bodySegments.length - 1 ? "Confirm & View Report" : "Next",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white, fontFamily: 'Poppins'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ]
        else if(currentSegment.toLowerCase() == "upper arm")...[
             Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                child: Text(
                  "Take a photo or import an existing image to evaluate posture.",
                  style: TextStyle(fontSize: 12, fontFamily: 'Poppins'),
                ),
              ),

              SizedBox(height: 10),

              // Image Display Area (with VectorPainter & Angle Measurements)
              Container(
                margin: EdgeInsets.symmetric(horizontal: 16),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Segment: $currentSegment",
                      style: TextStyle(fontSize: 16, fontFamily: 'Poppins', fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 10),

                    _capturedImages[currentSegment] != null
                        ? Column(
                            children: [
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  Image.file(
                                    _capturedImages[currentSegment]!,
                                    width: 256,
                                    height: 256,
                                    fit: BoxFit.cover,
                                  ),
                                  if (_keypointsMap[currentSegment] != null)
                                    CustomPaint(
                                      size: Size(256, 256),
                                      painter: VectorPainter(
                                        _keypointsMap[currentSegment]!,
                                        currentSegment,
                                        0,  // No padding needed
                                        0,
                                        _selectedSide,
                                      ),
                                    ),
                                ],
                              ),
                              SizedBox(height: 8), // Space between image and text

                              // ✅ Small Angle Measurements Below the Image
                              if (_anglesMap[currentSegment] != null)
                                Column(
                                  children: _anglesMap[currentSegment]!.entries.map((entry) {
                                    List<double> values = entry.value;
                                    String formattedText = values.length == 2
                                        ? "${entry.key}: L ${values[0].toStringAsFixed(2)}° | R ${values[1].toStringAsFixed(2)}°"
                                        : values.length == 1
                                            ? "${entry.key}: ${values[0].toStringAsFixed(2)}°"
                                            : "${entry.key}: No data available";

                                    return Text(
                                      formattedText,
                                      style: TextStyle(
                                        fontSize: 10, // ✅ Small text
                                        fontFamily: 'Poppins',
                                        color: Colors.black87,
                                      ),
                                      textAlign: TextAlign.center,
                                    );
                                  }).toList(),
                                ),
                            ],
                          )
                        : Container(
                            width: 256,
                            height: 256,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.green, width: 2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                "No image captured for $currentSegment",
                                style: TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'Poppins'),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                  ],
                ),
              ),

              SizedBox(height: 10),

              // ✅ Centered Question Box
             // Checkbox Section with Left & Right Padding
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0), // ✅ Adds balanced left & right padding
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween, // ✅ Left & Right Alignment
                      children: [
                        Text("Is the shoulder raised", style: TextStyle(fontSize: 14)),
                        Checkbox(
                          value: segmentScores['shoulderRaised'] == 1,
                          onChanged: (bool? value) {
                            setState(() {
                              segmentScores['shoulderRaised'] = value! ? 1 : 0;
                            });
                          },
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween, // ✅ Left & Right Alignment
                      children: [
                        Text("Is the upper arm abducted?", style: TextStyle(fontSize: 14)),
                        Checkbox(
                          value: segmentScores['upperArmAbducted'] == 1,
                          onChanged: (bool? value) {
                            setState(() {
                              segmentScores['upperArmAbducted'] = value! ? 1 : 0;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20),

              // ✅ Image Upload Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        side: BorderSide(color: Color.fromRGBO(55, 149, 112, 1)),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: _isModelReady ? () => _pickImage(ImageSource.gallery) : null,
                      child: Text(
                        'Gallery',
                        style: TextStyle(color: Color.fromRGBO(55, 149, 112, 1), fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        side: BorderSide(color: Color.fromRGBO(55, 149, 112, 1)),
                      ),
                      onPressed: _isModelReady ? () => _pickImage(ImageSource.camera) : null,
                      child: Text(
                        'Scan',
                        style: TextStyle(color: Color.fromRGBO(55, 149, 112, 1), fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 10),

              // ✅ Navigation Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    SizedBox(height: 10),
                    Align(
                      alignment: Alignment.center,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color.fromRGBO(55, 149, 112, 1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        onPressed: _capturedImages[currentSegment] != null ? _nextSegment : null,
                        child: Text(
                          _currentStep == _bodySegments.length - 1 ? "Confirm & View Report" : "Next",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white, fontFamily: 'Poppins'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ]
        else if (currentSegment.toLowerCase() == "legs & posture") ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                child: Text(
                  "Take a photo or import an existing image to evaluate posture.",
                  style: TextStyle(fontSize: 12, fontFamily: 'Poppins'),
                ),
              ),

              SizedBox(height: 10),

              // Image Display Area (with VectorPainter & Angle Measurements)
              Container(
                margin: EdgeInsets.symmetric(horizontal: 16),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Segment: $currentSegment",
                      style: TextStyle(fontSize: 16, fontFamily: 'Poppins', fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 10),

                    _capturedImages[currentSegment] != null
                        ? Column(
                            children: [
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  Image.file(
                                    _capturedImages[currentSegment]!,
                                    width: 256,
                                    height: 256,
                                    fit: BoxFit.cover,
                                  ),
                                  if (_keypointsMap[currentSegment] != null)
                                    CustomPaint(
                                      size: Size(256, 256),
                                      painter: VectorPainter(
                                        _keypointsMap[currentSegment]!,
                                        currentSegment,
                                        0,  // No padding needed
                                        0,
                                        _selectedSide,
                                      ),
                                    ),
                                ],
                              ),
                              SizedBox(height: 8), // Space between image and text

                              // ✅ Small Angle Measurements Below the Image
                              if (_anglesMap[currentSegment] != null)
                                Column(
                                  children: _anglesMap[currentSegment]!.entries.map((entry) {
                                    List<double> values = entry.value;
                                    String formattedText = values.length == 2
                                        ? "${entry.key}: L ${values[0].toStringAsFixed(2)}° | R ${values[1].toStringAsFixed(2)}°"
                                        : values.length == 1
                                            ? "${entry.key}: ${values[0].toStringAsFixed(2)}°"
                                            : "${entry.key}: No data available";

                                    return Text(
                                      formattedText,
                                      style: TextStyle(
                                        fontSize: 10, // ✅ Small text
                                        fontFamily: 'Poppins',
                                        color: Colors.black87,
                                      ),
                                      textAlign: TextAlign.center,
                                    );
                                  }).toList(),
                                ),
                            ],
                          )
                        : Container(
                            width: 256,
                            height: 256,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.green, width: 2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                "No image captured for $currentSegment",
                                style: TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'Poppins'),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                  ],
                ),
              ),

              SizedBox(height: 20),

              // ✅ Centered Question Box
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    Text(
                      "Is one leg raised?",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
                      textAlign: TextAlign.center, // ✅ Center the text
                    ),
                    SizedBox(height: 10),
                    Center(
                      child: DropdownButton<int>(
                        value: segmentScores["legRaised"] ?? 1, // ✅ Default to 1 (No)
                        items: [
                          DropdownMenuItem(
                            value: 2,
                            child: Text(
                              "Yes - One leg raised",
                              style: TextStyle(fontSize: 14, fontFamily: 'Poppins'),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 1,
                            child: Text(
                              "No - Both feet on the ground",
                              style: TextStyle(fontSize: 14, fontFamily: 'Poppins'),
                            ),
                          ),
                        ],
                        onChanged: (int? value) {
                          setState(() {
                            segmentScores["legRaised"] = value ?? 1; // ✅ Update score (1 for No, 2 for Yes)
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20),

              // ✅ Image Upload Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        side: BorderSide(color: Color.fromRGBO(55, 149, 112, 1)),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: _isModelReady ? () => _pickImage(ImageSource.gallery) : null,
                      child: Text(
                        'Gallery',
                        style: TextStyle(color: Color.fromRGBO(55, 149, 112, 1), fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        side: BorderSide(color: Color.fromRGBO(55, 149, 112, 1)),
                      ),
                      onPressed: _isModelReady ? () => _pickImage(ImageSource.camera) : null,
                      child: Text(
                        'Scan',
                        style: TextStyle(color: Color.fromRGBO(55, 149, 112, 1), fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 10),

              // ✅ Navigation Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    SizedBox(height: 10),
                    Align(
                      alignment: Alignment.center,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color.fromRGBO(55, 149, 112, 1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        onPressed: _capturedImages[currentSegment] != null ? _nextSegment : null,
                        child: Text(
                          _currentStep == _bodySegments.length - 1 ? "Confirm & View Report" : "Next",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white, fontFamily: 'Poppins'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ]
        else ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [ 
                    Text(
                      "Take a photo or import an existing image to evaluate posture.",
                      style: TextStyle(fontSize: 12, fontFamily: 'Poppins'),
                    ),
                  ],
                ),
              ),

            SizedBox(height: 10),

            // Image Display Area
           Container(
              margin: EdgeInsets.symmetric(horizontal: 16),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Segment: $currentSegment",
                    style: TextStyle(fontSize: 16, fontFamily: 'Poppins', fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 10),

                  _capturedImages[currentSegment] != null
                      ? Column(
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                Image.file(
                                  _capturedImages[currentSegment]!,
                                  width: 256,
                                  height: 256,
                                  fit: BoxFit.cover,
                                ),
                                if (_keypointsMap[currentSegment] != null)
                                  CustomPaint(
                                    size: Size(256, 256),
                                    painter: VectorPainter(
                                      _keypointsMap[currentSegment]!,
                                      currentSegment,
                                      0, // No padding needed
                                      0,
                                      _selectedSide,
                                    ),
                                  ),
                              ],
                            ),
                            SizedBox(height: 8), // Space between image and text

                            // ✅ Small Angle Measurements Below the Image (Inside the Same Container)
                            if (_anglesMap[currentSegment] != null)
                              Column(
                                children: _anglesMap[currentSegment]!.entries.map((entry) {
                                  List<double> values = entry.value;
                                  String formattedText = values.length == 2
                                      ? "${entry.key}: L ${values[0].toStringAsFixed(2)}° | R ${values[1].toStringAsFixed(2)}°"
                                      : values.length == 1
                                          ? "${entry.key}: ${values[0].toStringAsFixed(2)}°"
                                          : "${entry.key}: No data available";

                                  return Text(
                                    formattedText,
                                    style: TextStyle(
                                      fontSize: 10, // ✅ Small text
                                      fontFamily: 'Poppins',
                                      color: Colors.black87,
                                    ),
                                    textAlign: TextAlign.center,
                                  );
                                }).toList(),
                              ),
                          ],
                        )
                      : Container(
                          width: 256,
                          height: 256,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.green, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              "No image captured for $currentSegment",
                              style: TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'Poppins'),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                ],
              ),
            ),

            SizedBox(height: 20),
    
              // Button Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        side: BorderSide(color: Color.fromRGBO(55, 149, 112, 1)),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: _isModelReady ? () => _pickImage(ImageSource.gallery) : null,
                      child: Text('Gallery', style: TextStyle(color: Color.fromRGBO(55, 149, 112, 1), fontFamily: 'Poppins', fontSize:12, fontWeight: FontWeight.w600)),
                    ),
                    SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        side: BorderSide(color: Color.fromRGBO(55, 149, 112, 1)),
                      ),
                      onPressed: _isModelReady ? () => _pickImage(ImageSource.camera) : null,
                      child: Text('Scan', style: TextStyle(color: Color.fromRGBO(55, 149, 112, 1), fontFamily: 'Poppins', fontSize:12, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20),

              // Navigation Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    SizedBox(height: 10),
                    Align(
                      alignment: Alignment.center,
                      child : 
                          ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color.fromRGBO(55, 149, 112, 1),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          onPressed: _capturedImages[currentSegment] != null ? _nextSegment : null,
                          child: Text(
                            _currentStep == _bodySegments.length - 1 ? "Confirm & View Report" : "Next",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white, fontFamily: 'Poppins'),
                          ),
                        ),
                      )
                  
                  ],
                ),
              ),
    ],
  ),
  ],
  ],
    ),
    ),
    );
    }
  }