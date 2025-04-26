import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:project_navigo/models/route_history_filter.dart';
import 'package:project_navigo/themes/app_typography.dart';
import 'package:provider/provider.dart';
import 'package:project_navigo/themes/theme_provider.dart';

import '../models/route_history_filter.dart';

class RouteHistoryFilterSheet extends StatefulWidget {
  final RouteHistoryFilter initialFilter;
  final Function(RouteHistoryFilter) onApplyFilters;

  const RouteHistoryFilterSheet({
    Key? key,
    required this.initialFilter,
    required this.onApplyFilters,
  }) : super(key: key);

  @override
  _RouteHistoryFilterSheetState createState() => _RouteHistoryFilterSheetState();
}

class _RouteHistoryFilterSheetState extends State<RouteHistoryFilterSheet> {
  late RouteHistoryFilter _currentFilter;

  // Tracking expanded sections
  bool _isDateExpanded = false;
  bool _isTravelModeExpanded = false;
  bool _isDistanceExpanded = false;
  bool _isDurationExpanded = false;
  bool _isTrafficExpanded = false;

  // For date picker
  DateTimeRange? _selectedDateRange;

  // For travel mode selection
  final List<String> _allTravelModes = ['DRIVING', 'WALKING', 'BICYCLING', 'TRANSIT'];
  List<String>? _selectedTravelModes;

  // For distance and duration sliders
  RangeValues? _distanceValues;
  RangeValues? _durationValues;

  // For traffic conditions
  final List<String> _allTrafficConditions = ['light', 'normal', 'heavy'];
  List<String>? _selectedTrafficConditions;

  @override
  void initState() {
    super.initState();
    // Initialize filter state from the provided initial filter
    _currentFilter = widget.initialFilter;

    // Set up the individual filter values
    _selectedDateRange = _currentFilter.dateRange;
    _selectedTravelModes = _currentFilter.travelModes != null
        ? List.from(_currentFilter.travelModes!)
        : null;
    _distanceValues = _currentFilter.distanceRange;
    _durationValues = _currentFilter.durationRange;
    _selectedTrafficConditions = _currentFilter.trafficConditions != null
        ? List.from(_currentFilter.trafficConditions!)
        : null;

    // Auto-expand sections with active filters
    _isDateExpanded = _currentFilter.dateRange != null;
    _isTravelModeExpanded = _currentFilter.travelModes != null;
    _isDistanceExpanded = _currentFilter.distanceRange != null;
    _isDurationExpanded = _currentFilter.durationRange != null;
    _isTrafficExpanded = _currentFilter.trafficConditions != null;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Container(
      color: isDarkMode ? Colors.grey[900] : Colors.white,
      height: MediaQuery.of(context).size.height * 0.9,
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Close button
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                // Title
                Text(
                  'Filter Routes',
                  style: AppTypography.textTheme.titleLarge?.copyWith(
                    color: isDarkMode ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // Reset button
                TextButton(
                  onPressed: _resetFilters,
                  child: Text(
                    'Reset',
                    style: AppTypography.textTheme.labelLarge?.copyWith(
                      color: _currentFilter.hasActiveFilters
                          ? Colors.blue
                          : (isDarkMode ? Colors.grey[600] : Colors.grey[400]),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Divider(
            height: 1,
            thickness: 1,
            color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
          ),

          // Filter Options (Scrollable)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date Filter
                  _buildFilterExpansionTile(
                    title: 'Date',
                    subtitle: _selectedDateRange != null
                        ? '${DateFormat('MMM d, y').format(_selectedDateRange!.start)} - ${DateFormat('MMM d, y').format(_selectedDateRange!.end)}'
                        : 'Any date',
                    isExpanded: _isDateExpanded,
                    onExpansionChanged: (value) => setState(() => _isDateExpanded = value),
                    hasFilter: _selectedDateRange != null,
                    onClear: () => setState(() {
                      _selectedDateRange = null;
                    }),
                    children: [
                      _buildDateRangeSelector(isDarkMode),
                    ],
                    isDarkMode: isDarkMode,
                  ),

                  const SizedBox(height: 16),

                  // Distance Filter
                  _buildFilterExpansionTile(
                    title: 'Distance',
                    subtitle: _distanceValues != null
                        ? _formatDistanceRange(_distanceValues!)
                        : 'Any distance',
                    isExpanded: _isDistanceExpanded,
                    onExpansionChanged: (value) => setState(() => _isDistanceExpanded = value),
                    hasFilter: _distanceValues != null,
                    onClear: () => setState(() {
                      _distanceValues = null;
                    }),
                    children: [
                      _buildDistanceRangeSelector(isDarkMode),
                    ],
                    isDarkMode: isDarkMode,
                  ),

                  const SizedBox(height: 16),

                  // Duration Filter
                  _buildFilterExpansionTile(
                    title: 'Duration',
                    subtitle: _durationValues != null
                        ? _formatDurationRange(_durationValues!)
                        : 'Any duration',
                    isExpanded: _isDurationExpanded,
                    onExpansionChanged: (value) => setState(() => _isDurationExpanded = value),
                    hasFilter: _durationValues != null,
                    onClear: () => setState(() {
                      _durationValues = null;
                    }),
                    children: [
                      _buildDurationRangeSelector(isDarkMode),
                    ],
                    isDarkMode: isDarkMode,
                  ),

                  const SizedBox(height: 16),

                  // Traffic Filter
                  _buildFilterExpansionTile(
                    title: 'Traffic Conditions',
                    subtitle: _selectedTrafficConditions != null
                        ? _formatTrafficConditions(_selectedTrafficConditions!)
                        : 'Any traffic',
                    isExpanded: _isTrafficExpanded,
                    onExpansionChanged: (value) => setState(() => _isTrafficExpanded = value),
                    hasFilter: _selectedTrafficConditions != null,
                    onClear: () => setState(() {
                      _selectedTrafficConditions = null;
                    }),
                    children: [
                      _buildTrafficConditionSelector(isDarkMode),
                    ],
                    isDarkMode: isDarkMode,
                  ),
                ],
              ),
            ),
          ),

          // Divider
          Divider(
            height: 1,
            thickness: 1,
            color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
          ),

          // Apply Button
          Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _applyFilters,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Apply Filters',
                  style: AppTypography.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build an expansion tile for filter sections
  Widget _buildFilterExpansionTile({
    required String title,
    required String subtitle,
    required bool isExpanded,
    required Function(bool) onExpansionChanged,
    required List<Widget> children,
    required bool hasFilter,
    required Function() onClear,
    required bool isDarkMode,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[850] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          colorScheme: ColorScheme.fromSwatch().copyWith(
            // Make the expansion arrow color match the theme
            secondary: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        child: ExpansionTile(
          title: Text(
            title,
            style: AppTypography.textTheme.titleMedium?.copyWith(
              color: isDarkMode ? Colors.white : Colors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: AppTypography.textTheme.bodyMedium?.copyWith(
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          initiallyExpanded: isExpanded,
          onExpansionChanged: onExpansionChanged,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Clear button if filter is active
              if (hasFilter)
                IconButton(
                  icon: Icon(
                    Icons.clear,
                    size: 20,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                  onPressed: onClear,
                ),
              // Expansion arrow
              Icon(
                isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ],
          ),
          children: children,
        ),
      ),
    );
  }

  // Date Range Selector
  Widget _buildDateRangeSelector(bool isDarkMode) {
    // Get last 90 days as default range for date picker
    final DateTime now = DateTime.now();
    final DateTime ninetyDaysAgo = now.subtract(const Duration(days: 90));

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Predefined date ranges
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildDateChip('Today',
                      () => _selectPredefinedDateRange(
                      DateTime(now.year, now.month, now.day),
                      now
                  ),
                  isDarkMode
              ),
              _buildDateChip('Yesterday',
                      () => _selectPredefinedDateRange(
                      DateTime(now.year, now.month, now.day - 1),
                      DateTime(now.year, now.month, now.day - 1)
                  ),
                  isDarkMode
              ),
              _buildDateChip('Last 7 days',
                      () => _selectPredefinedDateRange(
                      now.subtract(const Duration(days: 7)),
                      now
                  ),
                  isDarkMode
              ),
              _buildDateChip('Last 30 days',
                      () => _selectPredefinedDateRange(
                      now.subtract(const Duration(days: 30)),
                      now
                  ),
                  isDarkMode
              ),
              _buildDateChip('This month',
                      () => _selectPredefinedDateRange(
                      DateTime(now.year, now.month, 1),
                      DateTime(now.year, now.month + 1, 0)
                  ),
                  isDarkMode
              ),
              _buildDateChip('Last month',
                      () => _selectPredefinedDateRange(
                      DateTime(now.year, now.month - 1, 1),
                      DateTime(now.year, now.month, 0)
                  ),
                  isDarkMode
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Custom date range button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _showCustomDateRangePicker(ninetyDaysAgo, now),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                _selectedDateRange != null
                    ? '${DateFormat('MMM d, y').format(_selectedDateRange!.start)} - ${DateFormat('MMM d, y').format(_selectedDateRange!.end)}'
                    : 'Custom Date Range',
                style: AppTypography.textTheme.bodyMedium?.copyWith(
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper to build date range chip
  Widget _buildDateChip(String label, VoidCallback onTap, bool isDarkMode) {
    return GestureDetector(
      onTap: onTap,
      child: Chip(
        label: Text(
          label,
          style: AppTypography.textTheme.bodyMedium?.copyWith(
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[200],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  // Helper to select predefined date range
  void _selectPredefinedDateRange(DateTime start, DateTime end) {
    setState(() {
      _selectedDateRange = DateTimeRange(start: start, end: end);
    });
  }

  // Show date range picker
  Future<void> _showCustomDateRangePicker(DateTime firstDate, DateTime lastDate) async {
    final DateTimeRange? result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020), // Set a reasonable start date
      lastDate: lastDate,
      initialDateRange: _selectedDateRange ?? DateTimeRange(
        start: firstDate,
        end: lastDate,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              surface: Provider.of<ThemeProvider>(context).isDarkMode
                  ? Colors.grey[850]!
                  : Colors.white,
              onSurface: Provider.of<ThemeProvider>(context).isDarkMode
                  ? Colors.white
                  : Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (result != null) {
      setState(() {
        _selectedDateRange = result;
      });
    }
  }

  // Travel Mode Selector
  Widget _buildTravelModeSelector(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: _allTravelModes.map((mode) {
          final isSelected = _selectedTravelModes?.contains(mode) ?? false;
          return CheckboxListTile(
            title: Text(
              _formatTravelMode(mode),
              style: AppTypography.textTheme.bodyLarge?.copyWith(
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            value: isSelected,
            onChanged: (bool? value) {
              setState(() {
                if (value == true) {
                  // Initialize the list if needed
                  _selectedTravelModes ??= [];
                  _selectedTravelModes!.add(mode);
                } else {
                  _selectedTravelModes?.remove(mode);
                  // If all modes are deselected, set to null (any mode)
                  if (_selectedTravelModes?.isEmpty ?? true) {
                    _selectedTravelModes = null;
                  }
                }
              });
            },
            activeColor: Colors.blue,
            checkColor: Colors.white,
            controlAffinity: ListTileControlAffinity.trailing,
            contentPadding: EdgeInsets.zero,
          );
        }).toList(),
      ),
    );
  }

  // Distance Range Selector
  Widget _buildDistanceRangeSelector(bool isDarkMode) {
    // Default range if none selected
    final currentRange = _distanceValues ?? const RangeValues(0, RouteHistoryFilter.maxDistance);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Distance range slider
          RangeSlider(
            values: currentRange,
            min: 0,
            max: RouteHistoryFilter.maxDistance,
            divisions: 50,
            labels: RangeLabels(
              _formatDistance(currentRange.start),
              _formatDistance(currentRange.end),
            ),
            onChanged: (RangeValues values) {
              setState(() {
                _distanceValues = values;
              });
            },
            activeColor: Colors.blue,
            inactiveColor: isDarkMode ? Colors.grey[700] : Colors.grey[300],
          ),

          // Labels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDistance(currentRange.start),
                  style: AppTypography.textTheme.bodyMedium?.copyWith(
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                Text(
                  _formatDistance(currentRange.end),
                  style: AppTypography.textTheme.bodyMedium?.copyWith(
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          // Predefined distance ranges
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildDistanceChip('< 1 km', () => setState(() {
                _distanceValues = const RangeValues(0, 1000);
              }), isDarkMode),
              _buildDistanceChip('1-5 km', () => setState(() {
                _distanceValues = const RangeValues(1000, 5000);
              }), isDarkMode),
              _buildDistanceChip('5-10 km', () => setState(() {
                _distanceValues = const RangeValues(5000, 10000);
              }), isDarkMode),
              _buildDistanceChip('10-20 km', () => setState(() {
                _distanceValues = const RangeValues(10000, 20000);
              }), isDarkMode),
              _buildDistanceChip('> 20 km', () => setState(() {
                _distanceValues = const RangeValues(20000, RouteHistoryFilter.maxDistance);
              }), isDarkMode),
            ],
          ),
        ],
      ),
    );
  }

  // Duration Range Selector
  Widget _buildDurationRangeSelector(bool isDarkMode) {
    // Default range if none selected
    final currentRange = _durationValues ?? const RangeValues(0, RouteHistoryFilter.maxDuration);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Duration range slider
          RangeSlider(
            values: currentRange,
            min: 0,
            max: RouteHistoryFilter.maxDuration,
            divisions: 48, // 2 minutes increments for 2 hours max
            labels: RangeLabels(
              _formatDuration(currentRange.start),
              _formatDuration(currentRange.end),
            ),
            onChanged: (RangeValues values) {
              setState(() {
                _durationValues = values;
              });
            },
            activeColor: Colors.blue,
            inactiveColor: isDarkMode ? Colors.grey[700] : Colors.grey[300],
          ),

          // Labels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(currentRange.start),
                  style: AppTypography.textTheme.bodyMedium?.copyWith(
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                Text(
                  _formatDuration(currentRange.end),
                  style: AppTypography.textTheme.bodyMedium?.copyWith(
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          // Predefined duration ranges
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildDistanceChip('< 15 min', () => setState(() {
                _durationValues = const RangeValues(0, 900);
              }), isDarkMode),
              _buildDistanceChip('15-30 min', () => setState(() {
                _durationValues = const RangeValues(900, 1800);
              }), isDarkMode),
              _buildDistanceChip('30-60 min', () => setState(() {
                _durationValues = const RangeValues(1800, 3600);
              }), isDarkMode),
              _buildDistanceChip('1-2 hours', () => setState(() {
                _durationValues = const RangeValues(3600, 7200);
              }), isDarkMode),
              _buildDistanceChip('> 1 hour', () => setState(() {
                _durationValues = const RangeValues(3600, RouteHistoryFilter.maxDuration);
              }), isDarkMode),
            ],
          ),
        ],
      ),
    );
  }

  // Traffic Condition Selector
  Widget _buildTrafficConditionSelector(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: _allTrafficConditions.map((condition) {
          final isSelected = _selectedTrafficConditions?.contains(condition) ?? false;
          return CheckboxListTile(
            title: Row(
              children: [
                _buildTrafficConditionIcon(condition),
                const SizedBox(width: 12),
                Text(
                  condition[0].toUpperCase() + condition.substring(1),
                  style: AppTypography.textTheme.bodyLarge?.copyWith(
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
            value: isSelected,
            onChanged: (bool? value) {
              setState(() {
                if (value == true) {
                  // Initialize the list if needed
                  _selectedTrafficConditions ??= [];
                  _selectedTrafficConditions!.add(condition);
                } else {
                  _selectedTrafficConditions?.remove(condition);
                  // If all conditions are deselected, set to null (any condition)
                  if (_selectedTrafficConditions?.isEmpty ?? true) {
                    _selectedTrafficConditions = null;
                  }
                }
              });
            },
            activeColor: Colors.blue,
            checkColor: Colors.white,
            controlAffinity: ListTileControlAffinity.trailing,
            contentPadding: EdgeInsets.zero,
          );
        }).toList(),
      ),
    );
  }

  // Helper for distance chip
  Widget _buildDistanceChip(String label, VoidCallback onTap, bool isDarkMode) {
    return GestureDetector(
      onTap: onTap,
      child: Chip(
        label: Text(
          label,
          style: AppTypography.textTheme.bodyMedium?.copyWith(
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[200],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  // Helper to format distance values
  String _formatDistance(double meters) {
    if (meters >= RouteHistoryFilter.maxDistance) {
      return 'Any';
    }
    if (meters < 1000) {
      return '${meters.toInt()} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }

  // Helper to format distance range
  String _formatDistanceRange(RangeValues range) {
    final minDistance = _formatDistance(range.start);
    final maxDistance = _formatDistance(range.end);
    return '$minDistance - $maxDistance';
  }

  // Helper to format duration values
  String _formatDuration(double seconds) {
    if (seconds >= RouteHistoryFilter.maxDuration) {
      return 'Any';
    }
    if (seconds < 60) {
      return '${seconds.toInt()} sec';
    } else if (seconds < 3600) {
      return '${(seconds / 60).floor()} min';
    } else {
      int hours = (seconds / 3600).floor();
      int minutes = ((seconds % 3600) / 60).floor();
      return minutes > 0 ? '$hours h $minutes min' : '$hours h';
    }
  }

  // Helper to format duration range
  String _formatDurationRange(RangeValues range) {
    final minDuration = _formatDuration(range.start);
    final maxDuration = _formatDuration(range.end);
    return '$minDuration - $maxDuration';
  }

  // Helper to format travel modes
  String _formatTravelModes(List<String> modes) {
    return modes.map((mode) => _formatTravelMode(mode)).join(', ');
  }

  // Helper to format a single travel mode
  String _formatTravelMode(String mode) {
    switch (mode) {
      case 'DRIVING': return 'Driving';
      case 'WALKING': return 'Walking';
      case 'BICYCLING': return 'Cycling';
      case 'TRANSIT': return 'Transit';
      default: return mode;
    }
  }

  // Helper to format traffic conditions
  String _formatTrafficConditions(List<String> conditions) {
    return conditions.map((condition) =>
    condition[0].toUpperCase() + condition.substring(1)
    ).join(', ');
  }

  // Helper to get traffic condition icon
  Widget _buildTrafficConditionIcon(String condition) {
    Color iconColor;
    switch (condition) {
      case 'light':
        iconColor = Colors.green;
        break;
      case 'normal':
        iconColor = Colors.amber;
        break;
      case 'heavy':
        iconColor = Colors.red;
        break;
      default:
        iconColor = Colors.grey;
    }

    return Icon(Icons.traffic, color: iconColor, size: 24);
  }

  // Reset all filters
  void _resetFilters() {
    setState(() {
      _selectedDateRange = null;
      _selectedTravelModes = null;
      _distanceValues = null;
      _durationValues = null;
      _selectedTrafficConditions = null;

      // Collapse all sections
      _isDateExpanded = false;
      _isTravelModeExpanded = false;
      _isDistanceExpanded = false;
      _isDurationExpanded = false;
      _isTrafficExpanded = false;
    });
  }

  // Apply filters and close sheet
  void _applyFilters() {
    // Build the filter object from current state
    final newFilter = RouteHistoryFilter(
      dateRange: _selectedDateRange,
      travelModes: _selectedTravelModes,
      distanceRange: _distanceValues,
      durationRange: _durationValues,
      trafficConditions: _selectedTrafficConditions,
    );

    // Call the callback with the new filter
    widget.onApplyFilters(newFilter);

    // Close the sheet
    Navigator.pop(context);
  }
}