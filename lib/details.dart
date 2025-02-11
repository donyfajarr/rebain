import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'list.dart';

class AssessmentDetailsPage extends StatelessWidget {
  final String assessmentId;
  final Map<String, dynamic> data;

  const AssessmentDetailsPage({Key? key, required this.assessmentId, required this.data}) : super(key: key);

  Future<void> _deleteImagesFromSupabase(List<dynamic> images) async {
    final supabase = Supabase.instance.client;

    List<String> filePaths = images.map<String>((img) {
      String url = img['url'].toString();
      Uri uri = Uri.parse(url);
      List<String> segments = uri.pathSegments;

      // Extract the correct file path in Supabase Storage
      return segments.skip(5).join('/'); // Skipping 'storage', 'v1', 'object'
    }).toList();

    if (filePaths.isNotEmpty) {
      try {
        print('filepath : $filePaths');
        await supabase.storage.from('rebain').remove(filePaths);
        print("✅ Successfully deleted images from Supabase");
      } catch (e) {
        print("❌ Supabase delete error: $e");
      }
    }
  }

    // Function to delete the assessment
    Future<void> _deleteAssessment(BuildContext context) async {
      try {
        // Get images to delete from Supabase before removing Firestore entry
        List<dynamic> images = (data['images'] as List<dynamic>?) ?? [];

        // Delete images from Supabase
        await _deleteImagesFromSupabase(images);

        // Delete the assessment from Firestore
        await FirebaseFirestore.instance.collection('reba_assessments').doc(assessmentId).delete();

        print("✅ Deleted assessment successfully");

        // Navigate back to the list page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => AssessmentListPage()),
        );
      } catch (e) {
        print("❌ Error deleting assessment: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to delete assessment")),
        );
      }
    }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Assessment Details")),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('reba_assessments').doc(assessmentId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Assessment not found"));
          }
          
          // var data = snapshot.data!.data() as Map<String, dynamic>;
          
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                Text("Title: ${data['title']}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text("Description: ${data['description']}", style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                Text("Overall Score: ${data['overallScore']}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                
                if (data['bodyScores'] != null)
                  ...((data['bodyScores'] as Map<String, dynamic>).entries.map<Widget>((entry) => ListTile(
                        title: Text("${entry.key}: ${entry.value}"),
                  ),
                      )),
                
                const SizedBox(height: 12),
                if (data['images'] != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Images:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      if (data['images'] != null)
                      ...((data['images'] as List<dynamic>).map<Widget>((img) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(img['segment'].toString() ?? "Unknown Segment", 
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                                const SizedBox(height: 4),
                                img['url'] != null
                                    ? Image.network(img['url'].toString(), height: 200, fit: BoxFit.cover)
                                    : const Text("No Image Available"),
                              ],
                              
                            ),
                            
                      )
                          
                          )),
                    ],
                  ),
                const SizedBox(height:20),
                Center(
                  child: ElevatedButton(
                    onPressed: () => _deleteAssessment(context),
                    child: const Text("Delete Assessment", style: TextStyle(color: Colors.black))),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}
