import 'package:intl/intl.dart';

class FormatUtils {
  /// Format distance for display
  static String formatDistance(int meters) {
    if (meters < 1000) {
      return '$meters m';
    } else {
      final km = meters / 1000.0;
      return '${km.toStringAsFixed(1)} km';
    }
  }

  /// Format time for ETA display
  static String formatEta(DateTime time) {
    return DateFormat('HH:mm').format(time);
  }

  /// Format duration from seconds
  static String formatDuration(int seconds) {
    if (seconds < 60) {
      return '$seconds sec';
    } else if (seconds < 3600) {
      int minutes = seconds ~/ 60;
      return '$minutes min';
    } else {
      int hours = seconds ~/ 3600;
      int minutes = (seconds % 3600) ~/ 60;
      return '$hours h $minutes min';
    }
  }

  /// Format date for display in history or saved locations
  static String formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final dateToCheck = DateTime(date.year, date.month, date.day);

    if (dateToCheck == today) {
      return 'Today ${DateFormat('h:mm a').format(date)}';
    } else if (dateToCheck == yesterday) {
      return 'Yesterday ${DateFormat('h:mm a').format(date)}';
    } else {
      return DateFormat('MMM d, y \'at\' h:mm a').format(date);
    }
  }

  /// Clean HTML from instruction text
  static String cleanInstruction(String instruction) {
    // Remove HTML tags
    String cleaned = instruction.replaceAll(RegExp(r'<[^>]*>'), '');

    // Simplify common phrases
    cleaned = cleaned
        .replaceAll('Proceed to', 'Go to')
        .replaceAll('Continue onto', 'Continue on');

    return cleaned;
  }

  /// Extract road name from navigation instruction
  static String extractRoadName(String instruction) {
    // Simple algorithm to extract road names from instructions
    if (instruction.contains(" onto ")) {
      return instruction.split(" onto ")[1].split("<")[0].trim();
    }
    if (instruction.contains(" on ")) {
      return instruction.split(" on ")[1].split("<")[0].trim();
    }
    return instruction.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }
}