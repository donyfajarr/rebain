import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdf/pdf.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  DateTime? startDate;
  DateTime? endDate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 20),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 📂 Export Section
            Card(
              color: Color.fromRGBO(244, 246, 245, 1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 2,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.import_export_rounded, color: Colors.black),
                        SizedBox(width: 10),
                        Text("Export Data", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    SizedBox(height: 10),
                    _buildDatePicker("Start Date", startDate, (pickedDate) {
                      setState(() => startDate = pickedDate);
                    }),
                    _buildDatePicker("End Date", endDate, (pickedDate) {
                      setState(() => endDate = pickedDate);
                    }),
                    SizedBox(height: 20),
                    
                    // Centered Export Buttons (White/Grey Color)
                    Center(
                      child: Column(
                        children: [
                          _buildActionButton(
                            label: "Export Data",
                            icon: Icons.save_alt_rounded,
                            color: Colors.white,
                            textColor: Colors.black,
                            onPressed: () => generateAllPdfs(context, startDate, endDate),
                          ),
                          SizedBox(height: 10),
                          _buildActionButton(
                            label: "Export All Data",
                            icon: Icons.cloud_download_rounded,
                            color: Colors.white,
                            textColor: Colors.black,
                            onPressed: () => generateAllPdfs(context, null, null),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 30),

            // ❌ Delete All Data (Standalone, Red Background with White Text/Icon)
            _buildActionButton(
              label: "Delete All Data",
              icon: Icons.delete_forever_rounded,
              color: Colors.red,
              textColor: Colors.white,
              onPressed: () => _confirmDeleteAllData(context),
            ),
          ],
        ),
      ),
    );
  }

  /// 📅 Date Picker Widget
  Widget _buildDatePicker(String label, DateTime? selectedDate, Function(DateTime) onDatePicked) {
    return GestureDetector(
      onTap: () async {
        DateTime? pickedDate = await showDatePicker(
          context: context,
          initialDate: selectedDate ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
        );
        if (pickedDate != null) {
          onDatePicked(pickedDate);
        }
      },
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 5),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              selectedDate == null ? label : "${selectedDate.toLocal()}".split(' ')[0],
              style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600),
            ),
            Icon(Icons.calendar_today_rounded),
          ],
        ),
      ),
    );
  }

  /// 🔘 Styled Button Widget
  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required Color textColor,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      icon: Icon(icon, color: textColor),
      label: Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20), // Increased padding
      ),
      onPressed: onPressed,
    );
  }
}



class DataDeletionService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final SupabaseClient supabase = Supabase.instance.client;
  final FirebaseAuth auth = FirebaseAuth.instance;

  Future<void> deleteAllUserData(BuildContext context) async {
    try {
      String? userId = auth.currentUser?.uid;
      if (userId == null) {
        print("❌ No logged-in user found.");
        return;
      }

      print("🔍 Fetching user data for deletion...");

      // Step 1: Fetch all assessments for the user
      QuerySnapshot assessmentsSnapshot = await firestore
          .collection('reba_assessments')
          .where('userId', isEqualTo: userId)
          .get();

      List<String> assessmentIds = [];
      List<String> imagePaths = [];

      for (var doc in assessmentsSnapshot.docs) {
        assessmentIds.add(doc.id);
        List<dynamic> images = (doc['images'] as List<dynamic>?) ?? [];

        // Extract image paths for Supabase deletion
        imagePaths.addAll(images.map((img) {
          Uri uri = Uri.parse(img['url'].toString());
          return uri.pathSegments.skip(5).join('/'); // Supabase file path
        }));
      }

      // Step 2: Delete images from Supabase
      if (imagePaths.isNotEmpty) {
        await _deleteImagesFromSupabase(imagePaths);
      }

      // Step 3: Delete all related Firestore documents
      for (String assessmentId in assessmentIds) {
        await firestore.collection('reba_assessments').doc(assessmentId).delete();
      }

      print("✅ Successfully deleted all assessments.");

      // Step 4: Delete user data from other collections (if applicable)
      await _deleteUserRelatedData(userId);

      // Step 5: Notify user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ Successfully deleted all user data.")),
      );

    } catch (e) {
      print("❌ Error deleting user data: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to delete all data.")),
      );
    }
  }

  Future<void> _deleteImagesFromSupabase(List<String> filePaths) async {
    if (filePaths.isEmpty) return;

    try {
      print('🗑️ Deleting images from Supabase: $filePaths');
      await supabase.storage.from('rebain').remove(filePaths);
      print("✅ Images deleted from Supabase.");
    } catch (e) {
      print("❌ Supabase delete error: $e");
    }
  }

  Future<void> _deleteUserRelatedData(String userId) async {
    // Example: If there are other collections related to the user, delete them here
    List<String> collectionsToDelete = ['user_activity_logs', 'user_settings'];

    for (String collection in collectionsToDelete) {
      QuerySnapshot snapshot = await firestore
          .collection(collection)
          .where('userId', isEqualTo: userId)
          .get();

      for (var doc in snapshot.docs) {
        await firestore.collection(collection).doc(doc.id).delete();
      }
    }

    print("✅ Deleted related user data.");
  }
}

void _confirmDeleteAllData(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: Text("Confirm Deletion"),
        content: Text(
            "Are you sure you want to delete all your data? This action cannot be undone."),
        actions: [
          TextButton(
            child: Text("Cancel"),
            onPressed: () => Navigator.pop(dialogContext),
          ),
          TextButton(
            child: Text("Delete", style: TextStyle(color: Colors.red)),
            onPressed: () {
              Navigator.pop(dialogContext);
              DataDeletionService().deleteAllUserData(context);
            },
          ),
        ],
      );
    },
  );
}



// ✅ Fetch all assessments created by the logged-in user
Future<List<Map<String, dynamic>>> fetchAllAssessments() async {
  String userId = FirebaseAuth.instance.currentUser!.uid;

  QuerySnapshot querySnapshot = await FirebaseFirestore.instance
      .collection("reba_assessments")
      .where("userId", isEqualTo: userId)
      .get();

  return querySnapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
}

Future<List<Map<String, dynamic>>> fetchFilteredData(DateTime start, DateTime end) async {
  String userId = FirebaseAuth.instance.currentUser!.uid;
  QuerySnapshot snapshot = await FirebaseFirestore.instance
      .collection("reba_assessments")
      .where("userId", isEqualTo: userId)
      .where("timestamp", isGreaterThanOrEqualTo: Timestamp.fromDate(start))
      .where("timestamp", isLessThanOrEqualTo: Timestamp.fromDate(end))
      .get();

  return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
}

// ✅ Generate PDFs for all assessments in the background

Future<void> generateAllPdfs(BuildContext context, DateTime? start, DateTime? end) async {
   List<Map<String, dynamic>> filteredData;

  // Step 1️⃣: Request storage permission
  var status = await Permission.storage.request();
  if (!status.isGranted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Storage permission denied! Cannot export PDFs.")),
    );
    return;
  }


  // Step 2️⃣: Let the user select a folder
  String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

  if (selectedDirectory == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("No folder selected. Export canceled.")),
    );
    return;
  }

  Directory targetDir = Directory(selectedDirectory);
  if (!await targetDir.exists()) {
    await targetDir.create(recursive: true);
  }


  // Step 3️⃣: Fetch all assessments
  // List<Map<String, dynamic>> assessments = await fetchAllAssessments();

  if (start != null && end != null) {
    // ✅ Fetch data within the date range
    // filteredData = await fetchFilteredData(start, end);
    List<Map<String, dynamic>> filteredData = await fetchFilteredData(start, end);
     if (filteredData.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text("No data found for the selected date range."),
    ));
    return;
  }
  else {
    for (var data in filteredData) {
        await generatePdf(data, targetDir);
  }
  }
    
  } else {
    // 🔄 Fetch all data if no date is selected
    List<Map<String, dynamic>> assessments = await fetchAllAssessments();
     for (var data in assessments) {
    await generatePdf(data, targetDir);
  }
  }
  
  

  // Step 4️⃣: Generate PDFs in background
 

  // Step 5️⃣: Notify user when complete
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text("All PDFs have been exported successfully!")),
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

Future<void> generatePdf(Map<String, dynamic> data, Directory targetDir) async {
  final pdf = pw.Document();
  DateTime timestampDate = (data['timestamp'] as Timestamp).toDate();
  String formattedDate = "${timestampDate.day}-${timestampDate.month}-${timestampDate.year} ${timestampDate.hour}:${timestampDate.minute}";
  
  int overallScore = (data['overallScore'] as num?)?.toInt() ?? 0;
  String risk = _getRiskCategory(overallScore);
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
              _buildScoreRow("Force Load Score", (bodyScores["forceLoad"] as num?)?.toInt()),

              _buildCenteredScore("REBA Score A", (data['rebaScoreA'] as num?)?.toInt()),

              _buildSection("Arm & Wrist Analysis"),
              armWristTable, // ✅ **Use preloaded table here**
              _buildScoreRow("Coupling Score", (bodyScores["coupling"] as num?)?.toInt()),

              _buildCenteredScore("REBA Score B", (data['rebaScoreB'] as num?)?.toInt()),

              _buildSection("Activity Score"),
              _buildScoreRow("Activity Score", (bodyScores["activityScore"] as num?)?.toInt()),

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
  
  if (await Permission.manageExternalStorage.request().isDenied) {
    print("❌ Storage permission denied");
    return;
  }

  // ✅ 2️⃣ Define the target folder in public storage
  

  // ✅ 3️⃣ Define the file path with title instead of timestamp
  String sanitizedTitle = data['title'].toString().replaceAll(RegExp(r'[\/:*?"<>|]'), "_"); // Remove invalid characters
  String savePath = "${targetDir.path}/REBA_Report_$sanitizedTitle.pdf";

  final file = File(savePath);

  try {
    await file.writeAsBytes(await pdf.save());
    print("✅ PDF saved at: $savePath");
  } catch (e) {
    print("❌ Error saving PDF: $e");
  }
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

Future<pw.Widget> _buildImageScoreTable(List<Map<String, dynamic>> images, Map<String, dynamic> scores, Map<String, String> segmentMapping) async {
  return pw.Table(
    border: pw.TableBorder.all(),
    columnWidths: {0: pw.FlexColumnWidth(1), 1: pw.FlexColumnWidth(1)},
    children: [
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColors.grey200),
        children: [
          pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text("Segment", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
          pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text("Score", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
        ],
      ),
      for (var entry in segmentMapping.entries)
        pw.TableRow(children: [
          pw.Padding(
            padding: pw.EdgeInsets.all(8),
            child: pw.Column(
              children: [
                pw.Text(entry.key),
                if (images.any((img) => img['segment'] == entry.key))
                  await _drawKeypointsOnImage(images.firstWhere((img) => img['segment'] == entry.key)),
              ],
            ),
          ),
          pw.Padding(padding: pw.EdgeInsets.all(8), child: pw.Text((scores[entry.value] as num?)?.toInt()?.toString() ?? "-")),
        ]),
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
// Function to download and convert an image from Supabase URL to bytes

// Helper function to determine risk category
String _getRiskCategory(int score) {
  if (score == 1) return 'Negligible Risk';
  if (score >= 2 && score <= 3) return 'Low Risk. Change may be needed';
  if (score >= 4 && score <= 7) return 'Medium Risk. Investigate further.';
  if (score >= 8 && score <= 10) return 'High Risk. Immediate change required.';
  return 'Very High Risk. Urgent Action!';
}

