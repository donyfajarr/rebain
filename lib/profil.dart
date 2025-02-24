import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'main.dart'; // Import halaman login

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final User? user = FirebaseAuth.instance.currentUser;
  Map<String, String> deviceInfo = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(() => getDeviceInfo());
  }

  Future<void> getDeviceInfo() async {
    DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
    Map<String, String> info = {};

    try {
      if (Theme.of(context).platform == TargetPlatform.android) {
        AndroidDeviceInfo androidInfo = await deviceInfoPlugin.androidInfo;
        info = {
          "Device": androidInfo.model,
          "Brand": androidInfo.brand,
          "Android Version": androidInfo.version.release,
          // "Hardware": androidInfo.hardware,
        };
        print(info);
      
      }
    } catch (e) {
      info = {"Error": "Failed to get device info"};
    }

    setState(() {
      deviceInfo = info;
    });
  }

  void logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => SignInScreen()),
    );
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: Text("Profile", style:TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 20)), centerTitle: true),
    body: SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 20), // Prevent top overflow

            // Profile Picture
            // Profile Picture with Border
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Color.fromRGBO(55, 149, 112, 1), // Border color
                  width: 2, // Border width
                ),
              ),
              padding: EdgeInsets.all(4), // Optional padding inside the border
              child: CircleAvatar(
                radius: 50,
                backgroundImage: user?.photoURL != null
                    ? NetworkImage(user!.photoURL!)
                    : AssetImage("assets/default_profile.png") as ImageProvider,
              ),
            ),
            SizedBox(height: 16),

            // User Name
            Text(
              user?.displayName ?? "No Name",
              style: TextStyle(fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w600),
            ),

            // Email
            Text(
              user?.email ?? "No Email",
              style: TextStyle(fontFamily: 'Poppins',fontSize: 14, fontWeight: FontWeight.w600, color: Color.fromRGBO(192, 183, 183,1)),
            ),

            SizedBox(height: 20),

            // Device Info Section
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              color: Color.fromRGBO(244, 246, 245, 1),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.info_outline_rounded, ),
                      title: Text("Device Information", style:TextStyle(fontFamily: 'Poppins', fontSize:16, fontWeight: FontWeight.w600)),
                    ),
                    Divider(),
                    deviceInfo == null
                        ? Center(child: CircularProgressIndicator()) // Show loading if null
                        : Column(
                            children: deviceInfo.entries.map(
                              (entry) => ListTile(
                                title: Text(entry.key),
                                subtitle: Text(entry.value),
                              ),
                            ).toList(),

                          ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20), // Instead of Spacer()

            // Logout Button
            ElevatedButton.icon(
              onPressed: logout,
              icon: Icon(Icons.logout, color:Colors.white),
              label: Text("Logout", style:TextStyle(fontFamily: 'Poppins', fontSize:14, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),

            SizedBox(height: 20), // Prevent bottom overflow
          ],
        ),
      ),
    ),
  );
}

}
