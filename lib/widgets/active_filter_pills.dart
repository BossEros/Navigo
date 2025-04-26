import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:project_navigo/models/route_history_filter.dart';
import 'package:project_navigo/themes/app_typography.dart';

class ActiveFilterPills extends StatelessWidget {
  final RouteHistoryFilter filter;
  final Function(RouteHistoryFilter) onFilterChanged;
  final bool isDarkMode;

  const ActiveFilterPills({
    Key? key,
    required this.filter,
    required this.onFilterChanged,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // If no active filters, don't show anything
    if (!filter.hasActiveFilters) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Row(
            children: [
              Icon(
                Icons.filter_list,
                size: 16,
                color: isDarkMode ? Colors.white : Colors.grey[700],
              ),
              const SizedBox(width: 8),
              Text(
                'Filters:',
                style: AppTypography.textTheme.bodyMedium?.copyWith(
                  color: isDarkMode ? Colors.white : Colors.grey[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              // Clear all button
              TextButton(
                onPressed: () {
                  onFilterChanged(RouteHistoryFilter.empty());
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(50, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Clear all',
                  style: AppTypography.textTheme.bodySmall?.copyWith(
                    color: Colors.blue,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Filter pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _buildFilterPills(),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFilterPills() {
    final List<Widget> pills = [];

    // Date range pill
    if (filter.dateRange != null) {
      pills.add(
        _buildPill(
          'Date: ${DateFormat('MMM d').format(filter.dateRange!.start)} - ${DateFormat('MMM d').format(filter.dateRange!.end)}',
              () => onFilterChanged(filter.copyWith(clearDateRange: true)),
        ),
      );
    }

    // Travel mode pill
    if (filter.travelModes != null) {
      pills.add(
        _buildPill(
          'Mode: ${filter.formattedTravelModes}',
              () => onFilterChanged(filter.copyWith(clearTravelModes: true)),
        ),
      );
    }

    // Distance range pill
    if (filter.distanceRange != null) {
      pills.add(
        _buildPill(
          'Distance: ${filter.formattedDistanceRange}',
              () => onFilterChanged(filter.copyWith(clearDistanceRange: true)),
        ),
      );
    }

    // Duration range pill
    if (filter.durationRange != null) {
      pills.add(
        _buildPill(
          'Duration: ${filter.formattedDurationRange}',
              () => onFilterChanged(filter.copyWith(clearDurationRange: true)),
        ),
      );
    }

    // Traffic conditions pill
    if (filter.trafficConditions != null) {
      pills.add(
        _buildPill(
          'Traffic: ${filter.formattedTrafficConditions}',
              () => onFilterChanged(filter.copyWith(clearTrafficConditions: true)),
        ),
      );
    }

    return pills;
  }

  Widget _buildPill(String text, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[800] : Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isDarkMode ? Colors.grey[700]! : Colors.blue.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 6, bottom: 6, right: 4),
            child: Text(
              text,
              style: AppTypography.textTheme.bodySmall?.copyWith(
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              size: 16,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
            constraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
            padding: EdgeInsets.zero,
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}