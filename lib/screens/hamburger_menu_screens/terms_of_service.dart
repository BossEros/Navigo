import 'package:flutter/material.dart';
import 'package:project_navigo/themes/app_typography.dart';
import 'package:provider/provider.dart'; // Added for ThemeProvider
import 'package:project_navigo/themes/theme_provider.dart'; // Added for ThemeProvider

class TermsOfServiceScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Get the theme provider to check if dark mode is enabled
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      // Apply background color based on theme
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
      appBar: AppBar(
        title: Text(
          "Terms of Service",
          style: AppTypography.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            // Apply text color based on theme
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        // Apply AppBar theming based on dark/light mode
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
        foregroundColor: isDarkMode ? Colors.white : Colors.black,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white : Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          decoration: BoxDecoration(
            // Apply background color based on theme
            color: isDarkMode ? Colors.grey[850] : Colors.grey[50],
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: isDarkMode
                    ? Colors.black.withOpacity(0.3)
                    : Colors.black.withOpacity(0.05),
                blurRadius: 8,
                spreadRadius: 1,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListView(
            padding: const EdgeInsets.all(24.0),
            children: [
              SectionText(
                "Welcome to Navigo. By using our services, you agree to comply with and be bound by these Terms of Service. Please read them carefully. If you do not agree with these Terms, do not use the App.",
                isDarkMode: isDarkMode,
              ),
              SectionTitle("Eligibility", isDarkMode: isDarkMode),
              SectionText(
                "You must be at least 18 years old or have parental consent to use the App. By accessing or using the App, you confirm that you meet these requirements.",
                isDarkMode: isDarkMode,
              ),
              SectionTitle("Account Registration", isDarkMode: isDarkMode),
              SectionText(
                "To access certain features, you may need to create an account. You agree to provide accurate information and keep your account secure. You are responsible for all activities under your account.",
                isDarkMode: isDarkMode,
              ),
              SectionTitle("Use of the App", isDarkMode: isDarkMode),
              SectionText(
                "You agree to use the App only for lawful purposes and in accordance with these Terms. Prohibited activities include:",
                isDarkMode: isDarkMode,
              ),
              SectionText("- Using the App for any unlawful, harmful, or fraudulent activity.", isDarkMode: isDarkMode),
              SectionText("- Interfering with the functionality of the App or accessing it in an unauthorized way.", isDarkMode: isDarkMode),
              SectionTitle("Personalized Routes and Data", isDarkMode: isDarkMode),
              SectionText(
                "The App provides personalized route recommendations based on your travel history and preferences. By using this feature, you consent to the collection and use of your travel data. You can manage or delete your data through the App's settings.",
                isDarkMode: isDarkMode,
              ),
              SectionTitle("Traffic Reports and User-Generated Content", isDarkMode: isDarkMode),
              SectionText("Users may submit traffic reports to enhance the accuracy of the App. You agree that:", isDarkMode: isDarkMode),
              SectionText("- Your reports are accurate to the best of your knowledge.", isDarkMode: isDarkMode),
              SectionText("- The App may use, modify, and share your reports.", isDarkMode: isDarkMode),
              SectionText("- You will not submit harmful, misleading, or offensive content.", isDarkMode: isDarkMode),
              SectionTitle("Privacy Policy", isDarkMode: isDarkMode),
              SectionText(
                "Our use of your personal information is governed by our [Privacy Policy], which is incorporated into these Terms.",
                isDarkMode: isDarkMode,
              ),
              SectionTitle("Intellectual Property", isDarkMode: isDarkMode),
              SectionText(
                "All content, features, and functionality of the App (including software, text, images, and design) are owned by NaviGo or its licensors and are protected by intellectual property laws. You may not copy, distribute, or modify any part of the App without our permission.",
                isDarkMode: isDarkMode,
              ),
              SectionTitle("Disclaimer of Warranties", isDarkMode: isDarkMode),
              SectionText(
                "The App is provided on an 'as is' and 'as available' basis. We make no guarantees about the accuracy, reliability, or availability of the App and its services.",
                isDarkMode: isDarkMode,
              ),
              SectionTitle("Limitation of Liability", isDarkMode: isDarkMode),
              SectionText(
                "To the fullest extent permitted by law, NaviGo shall not be liable for any damages arising from your use of the App, including but not limited to direct, indirect, incidental, or consequential damages.",
                isDarkMode: isDarkMode,
              ),
              SectionTitle("Termination", isDarkMode: isDarkMode),
              SectionText(
                "We reserve the right to suspend or terminate your access to the App at our discretion, without prior notice, if you violate these Terms or engage in prohibited activities.",
                isDarkMode: isDarkMode,
              ),
              SectionTitle("Changes to the Terms", isDarkMode: isDarkMode),
              SectionText(
                "We may update these Terms from time to time. Any changes will be effective immediately upon posting. Your continued use of the App constitutes acceptance of the revised Terms.",
                isDarkMode: isDarkMode,
              ),
              SectionTitle("Governing Law", isDarkMode: isDarkMode),
              SectionText(
                "These Terms are governed by the laws of the Republic of the Philippines, without regard to its conflict of law provisions.",
                isDarkMode: isDarkMode,
              ),
              SectionTitle("Contact Us", isDarkMode: isDarkMode),
              SectionText(
                "If you have questions or concerns about these Terms, please contact us at navigosupport@gmail.com.",
                isDarkMode: isDarkMode,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom Widgets for Titles & Text, using AppTypography with dark mode support
class SectionTitle extends StatelessWidget {
  final String text;
  final bool isDarkMode;

  const SectionTitle(this.text, {Key? key, required this.isDarkMode}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 12.0),
      child: Text(
        text,
        style: AppTypography.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
          // Apply text color based on theme
          color: isDarkMode ? Colors.white : Colors.black87,
        ),
      ),
    );
  }
}

class SectionText extends StatelessWidget {
  final String text;
  final bool isDarkMode;

  const SectionText(this.text, {Key? key, required this.isDarkMode}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        text,
        style: AppTypography.textTheme.bodyLarge?.copyWith(
          height: 1.5,  // Improved line height for readability
          // Apply text color based on theme
          color: isDarkMode ? Colors.white.withOpacity(0.9) : Colors.black87,
        ),
      ),
    );
  }
}