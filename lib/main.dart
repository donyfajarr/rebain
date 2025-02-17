import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';


// import 'splash_screen.dart';
import 'input.dart'; // Import your input.dart file
import 'create.dart'; // Ensure form.dart contains SimpleForm
import 'package:firebase_core/firebase_core.dart';
import 'list.dart';

import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:flutter_dotenv/flutter_dotenv.dart';

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

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Welcome to MoveNet App'),
      ),
      body: Center(
        child: Column(
          // Use Column to stack widgets vertically
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                // Navigate to ImagePickerScreen
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ImagePickerScreen()),
                );
              },
              child: Text('Go to Image Picker'),
            ),
            SizedBox(height: 20), // Space between the buttons

            ElevatedButton(
              onPressed: () {
                // Navigate to SimpleForm
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AssessmentListPage()),
                );
              },
              child: Text('Go to Details'),
            ),
          ],
        ),
      ),
    );
  }
}
