import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';


class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Settings', style:TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 20)), centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          children: [
            
            SettingsTile(
              icon: Icons.import_export_rounded,
              title: "Export All Data",
              onTap: () => _handleTap("Export All Data"),
            ),
            SettingsTile(
              icon: Icons.delete_rounded,
              title: "Delete All Data",
              textColor: Colors.red,
              iconColor: Colors.red,
              onTap: () => _confirmDeleteAllData(context),
            ),
          ],
        ),
      ),
    );
  }

  void _handleTap(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("$title tapped!")),
    );
  }
}

class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color textColor;
  final Color iconColor;

  const SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.textColor = Colors.black,
    this.iconColor = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(title, style:TextStyle(color:textColor, fontFamily: 'Poppins', fontSize:14, fontWeight: FontWeight.w600)),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: onTap,
      ),
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


