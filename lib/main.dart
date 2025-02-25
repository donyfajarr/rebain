import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'dart:ui';


// import 'splash_screen.dart';
import 'input.dart'; // Import your input.dart file
import 'create.dart'; // Ensure form.dart contains SimpleForm
import 'package:firebase_core/firebase_core.dart';
import 'list.dart';
import 'details.dart';
import 'profil.dart';

import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


// import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: "assets/.env");
  String supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  String supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

    await Firebase.initializeApp();
    await supabase.Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey
    );
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Image Picker and MoveNet',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: SplashScreen(), // Start with SignInScreen
    );
  }
}

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    // Navigate to SignInScreen after 3 seconds
    Future.delayed(Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => SignInScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            var scale = Tween(begin: 0.8, end: 1.0).animate(animation);
            return ScaleTransition(scale: scale, child: child);
        },
      ),);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/logo.png', height: 200), // Your logo here
            SizedBox(height: 10),
            Text("REBAIN",
                style: TextStyle(
                    fontFamily: 'LilitaOne',
                    fontSize: 36,
                    color: Color(0xFF086444))),
          ],
        ),
      ),
    );
  }
}

class SignInScreen extends StatefulWidget {
  @override
  _SignInScreenState createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final Uri googleRegisterUrl = Uri.parse('https://accounts.google.com/signup');

  bool _isSigningIn = false;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isSigningIn = true;
    });

    try {
      // Sign in with Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // The user canceled the sign-in
        return;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Check for null values
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        print("Error: Access token or ID token is null");
        return;
      }

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // This will sign in the user to Firebase with the Google credentials
      await FirebaseAuth.instance.signInWithCredential(credential);

      // Now you can safely print the current user
      User? user = FirebaseAuth.instance.currentUser;
      print(user); // This should not be null

      // If successful, navigate to HomeScreen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );
    } catch (error) {
      print("Error signing in: $error");
    } finally {
      setState(() {
        _isSigningIn = false;
      });
    }
  }

 void _launchURL() async {
    if (await canLaunchUrl(googleRegisterUrl)) {
      await launchUrl(googleRegisterUrl);
    } else {
      throw 'Could not launch $googleRegisterUrl';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Full-width Top Decoration (Extends behind the status bar)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Image.asset(
              'assets/group.png', // Your asset
              width: MediaQuery.of(context).size.width, // Full width
              fit: BoxFit.cover, // Ensures full coverage
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Center Content
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [

                        Text(
                          "Hello!",
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),

                        Text(
                          "Please sign-in",
                       
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14, 
                            color: Colors.black),
                          textAlign: TextAlign.center,
                        ),

                        Text(
                          "into your own account.",
                       
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14, 
                            color: Colors.black),
                          textAlign: TextAlign.center,
                        ),



                        SizedBox(height: 30),

                        // Logo
                        Image.asset('assets/logo.png', height: 180),
                        SizedBox(height: 10),

                        // App Name
                        Text(
                          "REBAIN",
                          style: TextStyle(
                            fontFamily: 'LilitaOne',
                            fontSize: 36,
                            color: Color(0xFF086444),
                          ),
                        ),

                        SizedBox(height: 20),

                        // Welcome Text
                        

                        // Google Sign-In Button
                        GestureDetector(
                          onTap: () {
                            _signInWithGoogle();
                          },
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: Color.fromRGBO(55, 149, 112, 1),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'assets/google_icon.png',
                                  height: 24,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  "Sign In with Google",
                                  style: TextStyle(
                                    fontFamily : 'Poppins',
                                    fontWeight : FontWeight.w600,
                                    color: Color.fromRGBO(255, 250, 244, 1),
                                    fontSize: 16,
                                    
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        SizedBox(height: 20),

                        // Create Account Link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Not registered yet? ",
                              style: TextStyle(fontSize: 14, color: Colors.black54),
                            ),
                            GestureDetector(
                              onTap: () {
                                _launchURL();
                              },
                              child: Text(
                                "Create Account",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {

  @override

  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  late final List<Widget> _pages;


  @override
  void initState() {
    super.initState();
    _pages = [
      HomeContent(onTabChanged: (index) {
        setState(() => _currentIndex = index);
      }),
      AssessmentListPage(), // ✅ Halaman Assessment List
      ImagePickerScreen(), // QR Scanner (Nanti diganti)
      Placeholder(), // Settings Page
      ProfilePage(), // Profile Page
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _pages[_currentIndex],

      // Bottom Navigation Bar dengan QR Code Floating Button
      bottomNavigationBar: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Bottom Navigation Bar
          Container(
            margin: EdgeInsets.only(bottom: 10), // ✅ Naikkan sedikit
            child: BottomAppBar(
              shape: CircularNotchedRectangle(),
              notchMargin: 6,
              elevation: 0,
              color: Colors.white,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20), // ✅ Bikin lebih smooth
                  border: Border.all(color: Color.fromRGBO(239, 239, 239, 1), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 1,
                      spreadRadius: 1,
                      offset: Offset(0, 0), // Efek mengambang
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    buildNavItem(Icons.home_rounded, "Home", 0),
                    buildNavItem(Icons.assignment, "Assess", 1),
                    SizedBox(width: 48), // ✅ Space for floating QR Box
                    buildNavItem(Icons.settings, "Settings", 3),
                    buildNavItem(Icons.person, "Profile", 4),
                  ],
                ),
              ),
            ),
          ),

          // Custom QR Code Button dengan Background Lingkaran Hijau
          Positioned(
            bottom: 25, // ✅ Turunkan sedikit agar lebih pas
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ImagePickerScreen()), // QR Scanner Page
                );
              },
              child: Container(
                width: 65, // ✅ Lebih kecil dari FloatingActionButton biasa
                height: 65,
                decoration: BoxDecoration(
                  color: Color.fromRGBO(55, 149, 112, 1), // ✅ Warna background hijau
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 6,
                      spreadRadius: 1,
                      offset: Offset(0, 3), // ✅ Efek shadow agar tampak floating
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(Icons.qr_code_scanner, color: Colors.white, size: 30), // ✅ Ikon QR Scanner
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Function untuk membuat navigation item
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
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: _currentIndex == index ? FontWeight.w600 : FontWeight.w400,
              color: _currentIndex == index ? Colors.black : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}


class HomeContent extends StatefulWidget {
  final String? user;
  final Function(int) onTabChanged;

  HomeContent({this.user, required this.onTabChanged});

  @override
  _HomeContentState createState() => _HomeContentState();
}

Future<Map<String, int>> fetchAssessmentData(String filter) async {
  // Get the current date and calculate the date range based on the filter
  DateTime now = DateTime.now();
  DateTime startDate;
  
  switch (filter) {
    case "This Week":
      startDate = now.subtract(Duration(days: now.weekday - 1)); // Start of the week
      break;
    case "This Month":
      startDate = DateTime(now.year, now.month, 1); // First day of the month
      break;
    case "This Year":
      startDate = DateTime(now.year, 1, 1); // First day of the year
      break;
    default:
      startDate = now;
  }
  final test = await FirebaseFirestore.instance.collection('reba_assessments');
  
  // Query assessments from Firestore based on the date range
  final userId = FirebaseAuth.instance.currentUser?.uid;
  QuerySnapshot querySnapshot = await FirebaseFirestore.instance
      .collection('reba_assessments')
      .where('userId', isEqualTo: userId)
      .where('timestamp', isGreaterThanOrEqualTo: startDate)
      .get();
 

  // Count the number of assessments and risk results

  int totalAssessments = querySnapshot.docs.length;
  int riskResults = querySnapshot.docs.where((doc) {
      var overallScore = doc['overallScore'];
      // Ensure 'overallScore' is a number and check if it's greater than 1
      if (overallScore is num) {
        return overallScore > 1;
      }
      return false;
    }).length;

  return {
    'totalAssessments': totalAssessments,
    'riskResults': riskResults,
  };
}

// Home Content Widget
class _HomeContentState extends State<HomeContent> {
  final userId = FirebaseAuth.instance.currentUser?.uid; // Get the current user ID
  final String? userName = FirebaseAuth.instance.currentUser?.displayName;
  String selectedFilter = "This Week"; // Default selected option
  int totalAssessments = 0;
  int riskResults = 0;
  String searchQuery = "";
  // Method to fetch the data based on the selected filter
 
  @override
  void initState() {
    super.initState();
    _fetchData(selectedFilter); // Fetch data when widget is initialized
  }

   Future<void> _fetchData(String filter) async {
    var data = await fetchAssessmentData(filter);
    setState(() {
      totalAssessments = data['totalAssessments'] ?? 0;
      riskResults = data['riskResults'] ?? 0;
    });
  }
  // HomeContent({this.userName = "User"}); // Default to "User" if name is null

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        physics: BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting
              SizedBox(height: 10),
              Row(
                children: [
                  CircleAvatar(
                    // radius: 20,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.sunny, color: Color.fromRGBO(77, 197, 150, 1)),
                  ),
                  SizedBox(width: 10),
                  Text(
                    "Hi, $userName!", // Display Google Name
                    style: TextStyle(
                      fontFamily: 'Poppins', 
                      fontSize: 16, 
                      fontWeight: FontWeight.w600),
                  ),
                ],
              ),
                

              SizedBox(height: 10),

              // Search Bar
              Container(
                // padding: EdgeInsets.only
                decoration: BoxDecoration(
                  color: Color.fromRGBO(244, 246, 245, 1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  onChanged: (value) {
                      setState(() {
                        searchQuery = value.toLowerCase();
                      });},
                  decoration: InputDecoration(
                    hintText: "Search your assessment results...",
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.search),
                    contentPadding: EdgeInsets.symmetric(vertical: 16),
                  ),
                   style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w200,
                    ),
                    
                ),
              ),

              SizedBox(height: 20),

              // Assessment Recap
             Container(
  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
  decoration: BoxDecoration(
    color: Color.fromRGBO(244, 246, 245, 1),
    borderRadius: BorderRadius.circular(20),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Row for title with background & dropdown
      Container(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: Color.fromRGBO(77, 197, 150, 1), // Light green background
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Title text
            Text(
              "Your Assessment Recap",
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12, fontWeight: FontWeight.w600,
                color: Colors.white),
            ),
            Container(
              // width: 100,
              // height: 40,
              padding: EdgeInsets.only(left:10, top: 0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20), // 20px border radius
                // border: Border.all(color: Colors.blueAccent
                color: Color.fromRGBO(55, 149, 112, 1) // Border color
            ),
            child:
            // Dropdown button inside the same green box
            DropdownButton<String>(
              value: selectedFilter,
              icon: Icon(Icons.arrow_drop_down, color: Colors.white),
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 8,
              ),
              underline: SizedBox(), // Removes default underline
              dropdownColor: Colors.grey,
              // dropdown // Optional for dropdown color
              isExpanded: false,
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    selectedFilter = newValue;
                    _fetchData(selectedFilter);
                  });
                }
              },
              items: ["This Month", "This Week", "This Year"]
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value, style:TextStyle(color : Colors.white)),
                );
              }).toList(),
            ),
            ),
          ],
        ),
      ),

      SizedBox(height: 10),

      // Row for assessment details
      Row(
        
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        
         children: [
          recapItem(
            Icons.history, 
            "$totalAssessments Assessment", 
            "See Details", 
            iconBackgroundColor: Color.fromRGBO(55, 149, 112, 100),  // Green background for assessment
            iconColor: Colors.white  // White icon color for visibility
          ),
          recapItem(
            Icons.warning, 
            "$riskResults Risk Result", 
            "See Details", 
            iconBackgroundColor: Color.fromRGBO(232, 183, 10, 1),  // Yellow background for risk results
            iconColor: Colors.white // Black icon color for contrast
          ),
        ],
      ),
    ],
  ),
),

              SizedBox(height: 20),

              // Latest Assessments
              Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween, // Distribute the items across the row
  children: [
    Text("Your Latest Assessment", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Poppins', color: Colors.black)),
    GestureDetector(
      onTap: () {
        widget.onTabChanged(1);
      },
      child: Container(
        padding: EdgeInsets.all(8), // Add padding inside the circle
        decoration: BoxDecoration(
          shape: BoxShape.circle, // Makes the background circular
          color: Color.fromRGBO(244, 246, 245, 1), // Circle background color
        ),
        child: Icon(
          Icons.arrow_forward_ios, // Arrow icon
          color: Colors.black, // Icon color
          size: 16, // Icon size
        ),
      ),
    ),
  ],
),

              
              SizedBox(height: 10),

              // Latest Assessments List
              

            // StreamBuilder<QuerySnapshot>(
            //   stream: FirebaseFirestore.instance
            //       .collection('reba_assessments')
            //       .where('userId', isEqualTo: userId) // Filter by the userId field
            //       .snapshots(),
            //   builder: (context, snapshot) {
            //     if (snapshot.connectionState == ConnectionState.waiting) {
            //       return const Center(child: CircularProgressIndicator());
            //     }

            //     if (snapshot.hasError) {
            //       return const Center(child: Text("Error fetching data"));
            //     }

            //     if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            //       return const Center(child: Text("No assessments available"));
            //     }

            //     var assessments = snapshot.data!.docs;
            //     if (searchQuery.isNotEmpty){
            //           assessments = assessments.where((doc) 
            //           {
            //             var data = doc.data() as Map<String, dynamic>;
            //             String title = (data['title'] as String?)?.toLowerCase() ?? "";
            //             return title.contains(searchQuery.toLowerCase());
            //           }).toList();
                      
            //           // var assessment = filteredDocs[index].data() as Map<String, dynamic>;
            //         }
                    
            //     if (assessments.isEmpty) {
            //         return const Center(child: 
            //         Text("No Matching Assessment", 
            //         style: TextStyle(
            //           fontSize: 14,
            //           fontFamily: 'Poppins',
            //           fontWeight: FontWeight.w300, 
            //         )));
            //       }
                    
                  
                  
                
            //     return Column(
            //       children: List.generate(assessments.length, (index) {
            //     //     if (filteredDocs.isEmpty){
            //     //   return Center(child:Text("No Matching Assessment"));
            //         var doc = assessments[index]; // Dapatkan dokumen Firestore
            //         var data = doc.data() as Map<String, dynamic>; 
            //         var assessment = assessments[index].data() as Map<String, dynamic>;

                    

            //         // Safely retrieve the title
            //         String assessmentId = doc.id;

            //         String title = (assessment['title'] ?? 'Unknown').toString();

            //         // Safely retrieve the timestamp (now as a Timestamp, not String)
            //         Timestamp timestamp = assessment['timestamp'] as Timestamp;
            //         DateTime timestampDate = timestamp.toDate();

            //         String formattedDate = DateFormat('dd-MM-yyyy HH:mm:ss').format(timestampDate);
            //         String imageUrl = (assessment['images'][0]['url'] ?? '').toString();

            //         return assessmentCard(
            //           context, assessmentId,
            //           title,
            //           formattedDate,
            //           imageUrl,
            //           data, // Convert to string for display or use any DateFormat you want
            //         );
            //       }),
            //     );
            //   },
            // ),

            StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance
      .collection('reba_assessments')
      .where('userId', isEqualTo: userId) // Filter by userId
      .orderBy('timestamp', descending: true) // Sort by latest
      .limit(5) // Limit to 5 latest assessments
      .snapshots(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }

    if (snapshot.hasError) {
      return const Center(child: Text("Error fetching data"));
    }

    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
      return const Center(child: Text("No assessments available"));
    }

    var assessments = snapshot.data!.docs;

    // Apply search filter if needed
    if (searchQuery.isNotEmpty) {
      assessments = assessments.where((doc) {
        var data = doc.data() as Map<String, dynamic>;
        String title = (data['title'] as String?)?.toLowerCase() ?? "";
        return title.contains(searchQuery.toLowerCase());
      }).toList();
    }

    if (assessments.isEmpty) {
      return const Center(
          child: Text("No Matching Assessment",
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w300,
              )));
    }

    return Column(
      children: List.generate(assessments.length, (index) {
        var doc = assessments[index];
        var data = doc.data() as Map<String, dynamic>;

        String assessmentId = doc.id;
        String title = (data['title'] ?? 'Unknown').toString();

        // Convert Firestore timestamp to DateTime
        Timestamp timestamp = data['timestamp'] as Timestamp;
        DateTime timestampDate = timestamp.toDate();
        String formattedDate = DateFormat('dd-MM-yyyy HH:mm:ss').format(timestampDate);

        // String imageUrl = (data['images'] != null && data['images'].isNotEmpty)
        //     ? (data['images'][0]['url'] ?? '').toString()
        //     : '';
        String imageUrl = (data['images'][0]['url'] ?? '').toString();
        return assessmentCard(context, assessmentId, title, formattedDate, imageUrl, data);
      }),
    );
  },
),

              
            ],
          ),
        ),
      ),
    );
  }
 
  // Widget for recap items
Widget recapItem(IconData icon, String title, String subtitle, {required Color iconBackgroundColor, required Color iconColor}) {
  return Expanded(
    child: 
    
    GestureDetector(
      onTap: () {
        widget.onTabChanged(1);
      },
      child: Padding(padding : EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6), // Padding around the icon to create the circle
            decoration: BoxDecoration(
              color: iconBackgroundColor, // Background color (green or yellow)
              shape: BoxShape.circle, // Make it circular
            ),
            child: Icon(icon, size: 16, color: iconColor), // Icon with color
          ),
          SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12, fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: Color.fromRGBO(55, 149, 112, 100))),
                Text(subtitle, style: TextStyle(fontSize: 8, fontFamily: 'Poppins', fontWeight: FontWeight.w300, color: Color.fromRGBO(55, 149, 112, 100))),
              ],
            ),
          ),
        ],
      ),
    
    ),
    ),
  );
}
  // Widget for assessment card

 Widget assessmentCard(BuildContext context, String assessmentId, String title, String timestamp, String imageUrl, Map<String, dynamic> data) { 
  return InkWell(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AssessmentDetailsPage(
            assessmentId: assessmentId,
            data:data,
          ),
        ),
      );
    },
    child: Card(
      margin: EdgeInsets.symmetric(vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // Placeholder for Assessment Image
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                imageUrl,
                width: 50, 
                height: 50, 
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 50,
                  height: 50,
                  color: Colors.grey.shade300,
                  child: Icon(Icons.image_not_supported, color: Colors.grey),
                ),
              ),
            ),
            SizedBox(width: 10),

            // Assessment Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title, 
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Text(
                    "📅 $timestamp",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),

            Align(
              alignment: Alignment.topRight,
              child: Icon(Icons.more_vert, color: Colors.grey),
            ),
          ],
        ),
      ),
    ),
  );
  }
}

