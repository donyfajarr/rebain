import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'details.dart';
import 'package:intl/intl.dart';

class AssessmentListPage extends StatefulWidget {
  @override
  _AssessmentListPageState createState() => _AssessmentListPageState();
}

class _AssessmentListPageState extends State<AssessmentListPage> {
  String userId = FirebaseAuth.instance.currentUser?.uid ?? "anonymous";
  String selectedFilter = "All"; // Default filter
  bool isLatest = true; // Sorting toggle
  String searchQuery = ""; // Search input

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          "Recent Assessment",
          style: TextStyle(color: Colors.black, fontSize: 16, fontFamily: 'Poppins', fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: Icon(Icons.history, color: Colors.black),
          onPressed: () {},
        ),
      ),
      body: Column(
        children: [
          // 🔍 Search, Filter, and Sort
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // 🔍 Search Bar
                Expanded(
                  child: TextField(
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value.toLowerCase();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: "Search by title...",
                      hintStyle: TextStyle(fontFamily: 'Poppins', fontSize:12),
                      prefixIcon: Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: Color.fromRGBO(244, 246, 245, 1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10),

                // 📌 Filter Dropdown
                DropdownButton<String>(
                  value: selectedFilter,
                  onChanged: (newValue) {
                    setState(() {
                      selectedFilter = newValue!;
                    });
                  },
                  items: ["All", "This Week", "This Month", "This Year"].map((filter) {
                    return DropdownMenuItem<String>(
                      value: filter,
                      child: Text(filter, style:TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize:12)),
                    );
                  }).toList(),
                ),
                SizedBox(width: 10),

                // 🔄 Sort Button
                IconButton(
                  icon: Icon(isLatest ? Icons.sort : Icons.swap_vert),
                  onPressed: () {
                    setState(() {
                      isLatest = !isLatest;
                    });
                  },
                ),
              ],
            ),
          ),

          // 📋 Firestore List
          Expanded(
            child: StreamBuilder(
              stream: _getFilteredStream(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text("No assessments found."));
                }

                // 🔎 Apply search filter on title
                var filteredDocs = snapshot.data!.docs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  String title = (data['title'] as String?)?.toLowerCase() ?? "";
                  return title.contains(searchQuery);
                }).toList();

                if (filteredDocs.isEmpty) {
                  return Center(child: Text("No matching assessments."));
                }

                return ListView(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  children: filteredDocs.map((doc) {
                    var data = doc.data() as Map<String, dynamic>;

                   // 🖼 Get Image URL
                    String imageUrl = _getImageUrl(data);

                    // 🗓 Convert Timestamp
                    String formattedDate = _formatTimestamp(data['timestamp']);
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

                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      margin: EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 📷 Image
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                imageUrl,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Icon(Icons.image_not_supported, size: 60, color: Colors.grey),
                              ),
                            ),
                            SizedBox(width: 10),

                            // 📝 Text & Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (data['title'] as String?) ?? "WS Produksi",
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: Color.fromRGBO(55, 149, 112, 1),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 6),

                                  // 🗓 Date
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                                      SizedBox(width: 5),
                                      Text(formattedDate, style: TextStyle(fontSize: 12, color: Colors.grey)),
                                    ],
                                  ),
                                  SizedBox(height: 4),

                                  // ⚠ Risk Found
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start, // Ensure alignment
                                    children: [
                                      Icon(Icons.warning, size: 14, color: Colors.grey),
                                      SizedBox(width: 5),
                                      Expanded( // Allows text to wrap instead of overflowing
                                        child: Text(
                                          risk,
                                          style: TextStyle(fontSize: 12, color: Colors.grey),
                                          softWrap: true,
                                          overflow: TextOverflow.ellipsis, // Adds "..." if too long
                                          maxLines: 2, // Adjust as needed
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 4),

                                  // 📊 RULA Score
                                  Row(
                                    children: [
                                      Icon(Icons.bar_chart, size: 14, color: Colors.grey),
                                      SizedBox(width: 5),
                                      Text("REBA Score: $overallScore", style: TextStyle(fontSize: 12, color: Colors.grey)),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // 📌 Button Bottom Right
                            Align(
                              alignment: Alignment.bottomRight,
                              child: SizedBox(
                                height: 28,
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => AssessmentDetailsPage(
                                          assessmentId: doc.id,
                                          data: data,
                                        ),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    // textStyle: TextStyle(fontSize: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  child: Text("See details", style: TextStyle(fontFamily:'Poppins', fontSize:10, fontWeight:FontWeight.w600, color:Color.fromRGBO(55, 149, 112, 1))),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 📌 Get Firestore Stream with Filtering & Sorting
  Stream<QuerySnapshot> _getFilteredStream() {
    Query query = FirebaseFirestore.instance
        .collection('reba_assessments')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: isLatest);

    DateTime now = DateTime.now();
    DateTime startDate;

    if (selectedFilter == "This Week") {
      startDate = now.subtract(Duration(days: now.weekday - 1));
      query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    } else if (selectedFilter == "This Month") {
      startDate = DateTime(now.year, now.month, 1);
      query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    } else if (selectedFilter == "This Year") {
      startDate = DateTime(now.year, 1, 1);
      query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }

    return query.snapshots();
  }
}



  // 🖼 Get Image URL
  String _getImageUrl(Map<String, dynamic> data) {
    if (data.containsKey('images') &&
        data['images'] is List<dynamic> &&
        (data['images'] as List<dynamic>).isNotEmpty &&
        data['images'][0] is Map<String, dynamic> &&
        (data['images'][0] as Map<String, dynamic>).containsKey('url')) {
      return (data['images'][0] as Map<String, dynamic>)['url'].toString();
    }
    return 'https://via.placeholder.com/60';
  }

  // 🗓 Format Timestamp
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return DateFormat('dd-MM-yyyy HH:mm:ss').format(timestamp.toDate());
    }
    return "Unknown Date";
  }


