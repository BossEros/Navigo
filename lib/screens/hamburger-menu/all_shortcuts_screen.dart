import 'package:flutter/material.dart';
import 'package:project_navigo/themes/app_typography.dart';
import 'package:project_navigo/themes/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:project_navigo/services/quick_access_shortcut_service.dart';
import 'package:flutter/services.dart';
import 'dart:ui' show lerpDouble;
import 'dart:ui' as ui;
import 'package:project_navigo/themes/theme_provider.dart';

class AllShortcutsScreen extends StatefulWidget {
  // Pass the current shortcuts, callback handlers
  final List<dynamic> shortcuts;
  final Function(dynamic) onShortcutTap;
  final Future<dynamic> Function() onAddNewShortcut;
  final Function(String) onDeleteShortcut;
  // Ensure we use a consistent name
  final Function(List<dynamic>)? onReorderShortcuts;  // Make it optional with '?'

  const AllShortcutsScreen({
    Key? key,
    required this.shortcuts,
    required this.onShortcutTap,
    required this.onAddNewShortcut,
    required this.onDeleteShortcut,
    this.onReorderShortcuts,  // Optional parameter
  }) : super(key: key);

  @override
  _AllShortcutsScreenState createState() => _AllShortcutsScreenState();
}

class _AllShortcutsScreenState extends State<AllShortcutsScreen> {
  List<dynamic> _shortcuts = [];
  bool _isLoading = false;
  QuickAccessShortcutService? _shortcutService;

  @override
  void initState() {
    super.initState();
    _shortcuts = List.from(widget.shortcuts);

    // Get service for deletion operations
    Future.microtask(() {
      _shortcutService = Provider.of<QuickAccessShortcutService>(context, listen: false);
    });
  }

  void _deleteShortcut(dynamic shortcut) {
    // Call the parent callback to handle deletion
    widget.onDeleteShortcut(shortcut.id);

    // Also update local list
    setState(() {
      _shortcuts.removeWhere((item) => item.id == shortcut.id);
    });

    // Show the enhanced delete success overlay
    _showDeleteSuccessOverlay(shortcut);
  }

  void _showDeleteSuccessOverlay(dynamic shortcut) {
    // Get theme state
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    // Add haptic feedback for better UX
    HapticFeedback.mediumImpact();

    // Create an overlay entry
    final overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) {
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutQuart,
          builder: (context, value, child) {
            return Positioned(
              top: 150 + (40 * (1 - value)), // Slide down animation
              left: 20,
              right: 20,
              child: Opacity(
                opacity: value,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Color.lerp(Colors.grey[900], Colors.red, 0.1)
                          : Color.lerp(Colors.white, Colors.red, 0.05),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 1,
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                        ),
                      ],
                      border: Border.all(
                          color: Colors.red.withOpacity(0.5),
                          width: 1.5
                      ),
                    ),
                    child: Row(
                      children: [
                        // Animated delete icon
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.elasticOut,
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                  size: 28,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 16),

                        // Text content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Shortcut Deleted',
                                style: AppTypography.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '"${shortcut.label}" has been removed',
                                style: AppTypography.textTheme.bodyMedium?.copyWith(
                                  color: isDarkMode ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    // Add the overlay
    overlayState.insert(overlayEntry);

    // Remove after 2.5 seconds
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Get the current theme state
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    // Get the bottom padding needed for the system navigation bar
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      // Theme-aware background color
      backgroundColor: isDarkMode ? AppTheme.darkTheme.scaffoldBackgroundColor : Colors.white,
      appBar: AppBar(
        title: Text(
          'Quick Access Shortcuts',
          style: AppTypography.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            // Theme-aware text color
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        // Theme-aware AppBar styling
        backgroundColor: isDarkMode ? AppTheme.darkTheme.appBarTheme.backgroundColor : Colors.white,
        elevation: 0,
        leading: IconButton(
          // Theme-aware icon color
          icon: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        // Set bottom to false as we'll handle bottom padding manually
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main content - shortcuts or empty state
            _isLoading
                ? Center(
              child: CircularProgressIndicator(
                // Use theme-aware color for the progress indicator
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDarkMode ? Colors.white : Colors.blue,
                ),
              ),
            )
                : _shortcuts.isEmpty
                ? _buildEmptyState(isDarkMode)
                : _buildShortcutsContent(isDarkMode),

            // Add new shortcut button (persistent at bottom with safe area padding)
            _buildAddButton(bottomPadding, isDarkMode),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmarks_outlined,
              size: 72,
              // Lighter gray in dark mode
              color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'No shortcuts added yet',
              style: AppTypography.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                // White text in dark mode
                color: isDarkMode ? Colors.white : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add shortcuts for your frequent destinations',
              style: AppTypography.textTheme.bodyMedium?.copyWith(
                // Lighter text in dark mode
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShortcutsContent(bool isDarkMode) {
    return Expanded(  // Wrap the entire content in Expanded to provide bounded height
      child: Column(
        children: [
          // Help text for edit feature - theme-aware styling
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                // Darker blue in dark mode
                color: isDarkMode
                    ? Colors.blue.withOpacity(0.15)
                    : Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  // Darker blue border in dark mode
                  color: isDarkMode
                      ? Colors.blue.withOpacity(0.4)
                      : Colors.blue.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tap to navigate, drag to reorder, or use the edit button for more options',
                      style: AppTypography.textTheme.bodyMedium?.copyWith(
                        // Keep blue text in both modes for emphasis but adjust shade
                        color: isDarkMode ? Colors.blue[300] : Colors.blue[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ReorderableListView - key change is to use Expanded here so it has a bounded height
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _shortcuts.length,
              onReorder: (oldIndex, newIndex) {
                // Handle reordering logic
                setState(() {
                  if (oldIndex < newIndex) {
                    // Adjusting the destination index when moving down
                    newIndex -= 1;
                  }
                  final shortcut = _shortcuts.removeAt(oldIndex);
                  _shortcuts.insert(newIndex, shortcut);

                  // Add haptic feedback
                  HapticFeedback.mediumImpact();

                  // Check if the callback exists before calling it
                  if (widget.onReorderShortcuts != null) {
                    widget.onReorderShortcuts!(_shortcuts);
                  }
                });
              },
              // Add the proxyDecorator for better visual feedback - theme-aware styling
              proxyDecorator: (child, index, animation) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (BuildContext context, Widget? child) {
                    final double animValue = Curves.easeInOut.transform(animation.value);
                    final double elevation = lerpDouble(0, 6, animValue)!;
                    return Material(
                      elevation: elevation,
                      color: Colors.transparent,
                      // Darker shadow in dark mode
                      shadowColor: isDarkMode
                          ? Colors.black.withOpacity(0.3)
                          : Colors.black.withOpacity(0.2),
                      child: child,
                    );
                  },
                  child: child,
                );
              },
              itemBuilder: (context, index) {
                final shortcut = _shortcuts[index];
                return _buildReorderableShortcutItem(shortcut, index, isDarkMode);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReorderableShortcutItem(dynamic shortcut, int index, bool isDarkMode) {
    return Container(
      key: ValueKey(shortcut.id),  // Key is required for ReorderableListView
      margin: const EdgeInsets.only(bottom: 12),
      child: Stack(
        children: [
          // Main shortcut card - theme-aware styling
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              // Dark card background in dark mode
              color: isDarkMode ? AppTheme.darkTheme.cardTheme.color : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  // Darker, more subtle shadow in dark mode
                  color: isDarkMode
                      ? Colors.black.withOpacity(0.2)
                      : Colors.black.withOpacity(0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              // Use transparent material to preserve ink effects
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                // In dark mode, make splash more visible
                splashColor: isDarkMode
                    ? Colors.grey[700]
                    : null,
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onShortcutTap(shortcut);
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      // Drag handle icon for reordering - theme-aware
                      ReorderableDragStartListener(
                        index: index,
                        child: Semantics(
                          label: 'Drag to reorder shortcut',
                          hint: 'Double tap and hold to reorder',
                          child: Container(
                            width: 24,
                            height: 24,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              // Darker background in dark mode
                              color: isDarkMode
                                  ? Colors.grey[800]
                                  : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Icon(
                              Icons.drag_handle,
                              // Lighter icon in dark mode
                              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                              size: 16,
                            ),
                          ),
                        ),
                      ),

                      // Shortcut icon - theme-aware container
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          // Darker blue background in dark mode
                          color: isDarkMode
                              ? Colors.blue.withOpacity(0.2)
                              : Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Image.asset(
                            shortcut.iconPath,
                            width: 28,
                            height: 28,
                            // Apply a color filter in dark mode to brighten the icon
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.star,
                                // Blue color in both modes for contrast
                                color: Colors.blue,
                                size: 24,
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Shortcut label and address preview - theme-aware text
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              shortcut.label,
                              style: AppTypography.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                // White text in dark mode
                                color: isDarkMode ? Colors.white : null,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 4),
                            Text(
                              shortcut.address ?? 'Tap to navigate',
                              style: AppTypography.textTheme.bodySmall?.copyWith(
                                // Lighter text in dark mode
                                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // Edit button (integrated into the row) - theme-aware
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _showEditOptions(shortcut, isDarkMode),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Icon(
                              Icons.edit,
                              size: 20,
                              // Keep blue for contrast in both modes
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton([double bottomPadding = 0, bool isDarkMode = false]) {
    return Container(
      width: double.infinity,
      // Add additional padding at the bottom to respect system navigation
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomPadding),
      decoration: BoxDecoration(
        // Theme-aware background
        color: isDarkMode ? AppTheme.darkTheme.cardTheme.color : Colors.white,
        boxShadow: [
          BoxShadow(
            // Darker shadow in dark mode
            color: isDarkMode
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () async {
          // Set loading state
          setState(() {
            _isLoading = true;
          });

          try {
            // Call the add shortcut function and await its result
            final newShortcut = await widget.onAddNewShortcut();

            // If a new shortcut was created, add it to our local list
            if (newShortcut != null && mounted) {
              setState(() {
                _shortcuts.add(newShortcut);
                _isLoading = false;
              });
            } else if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          } catch (e) {
            // Handle any errors
            if (mounted) {
              setState(() {
                _isLoading = false;
              });

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Error creating shortcut: ${e.toString()}',
                    style: AppTypography.textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        },
        style: ElevatedButton.styleFrom(
          // Use theme-aware color
          backgroundColor: isDarkMode
              ? AppTheme.darkTheme.colorScheme.primary
              : Colors.blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Text(
          'Add New Shortcut',
          style: AppTypography.textTheme.labelLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _showEditOptions(dynamic shortcut, bool isDarkMode) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // Make transparent to apply custom styling
      barrierColor: Colors.black.withOpacity(0.5), // Semi-transparent backdrop
      builder: (context) => BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3), // Subtle background blur
        child: SafeArea( // Ensure content respects device's safe areas
          child: Container(
            padding: const EdgeInsets.only(top: 12, bottom: 24),
            decoration: BoxDecoration(
              // Theme-aware background
              color: isDarkMode ? AppTheme.darkTheme.cardTheme.color : Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  // Darker shadow in dark mode
                  color: isDarkMode
                      ? Colors.black.withOpacity(0.3)
                      : Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 0,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Modern drag handle for bottom sheet
                Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    // Darker gray in dark mode
                    color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),

                // Shortcut title with icon
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        shortcut.iconPath,
                        width: 24,
                        height: 24,
                        // Lighter icon in dark mode
                        //color: isDarkMode ? Colors.white : null,
                        errorBuilder: (_, __, ___) => Icon(
                            Icons.star,
                            // Keep blue in both modes
                            color: Colors.blue
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          shortcut.label,
                          style: AppTypography.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            // White text in dark mode
                            color: isDarkMode ? Colors.white : null,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 24),

                // Edit option - Enhanced with Inkwell for touch feedback
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        // Add haptic feedback for better UX
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                        _editShortcut(shortcut);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Ink(
                        decoration: BoxDecoration(
                          // Darker blue in dark mode
                          color: isDarkMode
                              ? Colors.blue.withOpacity(0.15)
                              : Colors.blue.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  // Darker blue in dark mode
                                  color: isDarkMode
                                      ? Colors.blue.withOpacity(0.2)
                                      : Colors.blue.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.edit, color: Colors.blue, size: 24),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  'Edit Shortcut',
                                  style: AppTypography.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    // White text in dark mode
                                    color: isDarkMode ? Colors.white : null,
                                  ),
                                ),
                              ),
                              Icon(
                                  Icons.chevron_right,
                                  // Lighter gray in dark mode
                                  color: isDarkMode ? Colors.grey[600] : Colors.grey[400]
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 12),

                // Delete option - Enhanced with Inkwell for touch feedback
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        // Add haptic feedback for better UX
                        HapticFeedback.mediumImpact();
                        Navigator.pop(context);
                        _showDeleteConfirmation(shortcut, isDarkMode);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Ink(
                        decoration: BoxDecoration(
                          // Darker red in dark mode
                          color: isDarkMode
                              ? Colors.red.withOpacity(0.15)
                              : Colors.red.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  // Darker red in dark mode
                                  color: isDarkMode
                                      ? Colors.red.withOpacity(0.2)
                                      : Colors.red.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.delete_outline, color: Colors.red, size: 24),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  'Delete Shortcut',
                                  style: AppTypography.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                              Icon(
                                  Icons.chevron_right,
                                  // Lighter red in dark mode
                                  color: isDarkMode ? Colors.red[300] : Colors.red[200]
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editShortcut(dynamic shortcut) async {
    // Return to parent with edit request
    Navigator.of(context).pop({
      'action': 'edit',
      'shortcut': shortcut
    });
  }

  void _showDeleteConfirmation(dynamic shortcut, bool isDarkMode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        // Theme-aware background
        backgroundColor: isDarkMode ? AppTheme.darkTheme.dialogBackgroundColor : Colors.white,
        title: Text(
          'Delete Shortcut?',
          style: AppTypography.textTheme.titleLarge?.copyWith(
            // White text in dark mode
            color: isDarkMode ? Colors.white : null,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${shortcut.label}"? This action cannot be undone.',
          style: AppTypography.textTheme.bodyLarge?.copyWith(
            // Lighter text in dark mode
            color: isDarkMode ? Colors.grey[300] : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'CANCEL',
              style: AppTypography.textTheme.labelLarge?.copyWith(
                // Lighter text in dark mode
                color: isDarkMode ? Colors.grey[400] : null,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteShortcut(shortcut);
            },
            child: Text(
              'DELETE',
              style: AppTypography.textTheme.labelLarge?.copyWith(
                // Keep red in both modes for emphasis
                color: Colors.red,
              ),
            ),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}