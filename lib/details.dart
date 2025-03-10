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

      // Delete images from Supabase
      await _deleteImagesFromSupabase(images);

      // Delete the assessment from Firestore
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

  Future<void> generatePdf(Map<String, dynamic> data) async {
  final pdf = pw.Document();

  // Convert Timestamp to readable date
  DateTime timestampDate = (data['timestamp'] as Timestamp).toDate();
  String formattedDate = "${timestampDate.day}-${timestampDate.month}-${timestampDate.year} ${timestampDate.hour}:${timestampDate.minute}";

  // Risk Level Calculation
  int overallScore = (data['overallScore'] as num?)?.toInt() ?? 0;
  String risk = _getRiskCategory(overallScore);

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Padding(
          padding: pw.EdgeInsets.all(20),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("REBA Analysis Report",
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text("Title: ${data['title']}", style: pw.TextStyle(fontSize: 14)),
              pw.Text("Description: ${data['description']}", style: pw.TextStyle(fontSize: 14)),
              pw.Text("Date: $formattedDate", style: pw.TextStyle(fontSize: 14)),
              pw.SizedBox(height: 10),
              pw.Text("Overall REBA Score: $overallScore", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Text("Risk Level: $risk", style: pw.TextStyle(fontSize: 14, color: PdfColors.red)),
              pw.SizedBox(height: 15),

              pw.Text("Detailed Scores", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Table(
                border: pw.TableBorder.all(),
                columnWidths: {
                  0: pw.FlexColumnWidth(1),
                  1: pw.FlexColumnWidth(1),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text("Body Part", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text("Score", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    ],
                  ),
                  ..._buildScoreRows(data)
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Text("End of Report", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        );
      },
    ),
  );

  // Save PDF File
  final output = await getExternalStorageDirectory();
  final file = File("${output!.path}/REBA_Report.pdf");
  await file.writeAsBytes(await pdf.save());

  // Share or Open PDF
  await Share.shareXFiles([XFile(file.path)], text: "Download your REBA Report");

}

// Helper function to determine risk category
String _getRiskCategory(int score) {
  if (score == 1) return 'Negligible Risk';
  if (score >= 2 && score <= 3) return 'Low Risk. Change may be needed';
  if (score >= 4 && score <= 7) return 'Medium Risk. Investigate further.';
  if (score >= 8 && score <= 10) return 'High Risk. Immediate change required.';
  return 'Very High Risk. Urgent Action!';
}

// Helper function to build score rows
List<pw.TableRow> _buildScoreRows(Map<String, dynamic> data) {
  List<String> bodyParts = ["Neck", "Trunk", "Legs", "Upper Arm", "Lower Arm", "Wrist"];
  List<pw.TableRow> rows = [];
  for (String part in bodyParts) {
    rows.add(pw.TableRow(children: [
      pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text(part)),
      pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text(data['${part.toLowerCase()}Score']?.toString() ?? '-')),
    ]));
  }
  return rows;
}

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // extendBodyBehindAppBar: false,
      backgroundColor: Colors.white,
      appBar: AppBar(elevation:0, backgroundColor:Colors.white, title: Text("Assessment Report", style:TextStyle(fontFamily: 'Poppins', fontSize:20, fontWeight: FontWeight.w600))),
      body: SafeArea(
      child:SingleChildScrollView(
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
             Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                  ),
                  onPressed: () => generatePdf(data),
                  child: Text("Delete Assessment", style: TextStyle(fontSize: 16, color: Colors.white)),
                ),
              ),

          ],
        ),
      ),
    )
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
          // print(data['images']);
          // print('oi');
          var imageData = (data['images'] as List<dynamic>?)
              ?.firstWhere((img) => img['segment'] == segment, orElse: () => null);
          print('Segment: ${imageData?['segment']}');
          print('Keypoints: ${imageData?['keypoints']}');

         List<Keypoint> keypoints = [];
          if (imageData != null && imageData is Map<String, dynamic> &&
              imageData.containsKey('keypoints') && imageData['keypoints'] is List) {
            keypoints = (imageData['keypoints'] as List)
                .map((point) => Keypoint(
                      (point['x'] as num).toDouble(), 
                      (point['y'] as num).toDouble(), 
                      0.1 // Default confidence value (adjust if needed)
                    ))
                .toList();
          }

          String scoreKey = scoreMapping[segment] ?? "";
          String score = data['bodyScores']?[scoreKey]?.toString() ?? "-";
          
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
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

                    // Image with keypoints overlay
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
                                Positioned.fill(  // Ensure the painter is on top
                                  child: CustomPaint(
                                    size: Size(100, 100),
                                    painter: VectorPainter(
                                      keypoints,
                                      segment,
                                      0, // Adjust if needed
                                      0, // Adjust if needed
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Icon(Icons.image_not_supported),
                    ),
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
                            style: TextStyle(fontSize: 14, fontFamily:'Poppins', fontWeight: FontWeight.w700),
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
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 6.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
              SizedBox(width: 12),

              // Wrap the score box and text in a Column
              Column(
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