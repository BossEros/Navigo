import 'package:flutter/material.dart';
import 'package:project_navigo/themes/app_typography.dart'; // Import typography

class FAQScreen extends StatefulWidget {
  @override
  _FAQScreenState createState() => _FAQScreenState();
}

class _FAQScreenState extends State<FAQScreen> {
  Map<String, List<Map<String, String>>> faqData = {
    "General Usage": [
      {"How do I plan a route?": "Open the app, tap the search bar, and enter your starting point and destination. You can then choose your mode of transportation and view the best and alternative routes."},
      {"How does real-time traffic work?": "The app collects data from GPS signals, traffic sensors, and user reports to provide live updates on road conditions. This information is updated frequently to reflect current traffic patterns."},
      {"Can I customize my routes?": "Yes! After selecting a route, tap the options icon to avoid tolls, highways, or ferries. You can also drag the route to adjust it manually."},
      {"How do I save a route or map?": "Tap the star icon next to the route or map after generating it. Saved routes can be accessed in the 'My Routes' section of the app."},
    ],
    "Traffic Reporting and Alerts": [
      {"How do I report a traffic issue?": "Tap the 'Report' button on the map screen and choose from options like accident, road closure, or hazard. Add a brief description if needed, then submit."},
      {"What types of traffic alerts will I receive?": "You'll get alerts for accidents, road closures, heavy congestion, and any reported hazards. You can customize these in the app settings."},
      {"Can I turn off traffic alerts?": "Yes. Go to Settings > Notifications and toggle off traffic alerts. You can also choose which types of alerts you want to receive."},
    ],
    "Personalization and Data": [
      {"What is personalized route generation?": "The app analyzes your travel habits, preferred routes, and past trips to suggest routes tailored to your preferences, helping you save time and avoid unnecessary detours."},
      {"How do I delete my personalized traffic data?": "Go to Settings > Privacy > Delete Traffic Data and confirm. Keep in mind that deleting this data will result in routes based on general traffic patterns."},
      {"How is my data used and protected?": "Your data is used only to enhance your navigation experience. It is stored securely and never shared with third parties without your consent."},
    ],
    "Navigation Features": [
      {"Can I view alternate routes?": "Yes. After generating a route, swipe up to view alternative routes. You can compare estimated travel times and traffic conditions before selecting your preferred option."},
      {"How do I change my mode of transportation?": "Tap the mode icon (car, bike, walk) on the route planning screen and select your desired option. The app will adjust the route accordingly."},
      {"What happens if I lose internet connection?": "The app will switch to offline mode if you've downloaded offline maps. If not, you may experience limited functionality until the connection is restored."},
    ],
    "Account and Technical Support": [
      {"How do I reset my password?": "Tap Forgot Password on the login screen and follow the prompts to reset your password via email."},
      {"How can I contact support?": "You can contact our support team by tapping Help & Feedback in the app menu or emailing us at support@example.com."},
      {"How do I update or delete my account?": "Go to Settings > Account to update your details or delete your account. Deleting your account will remove all data permanently."},
    ],
  };

  Map<String, bool> expandedCategories = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Frequently Asked Questions",
          style: AppTypography.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: faqData.keys.map((category) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category header with improved styling
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    category,
                    style: AppTypography.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  trailing: Icon(
                    expandedCategories[category] == true ? Icons.remove_circle_outline : Icons.add_circle_outline,
                    color: Colors.blue,
                  ),
                  onTap: () {
                    setState(() {
                      expandedCategories[category] = !(expandedCategories[category] ?? false);
                    });
                  },
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              // Questions list with animation
              AnimatedCrossFade(
                firstChild: Container(height: 0),
                secondChild: Column(
                  children: faqData[category]!.map((faq) {
                    String question = faq.keys.first;
                    String answer = faq[question]!;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.05),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: ListTile(
                        title: Text(
                          question,
                          style: AppTypography.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        onTap: () => _showAnswerDialog(context, question, answer),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      ),
                    );
                  }).toList(),
                ),
                crossFadeState: expandedCategories[category] == true
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 300),
              ),

              const SizedBox(height: 16),
            ],
          );
        }).toList(),
      ),
    );
  }

  void _showAnswerDialog(BuildContext context, String question, String answer) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            question,
            style: AppTypography.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          content: SingleChildScrollView(
            child: Text(
              answer,
              style: AppTypography.textTheme.bodyMedium,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Close",
                style: AppTypography.textTheme.labelLarge?.copyWith(
                  color: Colors.blue,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}