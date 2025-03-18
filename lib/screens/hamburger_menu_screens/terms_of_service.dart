import 'package:flutter/material.dart';

class TermsOfServiceScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Terms of Service",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true, // Ensure title is centered
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey[200], // Light gray background
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: const [
              SectionText(
                  "Welcome to Navigo. By using our services, you agree to comply with and be bound by these Terms of Service. Please read them carefully. If you do not agree with these Terms, do not use the App."),
              SectionTitle("Eligibility"),
              SectionText(
                  "You must be at least 18 years old or have parental consent to use the App. By accessing or using the App, you confirm that you meet these requirements."),
              SectionTitle("Account Registration"),
              SectionText(
                  "To access certain features, you may need to create an account. You agree to provide accurate information and keep your account secure. You are responsible for all activities under your account."),
              SectionTitle("Use of the App"),
              SectionText(
                  "You agree to use the App only for lawful purposes and in accordance with these Terms. Prohibited activities include:"),
              SectionText("- Using the App for any unlawful, harmful, or fraudulent activity."),
              SectionText("- Interfering with the functionality of the App or accessing it in an unauthorized way."),
              SectionTitle("Personalized Routes and Data"),
              SectionText(
                  "The App provides personalized route recommendations based on your travel history and preferences. By using this feature, you consent to the collection and use of your travel data. You can manage or delete your data through the App’s settings."),
              SectionTitle("Traffic Reports and User-Generated Content"),
              SectionText("Users may submit traffic reports to enhance the accuracy of the App. You agree that:"),
              SectionText("- Your reports are accurate to the best of your knowledge."),
              SectionText("- The App may use, modify, and share your reports."),
              SectionText("- You will not submit harmful, misleading, or offensive content."),
              SectionTitle("Privacy Policy"),
              SectionText(
                  "Our use of your personal information is governed by our [Privacy Policy], which is incorporated into these Terms."),
              SectionTitle("Intellectual Property"),
              SectionText(
                  "All content, features, and functionality of the App (including software, text, images, and design) are owned by NaviGo or its licensors and are protected by intellectual property laws. You may not copy, distribute, or modify any part of the App without our permission."),
              SectionTitle("Disclaimer of Warranties"),
              SectionText(
                  "The App is provided on an 'as is' and 'as available' basis. We make no guarantees about the accuracy, reliability, or availability of the App and its services."),
              SectionTitle("Limitation of Liability"),
              SectionText(
                  "To the fullest extent permitted by law, NaviGo shall not be liable for any damages arising from your use of the App, including but not limited to direct, indirect, incidental, or consequential damages."),
              SectionTitle("Termination"),
              SectionText(
                  "We reserve the right to suspend or terminate your access to the App at our discretion, without prior notice, if you violate these Terms or engage in prohibited activities."),
              SectionTitle("Changes to the Terms"),
              SectionText(
                  "We may update these Terms from time to time. Any changes will be effective immediately upon posting. Your continued use of the App constitutes acceptance of the revised Terms."),
              SectionTitle("Governing Law"),
              SectionText(
                  "These Terms are governed by the laws of the Republic of the Philippines, without regard to its conflict of law provisions."),
              SectionTitle("Contact Us"),
              SectionText(
                  "If you have questions or concerns about these Terms, please contact us at navigosupport@gmail.com."),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom Widgets for Titles & Text
class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12.0, bottom: 4.0),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
    );
  }
}

class SectionText extends StatelessWidget {
  final String text;
  const SectionText(this.text, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16),
      ),
    );
  }
}
