import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'input.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
export 'details.dart';



class AssessmentDetailsPage extends StatelessWidget {
  final String assessmentId;
  final Map<String, dynamic> data;

  AssessmentDetailsPage({required this.assessmentId, required this.data});

  Future<void> _deleteImagesFromSupabase(List<dynamic> images) async {
    final supabase = Supabase.instance.client;

    List<String> filePaths = images.map<String>((img) {
      String url = img['url'].toString();
      Uri uri = Uri.parse(url);
      List<String> segments = uri.pathSegments;

      // Extract correct file path in Supabase Storage
      return segments.skip(5).join('/'); // Skipping 'storage', 'v1', 'object'
    }).toList();

    if (filePaths.isNotEmpty) {
      try {
        print('File paths to delete: $filePaths');
        await supabase.storage.from('rebain').remove(filePaths);
        print("✅ Successfully deleted images from Supabase");
      } catch (e) {
        print("❌ Supabase delete error: $e");
      }
    }
  }

  Future<void> _deleteAssessment(BuildContext context) async {
    try {
      // Get images to delete from Supabase before removing Firestore entry
      List<dynamic> images = (data['images'] as List<dynamic>?) ?? [];
      await _deleteImagesFromSupabase(images);
      await FirebaseFirestore.instance.collection('reba_assessments').doc(assessmentId).delete();

      print("✅ Deleted assessment successfully");
      // Navigate back after deletion
      Navigator.pop(context);
    } catch (e) {
      print("❌ Error deleting assessment: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to delete assessment")),
      );
    }
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text("Confirm Delete"),
          content: Text("Are you sure you want to delete this assessment? This action cannot be undone."),
          actions: [
            TextButton(
              child: Text("Cancel"),
              onPressed: () => Navigator.pop(dialogContext),
            ),
            TextButton(
              child: Text("Delete", style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.pop(dialogContext);
                _deleteAssessment(context);
              },
            ),
          ],
        );
      },
    );
  }

  Future<Uint8List> downloadImage(String imageUrl) async {
    final response = await http.get(Uri.parse(imageUrl));
    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception("Failed to load image");
    }
  }

  Future<void> generatePdf(Map<String, dynamic> data) async {
  final pdf = pw.Document();
  print('test data : $data');
  DateTime timestampDate = (data['timestamp'] as Timestamp).toDate();
  String formattedDate = "${timestampDate.day}-${timestampDate.month}-${timestampDate.year}-${timestampDate.hour}-${timestampDate.minute}";
  
  int overallScore = (data['overallScore'] as num?)?.toInt() ?? 0;
  String risk = _getRiskCategory(overallScore);
  String title = data['title']?.toString() ?? 'No Title';
  final bodyScores = data['bodyScores'] as Map<String, dynamic>;

  final List<Map<String, dynamic>> images = (data['images'] as List<dynamic>).map((image) {
    return {
      'segment': image['segment'].toString(),
      'url': image['url']?.toString() ?? '',
      'keypoints': image['keypoints'] ?? [],
    };
  }).toList();

  // ✅ **Preload async widgets**
  final neckTrunkLegTable = await _buildImageScoreTable(images, bodyScores, {
    "Neck": "neckScore",
    "Trunk": "trunkScore",
    "Legs & Posture": "legScore"
  });

  final armWristTable = await _buildImageScoreTable(images, bodyScores, {
    "Upper Arm": "upperArmScore",
    "Lower Arm": "lowerArmScore",
    "Wrist": "wristScore"
  });

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) => [
        pw.Padding(
          padding: pw.EdgeInsets.all(20),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("REBA Analysis Report", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text("Title: ${data['title']}", style: pw.TextStyle(fontSize: 14)),
              pw.Text("Description: ${data['description']}", style: pw.TextStyle(fontSize: 14)),
              pw.Text("Date: $formattedDate", style: pw.TextStyle(fontSize: 14)),
              pw.SizedBox(height: 10),
              pw.Text("Overall REBA Score: $overallScore", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Text("Risk Level: $risk", style: pw.TextStyle(fontSize: 14, color: PdfColors.red)),
              pw.SizedBox(height: 15),
              
              _buildSection("Neck, Trunk, and Leg Analysis"),
              neckTrunkLegTable, // ✅ **Use preloaded table here**
              // _buildScoreRow("Force Load Score", (bodyScores["forceLoad"] as num?)?.toInt()),
              _buildForceLoadScoreDetails(bodyScores),
              _buildCenteredScore("REBA Score A", (data['rebaScoreA'] as num?)?.toInt()),

              _buildSection("Arm & Wrist Analysis"),
              armWristTable, // ✅ **Use preloaded table here**
              _buildScoreRow("Coupling Score", (bodyScores["coupling"] as num?)?.toInt()),

              _buildCenteredScore("REBA Score B", (data['rebaScoreB'] as num?)?.toInt()),

              _buildSection("Activity Score"),
              // _buildScoreRow("Activity Score", (bodyScores["activityScore"] as num?)?.toInt()),
              _buildActivityScoreDetails(bodyScores), // ✅ **Use preloaded table here**)
              _buildCenteredScore("REBA Score C", (data['rebaScoreC'] as num?)?.toInt()),

              _buildCenteredScore("Total REBA Score", overallScore, emphasized: true),
              
              pw.SizedBox(height: 20),
              pw.Text("End of Report", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ),
      ],
    ),
  );

  final output = await getExternalStorageDirectory();
  final file = File("${output!.path}/REBA_Report_${data['title']}.pdf");
  await file.writeAsBytes(await pdf.save());
  await Share.shareXFiles([XFile(file.path)], text: "Download your REBA Report");
}

pw.Widget _buildSection(String title) {
  return pw.Padding(
    padding: pw.EdgeInsets.symmetric(vertical: 10),
    child: pw.Text(
      title,
      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue),
    ),
  );
}

pw.Widget _buildForceLoadScoreDetails(Map<String, dynamic> bodyScores) {
  List<pw.TableRow> rows = []; // Change List<pw.Widget> to List<pw.TableRow>

  // Iterate over all force/load-related factors and add them if they have a score of 1
  for (var entry in childToParent.entries) {
    if (entry.value == "forceLoad" && (bodyScores[entry.key] as num?) == 1) {
      rows.add(
        pw.TableRow(
          children: [
            pw.Padding(
              padding: pw.EdgeInsets.all(8),
              child: pw.Text(scoreDescriptions[entry.key] ?? entry.key),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.all(8),
              child: pw.Text("1"),
            ),
          ],
        ),
      );
    }
  }

  // If no force/load-related scores were recorded, show a placeholder
  if (rows.isEmpty) {
    rows.add(
      pw.TableRow(
        children: [
          pw.Padding(
            padding: pw.EdgeInsets.all(8),
            child: pw.Text(
              "No additional force/load factors",
              style: pw.TextStyle(color: PdfColors.grey),
            ),
          ),
          pw.Padding(
            padding: pw.EdgeInsets.all(8),
            child: pw.Text("0"),
          ),
        ],
      ),
    );
  }

  return pw.Table(
    border: pw.TableBorder.all(),
    children: [
      // Table Header
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColors.grey200),
        children: [
          pw.Padding(
            padding: pw.EdgeInsets.all(8),
            child: pw.Text("Force Load", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ),
          pw.Padding(
            padding: pw.EdgeInsets.all(8),
            child: pw.Text("Score", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ),
        ],
      ),
      // Force/load-related rows
      ...rows, // ✅ Now this works because `rows` is List<pw.TableRow>
      // Total Force/Load Score Row
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColors.lightBlue),
        children: [
          pw.Padding(
            padding: pw.EdgeInsets.all(8),
            child: pw.Text("Total Force/Load Score", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ),
          pw.Padding(
            padding: pw.EdgeInsets.all(8),
            child: pw.Text((bodyScores["forceLoad"] as num?)?.toInt()?.toString() ?? "0",
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ),
        ],
      ),
    ],
  );
}


pw.Widget _buildActivityScoreDetails(Map<String, dynamic> bodyScores) {
  List<pw.TableRow> rows = [];

  // Iterate over all activity-related factors and add them if they have a score of 1
  for (var entry in childToParent.entries) {
    if (entry.value == "activityScore" && (bodyScores[entry.key] as num?) == 1) {
      rows.add(
         pw.TableRow(
          children: [
            pw.Padding(
                padding: pw.EdgeInsets.all(8),
                child: pw.Text(scoreDescriptions[entry.key] ?? entry.key)),
            pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text("1")),
          ],
        ),
      );
    }
  }

  // If no activity-related scores were recorded, show a placeholder
  if (rows.isEmpty) {
    rows.add(
      pw.TableRow(
        children: [
          pw.Padding(
            padding: pw.EdgeInsets.all(8),
            child: pw.Text(
              "No additional activity factors",
              style: pw.TextStyle(color: PdfColors.grey),
            ),
          ),
          pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text("0")),
        ],
)
    );
  }

  return pw.Table(
    border: pw.TableBorder.all(),
    children: [
      // Table Header
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColors.grey200),
        children: [
          pw.Padding(
            padding: pw.EdgeInsets.all(8),
            child: pw.Text("Factor", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ),
          pw.Padding(
            padding: pw.EdgeInsets.all(8),
            child: pw.Text("Score", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ),
        ],
      ),
      // Activity-related rows
      ...rows,
      // Total Activity Score Row
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColors.lightBlue),
        children: [
          pw.Padding(
            padding: pw.EdgeInsets.all(8),
            child: pw.Text("Total Activity Score", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ),
          pw.Padding(
            padding: pw.EdgeInsets.all(8),
            child: pw.Text((bodyScores["activityScore"] as num?)?.toInt()?.toString() ?? "0", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ),
        ],
      ),
    ],
  );
}


Future<pw.Widget> _buildImageScoreTable(
  List<Map<String, dynamic>> images,
  Map<String, dynamic> scores,
  Map<String, String> segmentMapping,
) async {
  return pw.Table(
    border: pw.TableBorder.all(), // ✅ Restored table border
    columnWidths: {0: pw.FlexColumnWidth(1), 1: pw.FlexColumnWidth(1)},
    children: [
      // Table Header
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColors.grey200),
        children: [
          pw.Padding(
            padding: pw.EdgeInsets.all(8),
            child: pw.Text("Segment", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ),
          pw.Padding(
            padding: pw.EdgeInsets.all(8),
            child: pw.Text("Score", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ),
        ],
      ),

      // Table Content
      for (var entry in segmentMapping.entries)
        pw.TableRow(
          children: [
            // Left Column: Image + Segment Name + Extra Text
            pw.Padding(
              padding: pw.EdgeInsets.all(8),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(entry.key, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),

                  // Image (unchanged)
                  if (images.any((img) => img['segment'] == entry.key))
                    await _drawKeypointsOnImage(images.firstWhere((img) => img['segment'] == entry.key)),

                  // Additional descriptions below image
                  if (childToParent.containsValue(entry.value)) ...[
                    pw.SizedBox(height: 4),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: childToParent.entries
                          .where((e) => e.value == entry.value && scores[e.key] == 1)
                          .map((e) => pw.Text(
                                scoreDescriptions[e.key] ?? '',
                                style: pw.TextStyle(fontSize: 10, color: PdfColors.black),
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),

            // Right Column: Score
            pw.Padding(
              padding: pw.EdgeInsets.all(8),
              child: pw.Text((scores[entry.value] as num?)?.toInt()?.toString() ?? "-", textAlign: pw.TextAlign.center),
            ),
          ],
        ),
    ],
  );
}

Future<pw.Widget> _drawKeypointsOnImage(Map<String, dynamic> imageData) async {
  Uint8List imageBytes = await downloadImage(imageData['url'].toString());
  List<Map<String, dynamic>> keypoints = 
    (imageData['keypoints'] as List<dynamic>)
        .map((point) => (point as Map<dynamic, dynamic>).map(
              (key, value) => MapEntry(key.toString(), value),
            ))
        .toList();
    return pw.Container(
      width: 100,
      height: 100,
      child: pw.Stack(
        children: [
          pw.Image(pw.MemoryImage(imageBytes), width: 100, height: 100, fit: pw.BoxFit.cover),
          for (var point in keypoints)
            pw.Positioned(
              left: (point['x'] as num).toDouble() * 100,
              top: (point['y'] as num).toDouble() * 100,
              child: pw.SizedBox(
                        width: 4,
                        height: 4,
                        child: pw.Container(
                          decoration: pw.BoxDecoration(
                            color: PdfColors.red,
                            shape: pw.BoxShape.circle,
                          ),
                        ),
                      ),
                              ),
          ],
        ),
      );
  }



pw.Widget _buildScoreRow(String title, int? score) {
  return pw.Table(
    border: pw.TableBorder.all(),
    children: [
      pw.TableRow(
        children: [
          pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text(title)),
          pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text(score != null ? score.toString() : "-")),
        ],
      ),
    ],
  );
}

pw.Widget _buildCenteredScore(String title, int? score, {bool emphasized = false}) {
  return pw.Table(
    border: pw.TableBorder.all(),
    children: [
      pw.TableRow(
        children: [
          pw.Container(
            alignment: pw.Alignment.center,
            padding: pw.EdgeInsets.all(10),
            child: pw.Text(
              "$title: ${score ?? '-'}",
              style: pw.TextStyle(fontSize: emphasized ? 18 : 14, fontWeight: emphasized ? pw.FontWeight.bold : pw.FontWeight.normal),
            ),
          ),
        ],
      ),
    ],
  );
}


String _getRiskCategory(int score) {
  if (score == 1) return 'Negligible Risk';
  if (score >= 2 && score <= 3) return 'Low Risk. Change may be needed';
  if (score >= 4 && score <= 7) return 'Medium Risk. Investigate further.';
  if (score >= 8 && score <= 10) return 'High Risk. Immediate change required.';
  return 'Very High Risk. Urgent Action!';
}

// Helper function to build score rows
final Map<String, String> scoreMapping = {
    "Neck": "neckScore",
    "Trunk": "trunkScore",
    "Legs & Posture": "legScore",
    "Upper Arm": "upperArmScore",
    "Lower Arm": "lowerArmScore",
    "Wrist": "wristScore",
    "Force Load Score": "forceLoad",
    "Arm Supported": "armSupported",
    "Coupling Score": "coupling",
    "Activity Score": "activityScore",
  };

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
    backgroundColor: Colors.white,
    appBar: AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      title: Text(
        "Assessment Report",
        style: TextStyle(fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w600),
      ),
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            SizedBox(height: 30),
            _buildAnalysisSection("Neck, Trunk and Leg Analysis", ["Neck", "Trunk", "Legs & Posture"], data),
            _buildOtherScores(["Force Load Score"], data),
            _buildScoreABox(),
            SizedBox(height: 10),
            _buildAnalysisSection("Arm & Wrist Analysis", ["Upper Arm", "Lower Arm", "Wrist"], data),
            _buildOtherScores(["Coupling Score"], data),
            _buildScoreBBox(),
            _buildOtherScores(["Activity Score"], data),
            _buildScoreCBox(),
            _buildScoreBox(),
            SizedBox(height: 20),

            // 🆕 Download PDF Button
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue, // Blue for download action
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                ),
                onPressed: () => generatePdf(data),
                child: Text("Download PDF", style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ),
            SizedBox(height: 10),

            // ❌ Delete Button (Fixed)
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                ),
                onPressed: () => _confirmDelete(context),
                child: Text("Delete Assessment", style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}


  Widget _buildHeader() {
    Timestamp timestamp = data['timestamp'] as Timestamp;
    DateTime timestampDate = timestamp.toDate();
    String formattedDate = DateFormat('dd-MM-yyyy HH:mm:ss').format(timestampDate);

    int overallScore = (data['overallScore'] ?? 0) as int;
    String risk = 'No risk found';
  
    print(overallScore);
      // Ensure 'overallScore' is a number and check if it's greater than 1
    if (overallScore == 1) {
      risk = 'Negligible Risk';
    }
    else if(overallScore >= 2 && overallScore <= 3){
      risk = 'Low Risk. Change may be needed';
    }
    else if(overallScore >=4 && overallScore<=7){
      risk = 'Medium Risk. Further Investigate. Change Soon.';
    }
    else if (overallScore >=8 && overallScore <=10){
      risk = 'High Risk. Investigate and Implement Change';
    }
    else{
      risk = 'Very High Risk. Implement Change';
    }

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(data['title'].toString(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color:Color.fromRGBO(55, 149, 112, 1))),
          SizedBox(height: 8),
          Row(children: [Icon(Icons.description_rounded, size: 16), SizedBox(width: 6), Text(data['description'].toString(), style:TextStyle(fontFamily: 'Poppins', fontSize: 12))]),
          SizedBox(height: 4),
          Row(children: [Icon(Icons.calendar_today, size: 16), SizedBox(width: 6), Text(formattedDate, style:TextStyle(fontFamily: 'Poppins', fontSize: 12))]),
          SizedBox(height: 4),
          Row(children: [Icon(Icons.bar_chart_rounded, size: 16), SizedBox(width: 6), Text("REBA Score: ${data['overallScore'] ?? '-'}", style:TextStyle(fontFamily: 'Poppins', fontSize: 12))]),
          SizedBox(height: 4),
          Row(children: [Icon(Icons.warning, size: 16), SizedBox(width: 6), Text(risk, style:TextStyle(fontFamily: 'Poppins', fontSize: 12))]),
        ],
      ),
    );
  }

  Widget _buildAnalysisSection(String title, List<String> segments, Map<String, dynamic> data) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Center(
        child: Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            fontFamily: 'Poppins',
          ),
          textAlign: TextAlign.center,
        ),
      ),
      SizedBox(height: 8),

      Column(
        children: segments.map((segment) {
          var imageData = (data['images'] as List<dynamic>?)
              ?.firstWhere((img) => img['segment'] == segment, orElse: () => null);

          List<Keypoint> keypoints = [];
          if (imageData != null &&
              imageData is Map<String, dynamic> &&
              imageData.containsKey('keypoints') &&
              imageData['keypoints'] is List<dynamic>) {
            keypoints = (imageData['keypoints'] as List<dynamic>)
                .map((point) => Keypoint(
                      (point['x'] as num).toDouble(),
                      (point['y'] as num).toDouble(),
                      0.1, // Default confidence value
                    ))
                .toList();
          }

          String scoreKey = scoreMapping[segment] ?? "";
          String score = data['bodyScores']?[scoreKey]?.toString() ?? "-";

          // ✅ Collect additional text based on conditions
          List<String> extraInfo = [];
          childToParent.forEach((key, parent) {
            if (data['bodyScores'][key] == 1 && parent == scoreKey) {
              extraInfo.add(scoreDescriptions[key] ?? '');
            }
          });

          return Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Image and keypoints (stays on the left)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$segment Position',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    SizedBox(height: 4),
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                      ),
                      child: imageData != null && imageData['url'] != null
                          ? Stack(
                              clipBehavior: Clip.none,
                              children: [
                                ClipRRect(
                                  child: Image.network(
                                    imageData['url'].toString(),
                                    fit: BoxFit.cover,
                                    width: 100,
                                    height: 100,
                                  ),
                                ),
                                Positioned.fill(
                                  child: CustomPaint(
                                    size: Size(100, 100),
                                    painter: VectorPainter(
                                      keypoints,
                                      segment,
                                      0,
                                      0,
                                      null,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Icon(Icons.image_not_supported),
                    ),
                    if (extraInfo.isNotEmpty) ...[
                      SizedBox(height: 4),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start, // ✅ Left-align text below image
                        children: extraInfo.map((text) => Text(
                              text,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Poppins',
                                color: Colors.black,
                              ),
                            )).toList(),
                      ),
                    ],
                  ],
                ),

                SizedBox(width: 12),

                // Score box remains on the far right
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Column(
                      children: [
                        Container(
                          width: 60,
                          padding: EdgeInsets.all(12),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Color.fromRGBO(235, 237, 240, 1),
                          ),
                          child: Text(
                            score,
                            style: TextStyle(
                              fontSize: 14,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Score',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Poppins',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),

      SizedBox(height: 10),
    ],
  );
}

  Widget _buildOtherScores(List<String> labels, Map<String, dynamic> data) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: labels.map((label) {
          String scoreKey = scoreMapping[label] ?? "";
          String score = data['bodyScores']?[scoreKey]?.toString() ?? "-";
          List<String> extraInfo = [];
          childToParent.forEach((key, parent) {
            if (data['bodyScores'][key] == 1 && parent == scoreKey) {
              extraInfo.add(scoreDescriptions[key] ?? '');
            }
          });

          return Padding(
            padding: EdgeInsets.symmetric(vertical: 6.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children : [
                  Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                  ),
                ),
                SizedBox(height:4),
                if (extraInfo.isNotEmpty) ...[
                      SizedBox(height: 4),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start, // ✅ Left-align text below image
                        children: extraInfo.map((text) => Text(
                              text,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Poppins',
                                color: Colors.black,
                              ),
                            )).toList(),
                      ),
                    ],
                ],
              ),
              
              SizedBox(width: 12),
              
              Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Column(
                      children: [
                        Container(
                          width: 60,
                          padding: EdgeInsets.all(12),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Color.fromRGBO(235, 237, 240, 1),
                          ),
                          child: Text(
                            score,
                            style: TextStyle(
                              fontSize: 14,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Score',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Poppins',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildScoreABox() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 100,
              height: 60,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Color.fromRGBO(235, 237, 240, 1), 
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                data['rebaScoreA'].toString(),
                style: TextStyle(fontFamily: 'Poppins',fontSize: 20, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          SizedBox(height: 8), // Space between box and text
          Center(
            child: Text(
              'REBA Score A', 
              style: TextStyle(fontFamily: 'Poppins',fontSize: 16),
            ),
          ),
          SizedBox(height: 8), // Space before the line
          Divider(thickness: 2, color: Colors.black54), // Full-width line
        ],
      ),
    );
  }

  Widget _buildScoreBBox() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 100,
              height: 60,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Color.fromRGBO(235, 237, 240, 1), 
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                data['rebaScoreB'].toString(),
                style: TextStyle(fontFamily: 'Poppins',fontSize: 20, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          SizedBox(height: 8), // Space between box and text
          Center(
            child: Text(
              'REBA Score B', 
              style: TextStyle(fontFamily: 'Poppins',fontSize: 16),
            ),
          ),
          SizedBox(height: 8), // Space before the line
          Divider(thickness: 2, color: Colors.black54), // Full-width line
        ],
      ),
    );
  }

  Widget _buildScoreCBox() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 100,
              height: 60,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Color.fromRGBO(235, 237, 240, 1), 
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                data['rebaScoreC'].toString(),
                style: TextStyle(fontFamily: 'Poppins',fontSize: 20, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          SizedBox(height: 8), // Space between box and text
          Center(
            child: Text(
              'REBA Score C', 
              style: TextStyle(fontFamily: 'Poppins',fontSize: 16),
            ),
          ),
          SizedBox(height: 8), // Space before the line
          Divider(thickness: 2, color: Colors.black54), // Full-width line
        ],
      ),
    );
  }

  Widget _buildScoreBox() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 150,
              height: 80,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey[300], 
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                data['overallScore'].toString(),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(height: 8), // Space between box and text
            Text(
              'Total REBA Score', 
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

}