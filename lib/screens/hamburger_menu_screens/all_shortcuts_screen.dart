import 'package:flutter/material.dart';
import 'package:project_navigo/themes/app_typography.dart';
import 'package:project_navigo/themes/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:project_navigo/services/quick_access_shortcut_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'dart:ui' show lerpDouble;
import 'dart:ui' as ui; // For BackdropFilter
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

    // Get the current theme state
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    // Show confirmation with theme-aware styling
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Shortcut deleted',
          style: AppTypography.textTheme.bodyMedium?.copyWith(color: Colors.white),
        ),
        behavior: SnackBarBehavior.floating,
        // Dark snackbar in light mode, lighter in dark mode for contrast
        backgroundColor: isDarkMode ? Colors.grey[800] : Colors.black87,
        action: SnackBarAction(
          label: 'UNDO',
          // Use white text on both themes for contrast
          textColor: Colors.white,
          onPressed: () {
            // In a real app, you'd handle undo here
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Restore feature coming soon'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: isDarkMode ? Colors.grey[800] : Colors.black87,
              ),
            );
          },
        ),
      ),
    );
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

  void _onReorder(int oldIndex, int newIndex, bool isDarkMode) {
    setState(() {
      // ReorderableListView's behavior: when you drag an item down,
      // the index of the insertion point is shifted
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }

      // Update the order in our local list
      final item = _shortcuts.removeAt(oldIndex);
      _shortcuts.insert(newIndex, item);
    });

    // Notify parent about the reordered list
    widget.onReorderShortcuts!(_shortcuts);

    // Show confirmation with theme-aware styling
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Shortcut order updated',
          style: AppTypography.textTheme.bodyMedium?.copyWith(color: Colors.white),
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
        // Theme-aware background
        backgroundColor: isDarkMode ? Colors.grey[800] : Colors.black87,
      ),
    );
  }

  // Helper method to safely load icons with fallbacks
  Widget _buildSafeIcon(String iconPath, bool isDarkMode) {
    // Map of standard icons to use as fallbacks
    final Map<String, IconData> fallbackIcons = {
      'home': Icons.home,
      'work': Icons.work,
      'star': Icons.star,
      'favorite': Icons.favorite,
      'restaurant': Icons.restaurant,
      'shopping': Icons.shopping_bag,
      'school': Icons.school,
      'gym': Icons.fitness_center,
      'more': Icons.more_horiz,
      'plus': Icons.add,
      // Add more mappings as needed
    };

    // Determine which icon to use based on the path
    IconData? iconData;
    for (final entry in fallbackIcons.entries) {
      if (iconPath.toLowerCase().contains(entry.key)) {
        iconData = entry.value;
        break;
      }
    }

    // Default fallback
    iconData ??= Icons.star;

    // Try to load the asset, with the icon as fallback
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        iconPath,
        width: 28,
        height: 28,
        // Apply a color filter in dark mode to make icons more visible
        color: isDarkMode ? Colors.white : null,
        errorBuilder: (context, error, stackTrace) {
          // On error, use the icon
          return Icon(
            iconData,
            // Use blue in both modes for visibility
            color: Colors.blue,
            size: 24,
          );
        },
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

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? textColor,
    Color? iconColor,
    bool isDarkMode = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          // Darker background in dark mode
          color: isDarkMode ? Colors.grey[850] : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: iconColor ?? Colors.blue,
              size: 20,
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: AppTypography.textTheme.titleMedium?.copyWith(
                color: textColor ?? (isDarkMode ? Colors.white : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(dynamic shortcut, bool isDarkMode) {
    final TextEditingController controller = TextEditingController(text: shortcut.label);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        // Theme-aware background
        backgroundColor: isDarkMode ? AppTheme.darkTheme.dialogBackgroundColor : Colors.white,
        title: Text(
          'Rename Shortcut',
          style: AppTypography.textTheme.titleLarge?.copyWith(
            // White text in dark mode
            color: isDarkMode ? Colors.white : null,
          ),
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Shortcut Name',
            // Theme-aware border and text colors
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.blue, width: 2),
            ),
            // Theme-aware text styles
            labelStyle: TextStyle(
              color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
            ),
          ),
          style: TextStyle(
            // White text in dark mode
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
          maxLength: 15,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'CANCEL',
              style: AppTypography.textTheme.labelLarge?.copyWith(
                color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
              ),
            ),
          ),
          ElevatedButton(
            // Theme-aware button styling
            style: ElevatedButton.styleFrom(
              backgroundColor: isDarkMode
                  ? AppTheme.darkTheme.colorScheme.primary
                  : Colors.blue,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              // In a real implementation, you would update the shortcut name
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Rename functionality will be implemented soon'),
                  // Theme-aware background
                  backgroundColor: isDarkMode ? Colors.grey[800] : null,
                ),
              );
            },
            child: Text(
              'SAVE',
              style: AppTypography.textTheme.labelLarge?.copyWith(
                color: Colors.white,
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