import 'package:flutter/material.dart';
import 'package:merula/main.dart';
import 'input.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:image/image.dart' as image_lib;
import 'package:intl/intl.dart';
import 'create.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';


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
  final Map<String, File?> capturedImages; // Images linked to segments

  RebaReportScreen({required this.bodyPartScores, required this.capturedImages});

  @override
  _RebaReportScreenState createState() => _RebaReportScreenState();
}

class _RebaReportScreenState extends State<RebaReportScreen> {
  TextEditingController _descriptionController = TextEditingController();
  TextEditingController _titleController = TextEditingController();
  late String timestamp;
  late int overallScore;

  final Map<String, String> bodyPartToSegment = {
    "neckScore": "Neck",
    "trunkScore": "Trunk",
    "legScore": "Legs & Posture",
    "forceLoad": "Force Load Score",
    "upperArmScore": "Upper Arm",
    "lowerArmScore": "Lower Arm",
    "armSupported": "Arm Supported",
    "wristScore": "Wrist",
    "coupling": "Coupling Score",
    "activityScore": "Activity Score",
  };

  @override
  void initState() {
    super.initState();
    timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()); // Get current time
    overallScore = calculateOverallScore(widget.bodyPartScores); // Compute REBA final score
  }

  int calculateOverallScore(Map<String, int> scores) {
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
    return rebaScore;

  }

  void _submitAssessment() async {
    try {
    String userId = FirebaseAuth.instance.currentUser?.uid ?? "anonymous";
    print('userId: $userId');
    // ✅ Auto-generate assessmentId (Firestore document ID)
    String assessmentId = FirebaseFirestore.instance.collection('reba_assessments').doc().id;

    String description = _descriptionController.text.trim();
    String title = _titleController.text.trim();

    List<Map<String, dynamic>> images = [];

    

    for (var entry in widget.capturedImages.entries) {
      String segmentKey = entry.key;
      File? imageFile = entry.value;

      if (imageFile != null) {
        String? imageUrl = await uploadImageToSupabase(imageFile, userId, assessmentId, segmentKey);
        if (imageUrl != null) {
          images.add({"segment": segmentKey, "url": imageUrl});
        }
      }
    }



    Map<String, dynamic> assessmentData = {
      'userId' : userId,
      'assessmentId': assessmentId,  // Store the ID for future reference
      // 'userId': userId,
      'timestamp': timestamp,
      'title': title.isNotEmpty ? title : "Untitled Assessment",
      'description': description.isNotEmpty ? description : "No description provided",
      'overallScore': overallScore,
      'bodyScores': widget.bodyPartScores,
      'images': images,  // Store image URLs here
    };

 

    print(assessmentData);

      FirebaseAuth.instance.authStateChanges().listen((User? user) {
  if (user == null) {
    print("User is signed out");
  } else {
    print("User is signed in: ${user.uid}");
  }
});

          await FirebaseFirestore.instance.collection('reba_assessments')
  .doc(assessmentId)
  .set(assessmentData)
  .then((_) => print("✅ Successfully submitted REBA assessment"))
  .catchError((error) => print("❌ Firestore Write Error: $error"));

   print("✅ Submitted REBA Assessment: $assessmentData");
   Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()), 
      );
  } catch (e) {
    print("❌ Error submitting assessment: $e");
  }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('REBA Report')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("REBA Assessment Summary", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

              SizedBox(height: 10),
              Text("Timestamp: $timestamp", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),

              SizedBox(height: 10),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: "Enter Title",
                  border:OutlineInputBorder(),
                ),
                // maxLines: 3,
              ),

              SizedBox(height:10),
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: "Enter Title",
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),

              SizedBox(height: 20),
              Text("Overall Score: $overallScore", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),

              SizedBox(height: 10),
              Text("Body Scores:", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),

              ...widget.bodyPartScores.entries.map((entry) {
                String bodyPart = entry.key;
                int score = entry.value;
                String? relatedSegment = bodyPartToSegment[bodyPart];
                File? imageFile = relatedSegment != null ? widget.capturedImages[relatedSegment] : null;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 15),
                    Text("$bodyPart:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    if (imageFile != null && imageFile.existsSync())
                      Image.file(imageFile, height: 150, fit: BoxFit.cover)
                    else
                      Text("Image not found", style: TextStyle(color: Colors.red)),
                    Text("Score: $score"),
                  ],
                );
              }).toList(),

              SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: _submitAssessment,
                  child: Text("Submit Assessment"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}