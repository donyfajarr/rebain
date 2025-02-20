import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'details.dart';
import 'package:intl/intl.dart';

// ⬇️ Stateful Widget untuk Home dengan Bottom Navigation Bar
class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 1; // ⬅️ Default ke "Assessment"

  final List<Widget> _pages = [
    Placeholder(), // Home Page (Nanti bisa diganti)
    AssessmentListPage(), // ✅ Page untuk Assessment List
    Placeholder(), // QR Scanner (Placeholder)
    Placeholder(), // Settings Page
    Placeholder(), // Profile Page
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _pages[_currentIndex],

      // ✅ Bottom Navigation Bar dengan latar belakang putih
      bottomNavigationBar: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // ✅ Bottom Nav Background
          Container(
            height: 60,
            margin: EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  spreadRadius: 1,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                buildNavItem(Icons.home_rounded, "Home", 0),
                buildNavItem(Icons.assignment, "Assess", 1),
                SizedBox(width: 60), // Ruang untuk QR Button
                buildNavItem(Icons.settings, "Settings", 3),
                buildNavItem(Icons.person, "Profile", 4),
              ],
            ),
          ),

          // ✅ QR Code Floating Button di tengah
          Positioned(
            bottom: 20,
            child: GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => Placeholder()));
              },
              child: Container(
                width: 65,
                height: 65,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.black26, blurRadius: 6, spreadRadius: 1, offset: Offset(0, 3)),
                  ],
                ),
                child: Center(child: Icon(Icons.qr_code_scanner, color: Colors.white, size: 30)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Function untuk membuat Navigation Item
  Widget buildNavItem(IconData icon, String label, int index) {
    return GestureDetector(
      onTap: () {
        if (index != 2) setState(() => _currentIndex = index);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _currentIndex == index ? Colors.black : Colors.grey, size: 22),
          SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: _currentIndex == index ? FontWeight.w600 : FontWeight.w400, color: _currentIndex == index ? Colors.black : Colors.grey)),
        ],
      ),
    );
  }
}

// ⬇️ UI LIST SESUAI GAMBAR
class AssessmentListPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    String userId = FirebaseAuth.instance.currentUser?.uid ?? "anonymous";

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text("Recent Assessment", style: TextStyle(color: Colors.black, fontSize:16, fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
        // centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.history, color: Colors.black),
          onPressed: () {
         ;
          },
        ),
        
      ),
      body: Column(
        children: [
          // ✅ Search Bar & Filter
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: "Search...",
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
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: Icon(Icons.filter_alt_rounded, size: 18),
                  label: Text("Today"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color.fromRGBO(244, 246, 245, 1),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
                SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: Icon(Icons.sort, size: 18),
                  label: Text("Latest"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color.fromRGBO(244, 246, 245, 1),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ],
            ),
          ),

          // ✅ List dari Firestore
          Expanded(
  child: StreamBuilder(
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
        padding: EdgeInsets.symmetric(horizontal: 16),
        children: snapshot.data!.docs.map((doc) {
          var data = doc.data() as Map<String, dynamic>;

          // Validasi URL gambar dari Firestore
          String imageUrl = ''; // Default image
          if (data.containsKey('images') &&
    data['images'] is List<dynamic> &&
    (data['images'] as List<dynamic>).isNotEmpty &&
    data['images'][0] is Map<String, dynamic> &&
    (data['images'][0] as Map<String, dynamic>).containsKey('url')) {
  imageUrl = (data['images'][0] as Map<String, dynamic>)['url'].toString();
}

          // Konversi timestamp Firestore ke format yang dapat dibaca
          String formattedDate = "Unknown Date";
          if (data.containsKey('timestamp') && data['timestamp'] is Timestamp) {
            DateTime timestampDate = (data['timestamp'] as Timestamp).toDate();
            formattedDate = DateFormat('dd-MM-yyyy HH:mm:ss').format(timestampDate);
          }

          return Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            margin: EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🖼 Image on the left
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
                  SizedBox(width: 10), // Space between image and text

                  // 📝 Text & Button Section
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (data['title'] as String?) ?? "",
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Color.fromRGBO(55, 149, 112, 1),
                          ),
                          maxLines: 1, // Prevents overflow
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 8),

                        // 🗓 Date
                        Row(
                          children: [
                            Icon(Icons.calendar_month_rounded, size: 14),
                            SizedBox(width: 10),
                            Text(formattedDate, style: TextStyle(fontFamily:'Poppins', fontSize: 8, color: Colors.black)),
                          ],
                        ),
                        SizedBox(height: 4),

                        // ⚠ Risk Found
                        Row(
                          children: [
                            Icon(Icons.manage_search_rounded, size: 14),
                            SizedBox(width: 10),
                            Text("No risk found", style: TextStyle(fontFamily:'Poppins', fontSize: 8, color: Colors.black)),
                          ],
                        ),
                        SizedBox(height: 4),

                        // 📊 RULA Score
                        Row(
                          children: [
                            Icon(Icons.edit_document, size: 14, ),
                            SizedBox(width: 5),
                            Text("RULA Score: 4", style: TextStyle(fontFamily:'Poppins', fontSize: 8, color: Colors.black)),
                          ],
                        ),
                        SizedBox(height: 8), // Space before button

                        // 📌 Move Button Below Text
                        Align(
                          alignment: Alignment.bottomRight,
                          child: SizedBox(
                            // width: 120,
                            height: 28, // Prevents full width stretch
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
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                textStyle: TextStyle(fontSize: 12),
                                shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                              ),
                              child: Text("See details", style: TextStyle(fontFamily:'Poppins', fontWeight:FontWeight.w700, fontSize:8, color: Color.fromRGBO(52, 168, 83, 1))),
                            ),
                          ),
                        ),
                      ],
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
}
