import 'package:flutter/material.dart';
import 'profile.dart';
import 'settings.dart';

void main() {
  runApp(NavigoApp());
}

/// Main application widget
class NavigoApp extends StatelessWidget {
  const NavigoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Hamburgmenu(), // Starts the app on the ProfileScreen
    );
  }
}

/// Profile screen that displays user info and menu options
class Hamburgmenu extends StatelessWidget {
  const Hamburgmenu({super.key});

  /// Function to navigate to a new page
  void navigateTo(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Set background color to white
      body: Column(
        children: [
          /// Header container with a gradient background
          SizedBox(
            height: 220,
            child: Stack(
              children: [
                // Curved blue background
                ClipPath(
                  clipper: HeaderClipper(),
                  child: Container(
                    height: 180,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue, Colors.blue.shade300],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
                // Close button
                Positioned(
                  top: 40,
                  right: 20,
                  child: IconButton(
                    icon: Icon(Icons.close, color: Colors.black, size: 28),
                    onPressed: () {
                      navigateTo(context, EmptyPage());
                    },
                  ),
                ),
                // Profile picture
                Align(
                  alignment: Alignment.center,
                  child: Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.white,
                      backgroundImage: AssetImage('assets/profile.jpg'),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Username and email
          Text(
            'janedoe',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'janedoe202024@gmail.com',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          SizedBox(height: 30),

          /// Menu List with clickable options
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: 20),
              children: [
                buildListTile(
                  Icons.person,
                  'View Profile',
                  context,
                  ProfileScreen(),
                ),
                Divider(height: 1),
                buildListTile(
                  Icons.star_border,
                  'Saved Maps',
                  context,
                  EmptyPage(),
                ),
                Divider(height: 1),
                buildListTile(
                  Icons.map_outlined,
                  'Your Route Data',
                  context,
                  EmptyPage(),
                ),
                Divider(height: 1),
                buildListTile(
                  Icons.settings,
                  'Settings',
                  context,
                  SettingsPage(),
                ),
                Divider(height: 1),
                buildListTile(Icons.logout, 'Log out', context, EmptyPage()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Function to build each menu option as a clickable list tile
  Widget buildListTile(
    IconData icon,
    String title,
    BuildContext context,
    Widget page,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      leading: Icon(icon, size: 24, color: Colors.black),
      title: Text(
        title,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      trailing: Icon(Icons.chevron_right, color: Colors.grey),
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => page));
      },
    );
  }
}

/// Empty page to act as a placeholder for navigation
class EmptyPage extends StatelessWidget {
  const EmptyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('New Page'), backgroundColor: Colors.blue),
      body: Center(child: Text('This is an empty page')),
    );
  }
}

/// Custom Clipper for Curved Gradient Background
class HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 30);
    path.quadraticBezierTo(
      size.width / 2,
      size.height + 20,
      size.width,
      size.height - 30,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
