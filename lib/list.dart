import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'details.dart'; // Ensure you create this file for assessment details

class AssessmentListPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    String userId = FirebaseAuth.instance.currentUser?.uid ?? "anonymous";

    return Scaffold(
      appBar: AppBar(title: Text("My Assessments")),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('reba_assessments')
            .where('userId', isEqualTo: userId)
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text("No assessments found."));
          }
          return ListView(
            children: snapshot.data!.docs.map((doc) {
              var data = doc.data() as Map<String, dynamic>;
              return ListTile(
                title: Text(data['title'].toString() ?? "Untitled Assessment"),
                subtitle: Text("Date: ${data['timestamp']}"),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AssessmentDetailsPage(assessmentId: doc.id, data: data,),
                    ),
                  );
                },
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
