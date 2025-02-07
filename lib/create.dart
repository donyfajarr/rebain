import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> saveSegmentData(String assessmentId, String segment, String imageUrl, Map<String, dynamic> keypoints, Map<String, dynamic> angles) async {
  final docRef = FirebaseFirestore.instance.collection('assessments').doc(assessmentId);
  
  await docRef.set({
    'segments.$segment': {
      'imageUrl': imageUrl,
      'keypoints': keypoints,
      'angles': angles,
    },
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  print("$segment data saved successfully!");
}