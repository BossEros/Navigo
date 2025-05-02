// lib/widgets/report_panel.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:project_navigo/models/map_models/report_type.dart';
import 'package:project_navigo/services/report_service.dart';
import 'package:project_navigo/themes/app_typography.dart';
import 'package:project_navigo/themes/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:project_navigo/themes/theme_provider.dart';

import '../screens/authentication/login_screen.dart';

class ReportPanel extends StatefulWidget {
  final LatLng currentLocation;
  final Function(String reportTypeId)? onReportSubmitted;
  final Function()? onClose;

  const ReportPanel({
    Key? key,
    required this.currentLocation,
    this.onReportSubmitted,
    this.onClose,
  }) : super(key: key);

  @override
  State<ReportPanel> createState() => _ReportPanelState();
}

class _ReportPanelState extends State<ReportPanel> {
  final ReportService _reportService = ReportService();
  bool _isSubmitting = false;
  String? _selectedReportId;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    // Get the theme provider to check for dark mode
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          // Theme-aware background color
          color: isDarkMode ?
          AppTheme.darkTheme.dialogBackgroundColor :
          Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'What do you see?',
                style: AppTypography.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ),

            // Error message (if any)
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _errorMessage!,
                  style: AppTypography.textTheme.bodyMedium?.copyWith(
                    color: Colors.red,
                  ),
                ),
              ),

            // Grid of report options
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.9,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 16,
                ),
                itemCount: ReportTypes.allTypes.length,
                itemBuilder: (context, index) {
                  final reportType = ReportTypes.allTypes[index];
                  final isSelected = _selectedReportId == reportType.id;

                  return _buildReportTypeItem(
                    reportType: reportType,
                    isSelected: isSelected,
                    isDarkMode: isDarkMode,
                  );
                },
              ),
            ),

            // Submit button
            if (_selectedReportId != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : Text(
                    'Submit Report',
                    style: AppTypography.textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            // Always show "Close" when no report is selected
            if (_selectedReportId == null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: widget.onClose,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: Text(
                    'Close',
                    style: AppTypography.textTheme.labelLarge,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportTypeItem({
    required ReportType reportType,
    required bool isSelected,
    required bool isDarkMode,
  }) {
    return GestureDetector(
      onTap: () => setState(() {
        _selectedReportId = reportType.id;
      }),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Circular icon background
          Container(
            width: 70, // Slightly smaller container
            height: 70,
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Color.lerp(Colors.grey[800], reportType.color, isSelected ? 0.3 : 0.05)
                  : Color.lerp(Colors.grey[200], reportType.color, isSelected ? 0.3 : 0.05),
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: reportType.color, width: 2)
                  : null,
            ),
            child: Center(
              child: reportType.imagePath != null
                  ? Image.asset(
                reportType.imagePath!,
                width: 50, // Set custom image size to 24px
                height: 50, // Set custom image size to 24px
              )
                  : Icon(
                reportType.icon ?? Icons.error,
                size: 50, // Set icon size to 24px
              ),
            ),
          ),

          // Label remains the same
          const SizedBox(height: 8),
          Text(
            reportType.label,
            style: AppTypography.textTheme.bodyMedium?.copyWith(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isDarkMode
                  ? (isSelected ? Colors.white : Colors.white.withOpacity(0.8))
                  : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _submitReport() async {
    if (_selectedReportId == null) return;

    // Explicitly hide keyboard before processing submission
    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      // Check if user is logged in first (to show a better error message)
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _errorMessage = "You need to be logged in to submit reports";
          _isSubmitting = false;
        });

        // Show login prompt
        _showLoginPrompt(context);
        return;
      }

      // Submit the report
      await _reportService.submitReport(
        reportTypeId: _selectedReportId!,
        location: widget.currentLocation,
      );

      // Safety check to ensure the widget is still mounted
      if (!mounted) return;

      // Notify parent widget of submission - do this before closing to ensure proper handling
      if (widget.onReportSubmitted != null) {
        widget.onReportSubmitted!(_selectedReportId!);
      }

      // Close the panel - make sure we're using the correct Navigator context
      Navigator.of(context).pop();

    } catch (e) {
      // Make sure we only update state if still mounted
      if (mounted) {
        setState(() {
          // Extract meaningful message
          if (e.toString().contains("permission")) {
            _errorMessage = 'Permission denied: You need proper access to submit reports.';
          } else {
            _errorMessage = 'Failed to submit report: ${e.toString().replaceAll("Exception: ", "")}';
          }
        });
      }
    } finally {
      // Make sure we only update state if still mounted
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showLoginPrompt(BuildContext context) {
    // Get theme state
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
        title: Text(
          'Login Required',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        content: Text(
          'You need to be logged in to submit reports. Would you like to log in now?',
          style: TextStyle(
            color: isDarkMode ? Colors.white.withOpacity(0.9) : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => LoginScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: Text('Log In'),
          ),
        ],
      ),
    );
  }
}