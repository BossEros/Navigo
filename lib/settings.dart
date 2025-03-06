import 'package:flutter/material.dart';
import 'faq_screen.dart';
import 'terms_of_service.dart';
import 'profile.dart';

void main() {
  runApp(NaviGoApp());
}

class NaviGoApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NaviGo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: SettingsPage(),
    );
  }
}

// This class defines the main settings page with navigation options to different sections, including Privacy Policy.
// This class defines the main settings page with navigation options to different sections, including Privacy Policy.
class SettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.only(left: 20.0),
        child: Column(
          children: [
            ListTile(
              title: Text("Accessibility"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AccessibilityPage()),
                );
              },
            ),
            ListTile(
              title: Text("Profile Details"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProfileScreen()),
                );
              },
            ),
            ListTile(
              title: Text("FAQ"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => FAQScreen()),
                );
              },
            ),
            ListTile(
              title: Text("Terms of Service"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TermsOfServiceScreen(),
                  ),
                );
              },
            ),
            ListTile(
              title: Text("Privacy Policy"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PrivacyPolicyPage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Accessibility Settings Page
class AccessibilityPage extends StatefulWidget {
  @override
  _AccessibilityPageState createState() => _AccessibilityPageState();
}

class _AccessibilityPageState extends State<AccessibilityPage> {
  bool isDarkMode = false;
  bool isLargeFont = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'Accessibility',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      body: Padding(
        padding: EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Font Size',
                  style: TextStyle(
                    fontSize: isLargeFont ? 24 : 16,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      isLargeFont = !isLargeFont;
                    });
                  },
                  child: Text(
                    isLargeFont ? 'Huge' : 'Normal',
                    style: TextStyle(
                      fontSize: isLargeFont ? 24 : 16,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ],
            ),
            Divider(color: isDarkMode ? Colors.white : Colors.black),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Dark Mode',
                  style: TextStyle(
                    fontSize: isLargeFont ? 24 : 16,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                Checkbox(
                  value: isDarkMode,
                  onChanged: (bool? value) {
                    setState(() {
                      isDarkMode = value!;
                    });
                  },
                ),
              ],
            ),
            Divider(color: isDarkMode ? Colors.white : Colors.black),
          ],
        ),
      ),
    );
  }
}

// This class handles the Privacy Policy page, including displaying terms and ensuring scroll functionality.
class PrivacyPolicyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: // Text widgets define the content of the Privacy Policy, including headings, descriptions, and data collection details.
            Text(
          'Privacy Policy',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: // This ensures that the Privacy Policy content is scrollable, preventing overflow on smaller screens.
          SingleChildScrollView(
        padding: EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Privacy Policy",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "Effective Date: December 5, 2024",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "At NaviGo, your privacy is important to us. This Privacy Policy outlines how we collect, use, and protect your personal information when you use our app and services. By using the app, you agree to the terms of this policy.",
            ),
            SizedBox(height: 20),
            Text(
              "1. Information We Collect",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            //SizedBox(height: 10),
            Text(
              "We collect information to provide and improve our services. This includes: ",
            ),
            SizedBox(height: 10),
            Text(
              "a. Information You Provide",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              "- Account Information: Name, email address, and any other details you provide during registration.",
            ),
            Text(
              "- Reports and Feedback: Information submitted through traffic reports or feedback forms.",
            ),
            SizedBox(height: 10),
            Text(
              "b. Automatically Collected Information",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              "- Location Data: Real-time GPS location to generate personalized routes and traffic updates.",
            ),
            Text(
              "- Usage Data: Information about how you use the app, including clicks, routes generated, and time spent.",
            ),
            Text(
              "- Device Information: Details about your device such as model, operating system, and app version.",
            ),
            SizedBox(height: 10),
            Text(
              "c. Cookies and Tracking Technologies",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              "We use cookies and similar technologies to enhance your expercience and gather analytics data.",
            ),
            SizedBox(height: 20),
            Text("---"),
            SizedBox(height: 10),
            Text(
              "2. How We Use Your Information",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text("We use the information collected for purposes such as: "),
            SizedBox(height: 10),
            Text(
              "- Providing Services: Generating routes, real-time traffic updates, and personalized recommendations.",
            ),
            Text(
              "- Improving the App: Analyzing usage patterns to enhance features and performance.",
            ),
            Text(
              "- Communiton: Sending notifications, updates, and responding to feedback.",
            ),
            Text(
              "- Saftey and Security: Detecting and preventing fraudalent and unauthorized activities.",
            ),
            SizedBox(height: 20),
            Text("---"),
            SizedBox(height: 10),
            Text(
              "3. Sharing Your Information",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text("We do not sell your information. We may share information: "),
            SizedBox(height: 10),
            Text(
              "- With Service Providers: Third-party services that help us operate the application (e.g., hosting, analytics).",
            ),
            Text(
              "- For Legal Reasons: If required by law or to protect rights, safety, and property.",
            ),
            Text(
              "- With Your Consent: When you explicitly agree to share your information for specific purposes.",
            ),
            SizedBox(height: 20),
            Text("---"),
            SizedBox(height: 10),
            Text(
              "4. Data Security",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              "We implement industry-standard security measures to protect your information from unauthorized access, loss, or misuse. However, no system is completely secure, and we cannot guarantee absolute security.",
            ),
            SizedBox(height: 20),
            Text("---"),
            SizedBox(height: 10),
            Text(
              "5. Your Rights and Choices",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text("You have the right to: "),
            SizedBox(height: 10),
            Text(
              "- Access and Update: View and update your personal information through your account settings.",
            ),
            Text(
              "- Delete Data: Request deletion of your account and associated data.",
            ),
            Text(
              "- Opt-Out: Disable location tracking or notification through your device settings.",
            ),
            SizedBox(height: 20),
            Text("---"),
            SizedBox(height: 10),
            Text(
              "6. Data Retention",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              "We retain your data only as long as necessary to provide services or comply with legal obligations. Once data is no longer needed, we securely delete or anonymize it.",
            ),
            SizedBox(height: 20),
            Text("---"),
            SizedBox(height: 10),
            Text(
              "7. Children's Privacy",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              "Our services are not intended for children under 13. We do not knowingly collect personal information from children. If you believe a child has provided us with information, please contact us to remove it.",
            ),
            SizedBox(height: 20),
            Text("---"),
            SizedBox(height: 10),
            Text(
              "8. Changes to This Policy",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              "We may update this Privacy Policy from time to time. Any changes will be posted within the application, and your continued use of the application signifies acceptance of the updated terms.",
            ),
            SizedBox(height: 20),
            Text("---"),
            SizedBox(height: 10),
            Text(
              "9. Contact Us",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              "If you have questions or concerns about this Privacy Policy or how we handle your data, please contact us at: ",
            ),
            SizedBox(height: 10),
            Text(
              "Email: support@navigo.com",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              "Address: navigosupport@gmail.com",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
