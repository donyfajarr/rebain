import 'package:flutter/material.dart';
import 'package:merula/main.dart';
import 'input.dart';
import 'dart:io';
import 'create.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:typed_data';
import 'package:image/image.dart' as img;



// Table A: Neck Scores
Map<int, Map<int, Map<int, int>>> rebaTableA = {
  1: {
    1: {1: 1, 2: 2, 3: 2, 4: 3, 5: 4},
    2: {1: 2, 2: 3, 3: 4, 4: 5, 5: 6},
    3: {1: 3, 2: 4, 3: 5, 4: 6, 5: 7},
    4: {1: 4, 2: 5, 3: 6, 4: 7, 5: 8},
  },
  2: {
    1: {1: 1, 2: 3, 3: 4, 4: 5, 5: 6},
    2: {1: 2, 2: 4, 3: 5, 4: 6, 5: 7},
    3: {1: 3, 2: 5, 3: 6, 4: 7, 5: 8},
    4: {1: 4, 2: 6, 3: 7, 4: 8, 5: 9},
  },
  3: {
    1: {1: 3, 2: 4, 3: 5, 4: 6, 5: 7},
    2: {1: 3, 2: 5, 3: 6, 4: 7, 5: 8},
    3: {1: 5, 2: 6, 3: 7, 4: 8, 5: 9},
    4: {1: 6, 2: 7, 3: 8, 4: 9, 5: 9},
  },
};

// Table B: Upper Arm Score Lookup
Map<int, Map<int, Map<int, int>>> rebaTableB = {
  1: {
    1: {1: 1, 2: 2, 3: 2},
    2: {1: 1, 2: 2, 3: 3},
    3: {1: 3, 2: 4, 3: 5},
    4: {1: 4, 2: 5, 3: 5},
    5: {1: 6, 2: 7, 3: 8},
    6: {1: 7, 2: 8, 3: 8},
  },
  2: {
    1: {1: 1, 2: 2, 3: 3},
    2: {1: 2, 2: 3, 3: 4},
    3: {1: 4, 2: 5, 3: 5},
    4: {1: 5, 2: 6, 3: 7},
    5: {1: 7, 2: 8, 3: 8},
    6: {1: 8, 2: 9, 3: 9},
  },
};

// Table C: Final Score Lookup
Map<int, Map<int, int>> rebaTableC = {
  1: {1: 1, 2: 1, 3: 1, 4: 2, 5: 3, 6: 3, 7: 4, 8: 5, 9: 6, 10: 7, 11: 7, 12: 7},
  2: {1: 1, 2: 2, 3: 2, 4: 3, 5: 4, 6: 4, 7: 5, 8: 6, 9: 6, 10: 7, 11: 7, 12: 7},
  3: {1: 2, 2: 3, 3: 3, 4: 3, 5: 4, 6: 5, 7: 6, 8: 7, 9: 7, 10: 8, 11: 8, 12: 8},
  4: {1: 3, 2: 4, 3: 4, 4: 4, 5: 5, 6: 6, 7: 7, 8: 8, 9: 8, 10: 9, 11: 9, 12: 9},
  5: {1: 4, 2: 4, 3: 4, 4: 5, 5: 6, 6: 7, 7: 8, 8: 8, 9: 9, 10: 9, 11: 9, 12: 9},
  6: {1: 6, 2: 6, 3: 6, 4: 7, 5: 8, 6: 8, 7: 9, 8: 9, 9: 10, 10: 10, 11: 10, 12: 10},
  7: {1: 7, 2: 7, 3: 7, 4: 8, 5: 9, 6: 9, 7: 9, 8: 10, 9: 10, 10: 11, 11: 11, 12: 11},
  8: {1: 8, 2: 8, 3: 8, 4: 9, 5: 10, 6: 10, 7: 10, 8: 10, 9: 10, 10: 11, 11: 11, 12: 11},
  9: {1: 9, 2: 9, 3: 9, 4: 10, 5: 10, 6: 10, 7: 11, 8: 11, 9: 11, 10: 12, 11: 12, 12: 12},
  10: {1: 10, 2: 10, 3: 10, 4: 11, 5: 11, 6: 11, 7: 11, 8: 12, 9: 12, 10: 12, 11: 12, 12: 12},
  11: {1: 11, 2: 11, 3: 11, 4: 11, 5: 12, 6: 12, 7: 12, 8: 12, 9: 12, 10: 12, 11: 12, 12: 12},
  12: {1: 12, 2: 12, 3: 12, 4: 12, 5: 12, 6: 12, 7: 12, 8: 12, 9: 12, 10: 12, 11: 12, 12: 12},
};

int getRebaScoreA(int neckScore, int legScore, int trunkScore) {
  return rebaTableA[neckScore]?[legScore]?[trunkScore] ?? 0;
}

int getRebaScoreB(int upperArmScore, int lowerArmScore, int wristScore) {
  return rebaTableB[upperArmScore]?[lowerArmScore]?[wristScore] ?? 0;
}

// Function to retrieve final REBA Score from Table C
int getRebaScoreC(int scoreA, int scoreB) {
  return rebaTableC[scoreA]?[scoreB] ?? 0;
}

class RebaReportScreen extends StatefulWidget {
  final Map<String, int> bodyPartScores;
  final Map<String, File?> capturedImages;
  Map<String, List<Keypoint>> keypoints = {};
  Map<String, String> segmentSide;
  
  RebaReportScreen({required this.bodyPartScores, required this.capturedImages, required this.keypoints, required this.segmentSide});

  @override
  _RebaReportScreenState createState() => _RebaReportScreenState();
}

class _RebaReportScreenState extends State<RebaReportScreen> {
  TextEditingController _descriptionController = TextEditingController();
  TextEditingController _titleController = TextEditingController();
  late String timestamp;
  late int overallScore;
  late int rebaScoreA;
  late int rebaScoreB;
  late int rebaScoreC;
  // String? side;
  

  final Map<String, String> bodyPartToSegment = {
    "neckScore": "Neck",
    "trunkScore": "Trunk",
    "legScore": "Legs & Posture",
    "forceLoad": "Force Load Score",
    "upperArmScore": "Upper Arm",
    "lowerArmScore": "Lower Arm",
    "armSupport": "Arm Supported",
    "wristScore": "Wrist",
    "coupling": "Coupling Score",
    "activityScore": "Activity Score",
  };

  Map<String, int> calculateOverallScore(Map<String, int> scores) {
    // Neck Calculation
    if (scores['neckTwisted'] == 1 || scores['neckBended'] == 1) {
      scores['neckScore'] = (scores['neckScore'] ?? 0) + 1;
    }

    // Trunk Calculation
    if (scores['trunkTwisted'] == 1){
      scores['trunkScore'] = (scores['trunkScore'] ?? 0) + 1;
    };

    if (scores['trunkBended'] == 1){
      scores['trunkScore'] = (scores['trunkScore'] ?? 0) + 1;
    }

    // Legs & Posture Calculation

    if (scores['legRaised'] == 1){
      scores['legScore'] = (scores['legScore'] ?? 0) + 1;
    }
    if (scores['legRaised'] == 2){
      scores['legScore'] = (scores['legScore'] ?? 0) + 2;
    }

    // Upper Arm Calculation
    if (scores['shoulderRaised'] ==1 ){
      scores['upperArmScore'] = (scores['upperArmScore'] ?? 0) + 1;
    }

    if (scores['upperArmAbducted'] == 1){
      scores['upperArmScore'] = (scores['upperArmScore'] ?? 0) + 1;
    }

    if (scores['armSupport'] == -1){
      scores['upperArmScore'] = (scores['upperArmScore'] ?? 0) -1;
    }

    // Wrist Calculation
    if (scores['wristBent'] == 1){
      scores['wristScore'] = (scores['wristScore'] ?? 0) + 1;
    }

    // Force Load Calculation
    if (scores['shockAdded'] == 1){
      scores['forceLoad'] = (scores['forceLoad'] ?? 0) + 1;
    }

    if (scores['unstableBase'] == 1){
      scores['activityScore'] = (scores['activityScore'] ?? 0) +1; 
    }
    if (scores['staticPosture'] == 1){
      scores['activityScore'] = (scores['activityScore'] ?? 0) +1; 
    }
    if (scores['repeatedAction'] == 1){
      scores['activityScore'] = (scores['activityScore'] ?? 0) +1; 
    }

    print(scores);
    int rebaScoreA = getRebaScoreA(scores['neckScore'] ?? 0, scores['legScore'] ?? 0, scores['trunkScore'] ?? 0) + (scores['forceLoad'] ?? 0);
    print('rebascoreA : $rebaScoreA');
    int rebaScoreB = getRebaScoreB(scores['lowerArmScore'] ?? 0, scores['upperArmScore'] ?? 0, scores['wristScore'] ?? 0) + (scores['coupling'] ?? 0);
    print('rebascoreB : $rebaScoreB');
    int rebaScoreC = getRebaScoreC(rebaScoreA, rebaScoreB);
    print('Fetching rebaTableC[rebaScoreA][rebaScoreB]: ${rebaTableC[rebaScoreA]?[rebaScoreB]}');
    print('rebascoreC : $rebaScoreC');
    int rebaScore = rebaScoreC + (scores['activityScore'] ?? 0);
    print('total reba : $rebaScore');
    // print(widget.side);
    return {
    'rebaScoreA': rebaScoreA,
    'rebaScoreB': rebaScoreB,
    'rebaScoreC': rebaScoreC,
    'totalReba': rebaScore,
  };

  }
  @override
  void initState() {
    super.initState();
    // timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    Map<String, int> rebaScores = calculateOverallScore(widget.bodyPartScores);
    
    rebaScoreA = rebaScores['rebaScoreA']!;
    rebaScoreB = rebaScores['rebaScoreB']!;
    rebaScoreC = rebaScores['rebaScoreC']!;
    overallScore = rebaScores['totalReba']!;
    
  }


Future<File> resizeAndCompressImage(File file) async {
  Uint8List imageBytes = await file.readAsBytes();
  img.Image? decodedImage = img.decodeImage(imageBytes);

  if (decodedImage == null) return file; // Return original if decoding fails

  // 🔥 Resize to 256x256 (Maintaining Aspect Ratio)
  img.Image resizedImage = img.copyResize(decodedImage, width: 256, height: 256);

  // 🔥 Compress to JPEG with 70% quality
  Uint8List compressedBytes = Uint8List.fromList(img.encodeJpg(resizedImage, quality: 70));

  File compressedFile = File('${file.path}_resized.jpg');
  await compressedFile.writeAsBytes(compressedBytes);
  return compressedFile;
}
void _submitAssessment() async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => Center(child: CircularProgressIndicator()),
  );

  try {
    String userId = FirebaseAuth.instance.currentUser?.uid ?? "anonymous";
    String assessmentId = FirebaseFirestore.instance.collection('reba_assessments').doc().id;
    String description = _descriptionController.text.trim();
    String title = _titleController.text.trim();
    
    timestamp = DateTime.now().toIso8601String();
    overallScore = overallScore ?? 0;

    List<Future<Map<String, dynamic>?>> uploadTasks = [];

    for (var entry in widget.capturedImages.entries) {
      String segmentKey = entry.key;
      File? imageFile = entry.value;

      if (imageFile != null) {
        uploadTasks.add(() async {
          try {
            print('Compressing image for segment: $segmentKey');
            File compressedImage = await resizeAndCompressImage(imageFile);  // 🔥 Compress the image first

            print('Uploading compressed image for segment: $segmentKey');
            String? imageUrl = await uploadImageToSupabase(compressedImage, userId, assessmentId, segmentKey);
            if (imageUrl != null) {
              
              List<Map<String, double>> keypoints = widget.keypoints[segmentKey]
                      ?.map((kp) => {"x": kp.x, "y": kp.y})
                      .toList() ?? [];
              String side = segmentSide[segmentKey] ?? 'Unknown'; // Default to 'Unknown' if no side is set
              return {
                "segment": segmentKey,
                "url": imageUrl,
                "keypoints": keypoints,
                "side" : side,
              };
            }
          } catch (e) {
            print("❌ Error uploading image for segment $segmentKey: $e");
          }
          return null;
        }());
      }
    }

    List<Map<String, dynamic>> images = (await Future.wait(uploadTasks))
        .where((img) => img != null)
        .cast<Map<String, dynamic>>()
        .toList();

    Timestamp firestoreTimestamp = Timestamp.fromDate(DateTime.now());
    
    Map<String, dynamic> assessmentData = {
      'userId': userId,
      'assessmentId': assessmentId,
      'timestamp': firestoreTimestamp,
      'title': title.isNotEmpty ? title : "Untitled Assessment",
      'description': description.isNotEmpty ? description : "No description provided",
      'overallScore': overallScore,
      'bodyScores': widget.bodyPartScores,
      'images': images,
      'rebaScoreA': rebaScoreA,
      'rebaScoreB': rebaScoreB,
      'rebaScoreC': rebaScoreC,
    
    };

    print("🚀 Submitting Assessment: $assessmentData");

    WriteBatch batch = FirebaseFirestore.instance.batch();
    DocumentReference docRef = FirebaseFirestore.instance.collection('reba_assessments').doc(assessmentId);
    batch.set(docRef, assessmentData);
    await batch.commit();

    print("✅ Successfully submitted REBA assessment");

    _descriptionController.clear();
    _titleController.clear();

    Navigator.pop(context); // Close loading indicator
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => HomeScreen()),
    );
  } catch (e, stackTrace) {
    Navigator.pop(context); // Ensure loading dialog is dismissed
    print("❌ Error submitting assessment: $e");
    print(stackTrace);
  }
}


  final Map<String, String> displayBodyPartNames = {
  "neckScore": "Neck Position",
  "trunkScore": "Trunk Position",
  "legScore": "Legs & Posture Position",
  "forceLoad": "Force Load Score",
  "upperArmScore" : "Upper Arm Position",
  "lowerArmScore" : "Lower Arm Position",
  "wristScore" : "Wrist",
  "coupling": "Coupling Score",
  "activityScore": "Activity Score",
};
  
  // Explanations for additional breakdown (only applies to related segment)
// Define child-to-parent mappings
final Map<String, String> childToParent = {
  "neckTwisted": "neckScore",
  "neckBended": "neckScore",
  "trunkTwisted": "trunkScore",
  "trunkBended": "trunkScore",
  "legRaised": "legScore",
  "shoulderRaised": "upperArmScore",
  "upperArmAbducted": "upperArmScore",
  "armSupport": "upperArmScore",
  "wristBent": "wristScore",
  "shockAdded" : "forceLoad",
  "unstableBase" : "activityScore",
  "staticPosture" : "activityScore",
  "repeatedAction" : "activityScore",
};

final Map<String, String> scoreDescriptions = {
  "neckTwisted": "+1 Neck Twisted",
  "neckBended": "+1 Neck Bended",
  "trunkTwisted": "+1 Trunk Twisted",
  "trunkBended": "+1 Trunk Bended",
  "legRaised": "+1 Leg Raised",
  "shoulderRaised": "+1 Shoulder Raised",
  "upperArmAbducted": "+1 Upper Arm Abducted",
  "armSupport": "-1 Arm Support",
  "wristBent": "+1 Wrist Bent",
  "shockAdded" : "+1 Shock Added",
  "unstableBase" : "+1 Unstable Base",
  "staticPosture" : "+1 Static Posture",
  "repeatedAction" : "+1 Repeated Action",

};


@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text('Assessment Confirmation', 
        style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 18)),
    ),
    body: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title & Description Box (Restored)
            Text("Posture Assessment", 
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
            SizedBox(height: 6),
            Text("Review the assessment details before submitting.", 
              style: TextStyle(fontSize: 14, fontFamily: 'Poppins', color: Colors.grey[600])),
            SizedBox(height: 20),

            TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: "Enter Title",
                  labelStyle: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700], 
                  ),
                  filled: true,
                  fillColor: Colors.white, // Keep background white
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!, width: 1), // Soft grey border
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.blueAccent, width: 2), // Highlight when focused
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),

              SizedBox(height:10),
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: "Enter Description",
                  labelStyle: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.blueAccent, width: 2),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                maxLines: 3,
              ),
            
             SizedBox(height:20),

            // List of Body Parts
            ...widget.bodyPartScores.entries.map((entry) {
              String bodyPartKey = entry.key;
              int score = entry.value;

              // Skip if not in displayBodyPartNames
              if (!displayBodyPartNames.containsKey(bodyPartKey)) return SizedBox();

              // Get body part name
              String bodyPart = displayBodyPartNames[bodyPartKey]!;
              String? relatedSegment = bodyPartToSegment[bodyPartKey];
              File? imageFile = relatedSegment != null ? widget.capturedImages[relatedSegment] : null;

              // Collect descriptions only for this segment
              List<String> additionalDescriptions = [];
              widget.bodyPartScores.forEach((key, value) {
                if (childToParent[key] == bodyPartKey && value != 0) {
                  additionalDescriptions.add(scoreDescriptions[key]!);
                }
              });

              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Left Section (Image + Body Part Name + Additional Info)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Main Body Part Name
                        Text(
                          bodyPart, 
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'Poppins'),
                        ),
                        SizedBox(height: 4),

                        // Image (if exists)
                        if (imageFile != null && imageFile.existsSync())
                          ClipRRect(
                            child: Image.file(imageFile, width: 100, height: 80, fit: BoxFit.cover),
                          ),
                        
                        // Additional Information (small text, only for this segment)
                        if (additionalDescriptions.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: additionalDescriptions.map((desc) => 
                                Text(
                                  "• $desc", 
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600], fontFamily: 'Poppins'),
                                ),
                              ).toList(),
                            ),
                          ),
                      ],
                    ),

                    SizedBox(width: 16), 
                    Spacer(), 

                    // Score Box (Right Side)
                    Column(
                      children: [
                        Container(
                          width: 60,
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Color.fromRGBO(235, 237, 240, 1),
                          ),
                          child: Center(
                            child: Text(
                              "$score",
                              style: TextStyle(fontSize: 14, fontFamily:'Poppins', fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        SizedBox(height: 4), 
                        Text(
                          "Score",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, fontFamily: 'Poppins'),
                        ),
                      ],
                    ),
                    SizedBox(width: 10),
                  ],
                ),
              );
            }).where((widget) => widget is! SizedBox).toList(),

            SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: Color.fromRGBO(235, 237, 240, 1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "$overallScore",
                      style: TextStyle(fontFamily: 'Poppins',fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "REBA Score",
                    style: TextStyle(fontFamily: 'Poppins',fontSize: 16),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color.fromRGBO(55, 149, 112, 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: _submitAssessment,
                child: Text(
                  "Submit Assessment", 
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white, fontFamily: 'Poppins'),
                ),
              ),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    ),
  );
}
}