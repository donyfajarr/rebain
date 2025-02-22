import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'details.dart';
import 'package:intl/intl.dart';

// ⬇️ Stateful Widget untuk Home dengan Bottom Navigation Bar
// class HomeScreen extends StatefulWidget {
//   @override
//   _HomeScreenState createState() => _HomeScreenState();
// }

// class _HomeScreenState extends State<HomeScreen> {
//   int _currentIndex = 1; // ⬅️ Default ke "Assessment"

//   final List<Widget> _pages = [
//     Placeholder(), // Home Page (Nanti bisa diganti)
//     AssessmentListPage(), // ✅ Page untuk Assessment List
//     Placeholder(), // QR Scanner (Placeholder)
//     Placeholder(), // Settings Page
//     Placeholder(), // Profile Page
//   ];

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: _pages[_currentIndex],

//       // ✅ Bottom Navigation Bar dengan latar belakang putih
//       bottomNavigationBar: Stack(
//         alignment: Alignment.bottomCenter,
//         children: [
//           // ✅ Bottom Nav Background
//           Container(
//             height: 60,
//             margin: EdgeInsets.only(bottom: 10),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(20),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black12,
//                   blurRadius: 8,
//                   spreadRadius: 1,
//                   offset: Offset(0, 3),
//                 ),
//               ],
//             ),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceAround,
//               children: [
//                 buildNavItem(Icons.home_rounded, "Home", 0),
//                 buildNavItem(Icons.assignment, "Assess", 1),
//                 SizedBox(width: 60), // Ruang untuk QR Button
//                 buildNavItem(Icons.settings, "Settings", 3),
//                 buildNavItem(Icons.person, "Profile", 4),
//               ],
//             ),
//           ),

//           // ✅ QR Code Floating Button di tengah
//           Positioned(
//             bottom: 20,
//             child: GestureDetector(
//               onTap: () {
//                 Navigator.push(context, MaterialPageRoute(builder: (context) => Placeholder()));
//               },
//               child: Container(
//                 width: 65,
//                 height: 65,
//                 decoration: BoxDecoration(
//                   color: Color.fromRGBO(55, 149, 112, 1),
//                   shape: BoxShape.circle,
//                   boxShadow: [
//                     BoxShadow(color: Colors.black26, blurRadius: 6, spreadRadius: 1, offset: Offset(0, 3)),
//                   ],
//                 ),
//                 child: Center(child: Icon(Icons.qr_code_scanner, color: Colors.white, size: 30)),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // ✅ Function untuk membuat Navigation Item
//   Widget buildNavItem(IconData icon, String label, int index) {
//     return GestureDetector(
//       onTap: () {
//         if (index != 2) setState(() => _currentIndex = index);
//       },
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Icon(icon, color: _currentIndex == index ? Colors.black : Colors.grey, size: 22),
//           SizedBox(height: 2),
//           Text(label, style: TextStyle(fontSize: 10, fontWeight: _currentIndex == index ? FontWeight.w600 : FontWeight.w400, color: _currentIndex == index ? Colors.black : Colors.grey)),
//         ],
//       ),
//     );
//   }
// }

// ⬇️ UI LIST SESUAI GAMBAR
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
                                  SizedBox(height: 2),

                                  // 🗓 Date
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                                      SizedBox(width: 5),
                                      Text(formattedDate, style: TextStyle(fontSize: 12, color: Colors.grey)),
                                    ],
                                  ),
                                  SizedBox(height: 2),

                                  // ⚠ Risk Found
                                  Row(
                                    children: [
                                      Icon(Icons.warning, size: 14, color: Colors.orange),
                                      SizedBox(width: 5),
                                      Text("No risk found", style: TextStyle(fontSize: 12, color: Colors.grey)),
                                    ],
                                  ),
                                  SizedBox(height: 2),

                                  // 📊 RULA Score
                                  Row(
                                    children: [
                                      Icon(Icons.bar_chart, size: 14, color: Colors.blue),
                                      SizedBox(width: 5),
                                      Text("RULA Score: 4", style: TextStyle(fontSize: 12, color: Colors.grey)),
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


