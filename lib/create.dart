import 'package:cloud_firestore/cloud_firestore.dart';
import 'report.dart';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';


Future<String?> uploadImageToSupabase(File imageFile, String userId, String assessmentId, String segmentKey) async {
  final supabase = Supabase.instance.client;

  try {
    final fileName = '${assessmentId}_${segmentKey}.jpg';

    await supabase.storage.from('rebain').upload(
      'assessments/$userId/$fileName',
      imageFile,
      fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
    );

    return supabase.storage.from('rebain').getPublicUrl('assessments/$userId/$fileName');
  } catch (e) {
    print('Error uploading image: $e');
  }
  return null;
}