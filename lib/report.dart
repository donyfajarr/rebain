import 'package:flutter/material.dart';
import 'input.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:image/image.dart' as image_lib;

// Table A: Neck Scores
Map<int, Map<int, Map<int, int>>> rebaTableA = {
  1: {
    1: {1: 1, 2: 2, 3: 3, 4: 4, 5: 5},
    2: {1: 2, 2: 3, 3: 4, 4: 5, 5: 6},
    3: {1: 3, 2: 4, 3: 5, 4: 6, 5: 7},
    4: {1: 4, 2: 5, 3: 6, 4: 7, 5: 8},
  },
  2: {
    1: {1: 2, 2: 3, 3: 4, 4: 5, 5: 6},
    2: {1: 3, 2: 4, 3: 5, 4: 6, 5: 7},
    3: {1: 4, 2: 5, 3: 6, 4: 7, 5: 8},
    4: {1: 5, 2: 6, 3: 7, 4: 8, 5: 9},
  },
  3: {
    1: {1: 3, 2: 4, 3: 5, 4: 6, 5: 7},
    2: {1: 4, 2: 5, 3: 6, 4: 7, 5: 8},
    3: {1: 5, 2: 6, 3: 7, 4: 8, 5: 9},
    4: {1: 6, 2: 7, 3: 8, 4: 9, 5: 9},
  },
};

// Table B: Upper Arm Score Lookup
Map<int, Map<int, Map<int, int>>> rebaTableB = {
  1: {
    1: {1: 1, 2: 2, 3: 3},
    2: {1: 2, 2: 3, 3: 4},
    3: {1: 3, 2: 4, 3: 5},
    4: {1: 4, 2: 5, 3: 6},
    5: {1: 5, 2: 6, 3: 7},
    6: {1: 6, 2: 7, 3: 8},
  },
};

// Table C: Final Score Lookup
Map<int, Map<int, int>> rebaTableC = {
  1: {1: 1, 2: 2, 3: 3, 4: 4, 5: 5, 6: 6, 7: 7, 8: 7, 9: 8, 10: 9, 11: 10, 12: 12},
  2: {1: 2, 2: 3, 3: 4, 4: 5, 5: 6, 6: 7, 7: 8, 8: 8, 9: 9, 10: 10, 11: 11, 12: 12},
  3: {1: 3, 2: 4, 3: 5, 4: 6, 5: 7, 6: 8, 7: 9, 8: 9, 9: 10, 10: 11, 11: 12, 12: 12},
  4: {1: 4, 2: 5, 3: 6, 4: 7, 5: 8, 6: 9, 7: 10, 8: 10, 9: 11, 10: 12, 11: 12, 12: 12},
  5: {1: 5, 2: 6, 3: 7, 4: 8, 5: 9, 6: 10, 7: 11, 8: 11, 9: 12, 10: 12, 11: 12, 12: 12},
  6: {1: 6, 2: 7, 3: 8, 4: 9, 5: 10, 6: 11, 7: 12, 8: 12, 9: 12, 10: 12, 11: 12, 12: 12},
  7: {1: 7, 2: 8, 3: 9, 4: 10, 5: 11, 6: 12, 7: 12, 8: 12, 9: 12, 10: 12, 11: 12, 12: 12},
  8: {1: 7, 2: 8, 3: 9, 4: 10, 5: 11, 6: 12, 7: 12, 8: 12, 9: 12, 10: 12, 11: 12, 12: 12},
  9: {1: 8, 2: 9, 3: 10, 4: 11, 5: 12, 6: 12, 7: 12, 8: 12, 9: 12, 10: 12, 11: 12, 12: 12},
  10: {1: 9, 2: 10, 3: 11, 4: 12, 5: 12, 6: 12, 7: 12, 8: 12, 9: 12, 10: 12, 11: 12, 12: 12},
  11: {1: 10, 2: 11, 3: 12, 4: 12, 5: 12, 6: 12, 7: 12, 8: 12, 9: 12, 10: 12, 11: 12, 12: 12},
  12: {1: 12, 2: 12, 3: 12, 4: 12, 5: 12, 6: 12, 7: 12, 8: 12, 9: 12, 10: 12, 11: 12, 12: 12},
};

int getRebaScoreA(int neckScore, int trunkScore, int legScore) {
  return rebaTableA[neckScore]?[trunkScore]?[legScore] ?? 0;
}

int getRebaScoreB(int upperArmScore, int lowerArmScore, int wristScore) {
  return rebaTableB[upperArmScore]?[lowerArmScore]?[wristScore] ?? 0;
}

// Function to retrieve final REBA Score from Table C
int getRebaScoreC(int scoreA, int scoreB) {
  return rebaTableC[scoreA]?[scoreB] ?? 0;
}


int rebaScoreA = getRebaScoreA(segmentScores['neckScore']!, segmentScores['trunkScore']!, segmentScores['legScore']!);
int rebaScoreB = getRebaScoreB(segmentScores['upperArmScore']!,segmentScores['lowerArmScore']!,segmentScores['wristScore']!);
int finalScore = getRebaScoreC(rebaScoreA, rebaScoreB);


class RebaReportScreen extends StatelessWidget {
  final Map<String, int> bodyPartScores;
  final Map<String, File?> capturedImages; // Images linked to segments

  RebaReportScreen({required this.bodyPartScores, required this.capturedImages});

  final Map<String, String> bodyPartToSegment = {
  "neckScore": "Trunk & Neck",
  "trunkScore": "Trunk & Neck",
  "legScore": "Legs & Posture",
  "forceLoad": "Force Load Score",
  "upperArmScore": "Arm",
  "lowerArmScore": "Arm",
  "armSupported": "Arm Supported",
  "wristScore": "Wrist",
  "couplingScore": "Coupling Score",
  "activityScore": "Activity Score",
};

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

              ...bodyPartScores.entries.map((entry) {
                String bodyPart = entry.key;
                int score = entry.value;

                // Find corresponding segment image
                String? relatedSegment = bodyPartToSegment[bodyPart];
                File? imageFile = relatedSegment != null ? capturedImages[relatedSegment] : null;

                // Debugging prints
                print("Body Part: $bodyPart | Segment: $relatedSegment | Image Found: ${imageFile != null}");

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 15),
                    Text("$bodyPart:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    if (imageFile != null && imageFile.existsSync()) // Ensure file exists
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
                  onPressed: () {
                    _submitAssessment();
                  },
                  child: Text("Submit Assessment"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }




  void _submitAssessment() {
    // Here, you can handle Firebase submission
    print("Submitting REBA assessment: $segmentScores");
  }
}
