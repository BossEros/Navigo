import 'package:flutter/material.dart';

void main() {
  runApp(NavigoApp());
}

class NavigoApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ProfileScreen(),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Shortened blue header with username and profile pic
          Container(
            height: 200, // Reduced height for shorter gradient
            width: double.infinity, // Ensure full width
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // Blue curved background - no left/right padding to reach edges
                Positioned.fill(
                  child: ClipPath(
                    clipper: HeaderClipper(),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.lightBlue.shade300, Colors.blue],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  ),
                ),
                // Back button (left arrow)
                Positioned(
                  top: 40,
                  left: 20,
                  child: IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.black, size: 28),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ),
                // Username text positioned above profile picture
                Positioned(
                  top: 80, // Adjusted for shorter gradient
                  child: Text(
                    'janedoe',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                // Profile picture - positioned to overlap the curved edge by 50%
                Positioned(
                  bottom: -60, // This makes it overlap by 50%
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.white,
                    backgroundImage: AssetImage('assets/profile.jpg'),
                  ),
                ),
              ],
            ),
          ),

          // Space to account for the overlapping profile picture
          SizedBox(height: 70),

          // Profile details list
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: 20),
              children: [
                buildProfileItem(
                  'assets/icons/user_id.png',
                  'Username',
                  'janedoe',
                ),
                Divider(height: 1),
                buildProfileItem(
                  'assets/icons/email.png',
                  'Email',
                  'janedoe202024@gmail.com',
                ),
                Divider(height: 1),
                buildProfileItem(
                  'assets/icons/home.png',
                  'Home Address',
                  'Cebu N Rd, Consolacion, Cebu',
                ),
                Divider(height: 1),
                buildProfileItem(
                  'assets/icons/work.png',
                  'Work Address',
                  'Set up Work Address',
                ),
                Divider(height: 1),
                buildProfileItem(
                  'assets/icons/connected.png',
                  'Connected Accounts',
                  '',
                ),
              ],
            ),
          ),

          // Edit button
          Padding(
            padding: EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: () {
                    // Changed navigation to redirect to AccountLoginPage instead
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AccountLoginPage(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  ),
                  child: Text(
                    'Edit',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Bottom space to account for navigation bar or home indicator
          SizedBox(height: 10),
        ],
      ),
    );
  }

  // Custom widget for profile items with custom icons
  Widget buildProfileItem(String iconAsset, String title, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Since the design appears to use custom icons, we'll use Image instead of Icon
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: getIconForTitle(title),
          ),
          SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 14, color: Colors.grey)),
                SizedBox(height: 4),
                Text(
                  value.isEmpty ? ' ' : value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to get the appropriate icon for each profile item
  Widget getIconForTitle(String title) {
    // You should replace these with custom icons that match the design
    switch (title) {
      case 'Username':
        return Icon(Icons.badge, size: 24, color: Colors.black);
      case 'Email':
        return Icon(Icons.email, size: 24, color: Colors.black);
      case 'Home Address':
        return Icon(Icons.home, size: 24, color: Colors.black);
      case 'Work Address':
        return Icon(Icons.work, size: 24, color: Colors.black);
      case 'Connected Accounts':
        return Icon(Icons.people, size: 24, color: Colors.black);
      default:
        return Icon(Icons.circle, size: 24, color: Colors.black);
    }
  }
}

// New Account and Login Page based on the provided image
class AccountLoginPage extends StatefulWidget {
  @override
  _AccountLoginPageState createState() => _AccountLoginPageState();
}

class _AccountLoginPageState extends State<AccountLoginPage> {
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Method to show the deactivation confirmation dialog
  void _showDeactivateConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Warning icon
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.amber,
                  size: 60,
                ),
                SizedBox(height: 20),
                // Warning text
                Text(
                  'Are you sure you want to deactivate your account?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 24),
                // Buttons row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Cancel button
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.grey[300],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    // Deactivate button
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          // Close the dialog
                          Navigator.of(context).pop();
                          // Navigate to the deactivated account page
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DeactivatedAccountPage(),
                            ),
                          );
                        },
                        child: Text(
                          'Deactivate',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // NEW METHOD: Show delete account confirmation dialog
  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Warning icon
                Icon(Icons.error, color: Colors.red, size: 60),
                SizedBox(height: 20),
                // Warning text
                Text(
                  'Are you sure you want to delete your account?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text(
                  'This action can\'t be undone!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
                SizedBox(height: 24),
                // Buttons row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Cancel button
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.grey[300],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    // Delete button
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          // Close the dialog
                          Navigator.of(context).pop();
                          // Navigate to the deleted account page
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DeletedAccountPage(),
                            ),
                          );
                        },
                        child: Text(
                          'Delete account',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(70),
        child: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.black, size: 24),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.only(top: 12.0),
          ),
          title: Padding(
            padding: EdgeInsets.only(top: 12.0),
            child: Text(
              'Account and Login',
              style: TextStyle(
                color: Colors.black,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          actions: [
            Padding(
              padding: EdgeInsets.only(top: 12.0, right: 8.0),
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.black, size: 24),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
          centerTitle: true,
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Edit Login Info Section
              Text(
                'Edit Login Info',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 16),

              // Username Field - REDUCED HEIGHT
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ), // Reduced vertical padding
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Username',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2), // Reduced spacing
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'janedoe123',
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        isDense: true, // Makes the TextField more compact
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 8,
                        ), // Reduced padding
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12), // Reduced spacing between fields
              // Email Field - REDUCED HEIGHT
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ), // Reduced vertical padding
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Email',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2), // Reduced spacing
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'janedoe202024@gmail.com',
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        isDense: true, // Makes the TextField more compact
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 8,
                        ), // Reduced padding
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12), // Reduced spacing between fields
              // Password Field - REDUCED HEIGHT
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ), // Reduced vertical padding
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Password',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2), // Reduced spacing
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              hintText: '***************',
                              border: InputBorder.none,
                              hintStyle: TextStyle(color: Colors.grey[500]),
                              isDense: true, // Makes the TextField more compact
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 8,
                              ), // Reduced padding
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: Colors.grey[600],
                            size: 22, // Slightly smaller icon
                          ),
                          padding: EdgeInsets.all(0), // Reduced padding
                          constraints:
                              BoxConstraints(), // Minimizes constraints
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12), // Reduced spacing between fields
              // Confirm Password Field - REDUCED HEIGHT
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ), // Reduced vertical padding
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Confirm Password',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2), // Reduced spacing
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            obscureText: _obscureConfirmPassword,
                            decoration: InputDecoration(
                              hintText: '***************',
                              border: InputBorder.none,
                              hintStyle: TextStyle(color: Colors.grey[500]),
                              isDense: true, // Makes the TextField more compact
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 8,
                              ), // Reduced padding
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: Colors.grey[600],
                            size: 22, // Slightly smaller icon
                          ),
                          padding: EdgeInsets.all(0), // Reduced padding
                          constraints:
                              BoxConstraints(), // Minimizes constraints
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24), // Slightly reduced spacing
              // Account Deletion Section
              Text(
                'Account Deletion',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 12), // Reduced spacing
              // Deactivate Account Button - Modified to show dialog
              GestureDetector(
                onTap: _showDeactivateConfirmationDialog,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ), // Reduced vertical padding
                  child: Center(
                    // Centering the text
                    child: Text(
                      'Deactivate Account',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 12),
              // Reduced spacing
              // Delete Account Button - Modified to show delete confirmation dialog
              GestureDetector(
                onTap: _showDeleteConfirmationDialog,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.red[400],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ), // Reduced vertical padding
                  child: Text(
                    'Delete Account',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              SizedBox(height: 32), // Slightly reduced spacing
              // Save Changes Button
              Container(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[500],
                    padding: EdgeInsets.symmetric(
                      vertical: 12,
                    ), // Slightly reduced height
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Save Changes',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16), // Reduced bottom spacing
            ],
          ),
        ),
      ),
    );
  }
}

// New Page for Deleted Account (displayed after confirming account deletion)
class DeletedAccountPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Account Deleted', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
        centerTitle: true,
        automaticallyImplyLeading: false, // Remove back button
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline, size: 80, color: Colors.red),
              SizedBox(height: 30),
              Text(
                'Your Account Has Been Deleted',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              Text(
                'Your account has been permanently deleted. All your data has been removed from our servers.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              SizedBox(height: 40),
              Container(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Navigate back to the main screen or login screen
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Back to Login',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Deactivated Account Page - keeping for existing functionality
class DeactivatedAccountPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Account Deactivated',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
              SizedBox(height: 30),
              Text(
                'Your Account Has Been Deactivated',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              Text(
                'Your account has been successfully deactivated. You will be logged out automatically.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              SizedBox(height: 40),
              Container(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Navigate back to the main screen or login screen
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Back to Login',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Original Edit Profile Page (keeping for reference)
class EditProfilePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Edit Profile'), backgroundColor: Colors.blue),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Edit Profile Page',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              Text('Here you can edit your profile information'),
              SizedBox(height: 40),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text('Back to Profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 40);
    path.quadraticBezierTo(
      size.width / 2,
      size.height + 20,
      size.width,
      size.height - 40,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class EmptyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('New Page'), backgroundColor: Colors.blue),
      body: Center(child: Text('This is an empty page')),
    );
  }
}
