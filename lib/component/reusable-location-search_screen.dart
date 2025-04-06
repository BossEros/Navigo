import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:project_navigo/services/google-api-services.dart' as api;

/// A reusable location search screen that matches the main app's search experience.
/// Returns the selected [api.Place] when a location is chosen.
class LocationSearchScreen extends StatefulWidget {
  final String title;
  final String initialQuery;
  final String searchHint;

  const LocationSearchScreen({
    Key? key,
    required this.title,
    this.initialQuery = '',
    this.searchHint = 'Search for a location',
  }) : super(key: key);

  @override
  _LocationSearchScreenState createState() => _LocationSearchScreenState();
}

class _LocationSearchScreenState extends State<LocationSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<api.PlaceSuggestion> _placeSuggestions = [];
  bool _isSearching = false;
  Timer? _debounce;
  Map<String, String> _suggestionDistances = {};

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialQuery;

    // Auto-focus the search field when the screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    // Cancel any existing debounce timer
    _debounce?.cancel();

    // Set a new debounce timer
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.isNotEmpty) {
        setState(() {
          _isSearching = true;
          _placeSuggestions = []; // Clear previous results while searching
        });

        try {
          // Fetch suggestions using the Google Places API
          final suggestions = await api.GoogleApiServices.getPlaceSuggestions(query);

          // Only update state if the component is still mounted and the search text hasn't changed
          if (mounted && _searchController.text == query) {
            setState(() {
              _placeSuggestions = suggestions;
              _isSearching = false;
            });
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error getting place suggestions: $e')),
            );
            setState(() {
              _isSearching = false;
            });
          }
        }
      } else {
        setState(() {
          _placeSuggestions = [];
          _isSearching = false;
        });
      }
    });
  }

  Future<void> _selectPlace(api.PlaceSuggestion suggestion) async {
    try {
      // Close keyboard
      FocusScope.of(context).unfocus();

      setState(() {
        _isSearching = true;
      });

      // Get place details
      final place = await api.GoogleApiServices.getPlaceDetails(suggestion.placeId);

      if (place != null && mounted) {
        // Return the selected place to the calling screen
        Navigator.of(context).pop(place);
      } else {
        if (mounted) {
          setState(() {
            _isSearching = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not get details for the selected place')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting place details: $e')),
        );
      }
    }
  }

  String _calculateDistance(api.PlaceSuggestion suggestion) {
    // Return cached distance if available
    if (_suggestionDistances.containsKey(suggestion.placeId)) {
      return _suggestionDistances[suggestion.placeId]!;
    }

    // Return a placeholder while calculating
    return "-";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(Icons.search, color: Colors.grey[600]),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      decoration: InputDecoration(
                        hintText: widget.searchHint,
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: Colors.grey[600]),
                      ),
                      onChanged: _onSearchChanged,
                    ),
                  ),
                  if (_isSearching)
                    const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      color: Colors.grey[600],
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _placeSuggestions = [];
                        });
                      },
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.mic),
                      color: Colors.grey[600],
                      onPressed: () {
                        // Voice search functionality
                      },
                    ),
                ],
              ),
            ),
          ),

          // Search results
          Expanded(
            child: _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Searching places...'),
          ],
        ),
      );
    }

    if (_searchController.text.isEmpty) {
      return _buildSearchSuggestions();
    }

    if (_placeSuggestions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No places found for "${_searchController.text}"',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term or check your internet connection',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _placeSuggestions.length,
      itemBuilder: (context, index) {
        final suggestion = _placeSuggestions[index];
        return ListTile(
          leading: Icon(Icons.location_on, color: Colors.grey[600]),
          title: Text(suggestion.mainText),
          subtitle: Text(
            suggestion.secondaryText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(
            _calculateDistance(suggestion) == "-"
                ? "-"
                : "${_calculateDistance(suggestion)} km",
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          onTap: () => _selectPlace(suggestion),
        );
      },
    );
  }

  Widget _buildSearchSuggestions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            'Suggestions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          // Recent searches or common locations
          _buildSuggestionItem(
            'Current Location',
            Icons.my_location,
                () {
              // Handle current location selection
            },
          ),
          _buildSuggestionItem(
            'Nearby Places',
            Icons.place,
                () {
              // Handle nearby places selection
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionItem(String text, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue),
      title: Text(text),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
}