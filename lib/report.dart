import 'package:flutter/material.dart';
import 'package:merula/main.dart';
import 'input.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'create.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'handclassifier.dart';

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
  Map<String, List<Handkeypoint>> handkeypoints = {};
   // Images linked to segments

  RebaReportScreen({required this.bodyPartScores, required this.capturedImages, required this.keypoints, required this.handkeypoints});

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
    // print(scores['neckScore']);
    int rebaScoreA = getRebaScoreA(scores['neckScore'] ?? 0, scores['legScore'] ?? 0, scores['trunkScore'] ?? 0) + (scores['forceLoad'] ?? 0);
    print('rebascoreA : $rebaScoreA');
    int rebaScoreB = getRebaScoreB(scores['lowerArmScore'] ?? 0, scores['upperArmScore'] ?? 0, scores['wristScore'] ?? 0) + (scores['coupling'] ?? 0);
    print('rebascoreB : $rebaScoreB');
    int rebaScoreC = getRebaScoreC(rebaScoreA, rebaScoreB);
    print('Fetching rebaTableC[rebaScoreA][rebaScoreB]: ${rebaTableC[rebaScoreA]?[rebaScoreB]}');
    print('rebascoreC : $rebaScoreC');
    int rebaScore = rebaScoreC + (scores['activityScore'] ?? 0);
    print('total reba : $rebaScore');
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
    timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()); // Get current time
    // overallScore = calculateOverallScore(widget.bodyPartScores); // Compute REBA final score
    Map<String, int> rebaScores = calculateOverallScore(widget.bodyPartScores);
    
    rebaScoreA = rebaScores['rebaScoreA']!;
    rebaScoreB = rebaScores['rebaScoreB']!;
    rebaScoreC = rebaScores['rebaScoreC']!;
    overallScore = rebaScores['totalReba']!;
    
  }

 void _submitAssessment() async {
  try {
    String userId = FirebaseAuth.instance.currentUser?.uid ?? "anonymous";
    print('userId: $userId');

    // ✅ Auto-generate assessmentId (Firestore document ID)
    String assessmentId =
        FirebaseFirestore.instance.collection('reba_assessments').doc().id;

    String description = _descriptionController.text.trim();
    String title = _titleController.text.trim();

    List<Map<String, dynamic>> images = [];

    // ✅ Ensure timestamp & overallScore are initialized
    timestamp = DateTime.now().toIso8601String();
    overallScore = overallScore ?? 0;

    for (var entry in widget.capturedImages.entries) {
      String segmentKey = entry.key;
      File? imageFile = entry.value;

      if (imageFile != null) {
        try {
          String? imageUrl =
              await uploadImageToSupabase(imageFile, userId, assessmentId, segmentKey);
          if (imageUrl != null) {
            // ✅ Get keypoints for this image
            List<Map<String, double>> keypoints = widget.keypoints[segmentKey]
                    ?.map((kp) => {"x": kp.x, "y": kp.y})
                    .toList() ??
                [];

                Map<String, dynamic> imageData = {
                  "segment": segmentKey,
                  "url": imageUrl,
                  "keypoints": keypoints,
                };

                if (segmentKey == "Wrist") {
              List<Map<String, double>> handkeypoints = widget.handkeypoints[segmentKey]
                      ?.map((hkp) => {"x": hkp.x, "y": hkp.y})
                      .toList() ??
                  [];
                if (handkeypoints.isNotEmpty) {
                                imageData["handkeypoints"] = handkeypoints;
                              }
                            }

                            images.add(imageData);
                          }
                          
        } catch (e) {
          print("❌ Error uploading image for segment $segmentKey: $e");
        }
      }
    }
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
      'rebaScoreA' : rebaScoreA,
      'rebaScoreB' : rebaScoreB,
      'rebaScoreC' : rebaScoreC,
    };

    print("🚀 Submitting Assessment: $assessmentData");

    await FirebaseFirestore.instance
        .collection('reba_assessments')
        .doc(assessmentId)
        .set(assessmentData)
        .then((_) => print("✅ Successfully submitted REBA assessment"))
        .catchError((error) => print("❌ Firestore Write Error: $error"));


    _descriptionController.clear();
    _titleController.clear();
    print("✅ Submitted REBA Assessment: $assessmentData");
    

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => HomeScreen()),
    );
  } catch (e, stackTrace) {
    print("❌ Error submitting assessment: $e");
    print(stackTrace); // Logs full error trace for debugging
  }
}

  final Map<String, String> displayBodyPartNames = {
  "neckScore": "Neck Position",
  "trunkScore": "Trunk Position",
  "legScore": "Legs & Posture Position",
  "forceLoad": "Force Load Score",
  "shockAdded" : "Shock Added",
  "upperArmScore" : "Upper Arm Position",
  "lowerArmScore" : "Lower Arm Position",
  "wristScore" : "Wrist",
  "coupling": "Coupling Score",
  "activityScore": "Activity Score",
};
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Asessment Confirmation', style:TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 18))),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
             SizedBox(height: 8),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                labelText: "Enter Title",
                labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),

              SizedBox(height:10),
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: "Enter Description",
                   labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                maxLines: 3,
              ),
          SizedBox(height: 20),
          Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  "REBA Results Analysis",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
                ),
              ),
            ),
             SizedBox(height: 20),

          ...widget.bodyPartScores.entries.map((entry) {
            String bodyPartKey = entry.key;
            int score = entry.value;
            if (bodyPartKey == "staticPosture" || bodyPartKey == "repeatedAction" || bodyPartKey == "armSupport") return SizedBox();

            // Get display name, fallback to original key if not found
            String bodyPart = displayBodyPartNames[bodyPartKey] ?? bodyPartKey;
            String? relatedSegment = bodyPartToSegment[bodyPartKey];
            File? imageFile = relatedSegment != null ? widget.capturedImages[relatedSegment] : null;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left Section (Image or Body Part Name)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bodyPart, // Always show body part name
                        style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins',
                      ),
                      ),
                      SizedBox(height: 6),
                      if (imageFile != null && imageFile.existsSync())
                        ClipRRect(
                          // borderRadius: BorderRadius.circular(10),
                          child: Image.file(imageFile, width: 100, height: 80, fit: BoxFit.cover),
                        ),
                    ],
                  ),

                  SizedBox(width: 16), // Add space between image/text and score box
                  Spacer(), // Push score box to the right

                  // Score Box (Right Side)
                  Column(
                    children: [
                      Container(
                        width: 60,
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Color.fromRGBO(235, 237, 240, 1),
                          // borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            "$score",
                            style: TextStyle(fontSize: 14, fontFamily:'Poppins', fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      SizedBox(height: 4), // Space between box and "Score" text
                      Text(
                        "Score",
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Poppins',
                          ),
                      ),
                    ],
                  ),
                  SizedBox(width: 10), // Slight gap on the right side
                ],
              ),
            );
          }).toList(),

// Overall REBA Score (Centered)
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
                // padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
                  onPressed: _submitAssessment,
                  child: Text("Submit Assessment", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white, fontFamily: 'Poppins')),
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