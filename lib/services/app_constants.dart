import 'package:flutter/material.dart';

// Location category definitions used across the app
final Map<String, Map<String, dynamic>> locationCategories = {
  'favorite': {
    'displayName': 'Favorites',
    'icon': Icons.favorite,
    'color': Colors.red,
  },
  'food': {
    'displayName': 'Food & Dining',
    'icon': Icons.restaurant,
    'color': Colors.orange,
  },
  'shopping': {
    'displayName': 'Shopping',
    'icon': Icons.shopping_bag,
    'color': Colors.lightBlue,
  },
  'entertainment': {
    'displayName': 'Entertainment',
    'icon': Icons.movie,
    'color': Colors.purple,
  },
  'services': {
    'displayName': 'Services',
    'icon': Icons.business,
    'color': Colors.teal,
  },
  'other': {
    'displayName': 'Other Places',
    'icon': Icons.place,
    'color': Colors.amber,
  },
};

// Helper methods for category info
String getCategoryDisplayName(String category) {
  return locationCategories[category]?['displayName'] ?? 'Other Places';
}

IconData getCategoryIcon(String category) {
  return locationCategories[category]?['icon'] ?? Icons.place;
}

Color getCategoryColor(String category) {
  return locationCategories[category]?['color'] ?? Colors.amber;
}