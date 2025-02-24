import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'list.dart';
import 'package:intl/intl.dart';

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
            SizedBox(height: 16),
            _buildAnalysisSection("Neck, Trunk and Leg Analysis", ["Neck", "Trunk", "Legs & Posture"], data),
            _buildOtherScores(["Posture Score", "Force/Load Score"], data),
            _buildScoreABox(),
            SizedBox(height: 16),
            _buildAnalysisSection("Arm & Wrist Analysis", ["Upper Arm", "Lower Arm", "Wrist"], data),
            _buildOtherScores(["Force Load Score", "Arm Supported", "Coupling Score", "Activity Score"], data),
            _buildScoreABox(),
             SizedBox(height: 20),
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
      // Centered Title
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
                    // Segment Title
                    Text(
                      '$segment Position',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    SizedBox(height: 4),

                    // Image Container
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                      ),
                      child: imageData != null && imageData['url'] != null
                          ? ClipRRect(
                              child: Image.network(
                                imageData['url'].toString(),
                                fit: BoxFit.cover,
                              ),
                            )
                          : Icon(Icons.image_not_supported),
                    ),
                  ],
                ),
                SizedBox(width: 12),

                // Score Box with Segment Text Below
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

                        // Segment Text Below Score Box
                        Text(
                          segment +' Score',
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
          print(label);
          print(data['bodyScores']);
          print(score);
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 6.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(label, style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins',
                      )),
                ),
                SizedBox(width: 12),
                Container(
                  width: 60,
                  padding: EdgeInsets.all(12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Color.fromRGBO(235, 237, 240, 1),
                    // borderRadius: BorderRadius.circular(),
                  ),
                  child: Text(score, style: TextStyle(fontSize: 14, fontFamily:'Poppins', fontWeight: FontWeight.w700)),
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
      child: Center(
        child: Container(
          width: 150,
          height: 80,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(8)),
          child: Text("Score A", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}