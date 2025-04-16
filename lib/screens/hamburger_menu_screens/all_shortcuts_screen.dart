import 'package:flutter/material.dart';
import 'package:project_navigo/themes/app_typography.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:project_navigo/services/quick_access_shortcut_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'dart:ui' show lerpDouble;

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

    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Shortcut deleted',
          style: AppTypography.textTheme.bodyMedium?.copyWith(color: Colors.white),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black87,
        action: SnackBarAction(
          label: 'UNDO',
          textColor: Colors.white,
          onPressed: () {
            // In a real app, you'd handle undo here
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Restore feature coming soon'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get the bottom padding needed for the system navigation bar
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Quick Access Shortcuts',
          style: AppTypography.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        // Set bottom to false as we'll handle bottom padding manually
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Description text
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Text(
                'Tap to navigate or edit your favorite destinations',
                style: AppTypography.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ),

            // Main content - shortcuts or empty state
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _shortcuts.isEmpty
                ? _buildEmptyState()
                : _buildShortcutsContent(),

            // Add new shortcut button (persistent at bottom with safe area padding)
            _buildAddButton(bottomPadding),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmarks_outlined,
              size: 72,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'No shortcuts added yet',
              style: AppTypography.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add shortcuts for your frequent destinations',
              style: AppTypography.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShortcutsContent() {
    return Expanded(  // Wrap the entire content in Expanded to provide bounded height
      child: Column(
        children: [
          // Help text for edit feature
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tap to navigate, drag to reorder, or use the edit button for more options',
                      style: AppTypography.textTheme.bodyMedium?.copyWith(
                        color: Colors.blue[800],
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
              // Add the proxyDecorator for better visual feedback
              proxyDecorator: (child, index, animation) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (BuildContext context, Widget? child) {
                    final double animValue = Curves.easeInOut.transform(animation.value);
                    final double elevation = lerpDouble(0, 6, animValue)!;
                    return Material(
                      elevation: elevation,
                      color: Colors.transparent,
                      shadowColor: Colors.black.withOpacity(0.2),
                      child: child,
                    );
                  },
                  child: child,
                );
              },
              itemBuilder: (context, index) {
                final shortcut = _shortcuts[index];
                return _buildReorderableShortcutItem(shortcut, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReorderableShortcutItem(dynamic shortcut, int index) {
    return Container(
      key: ValueKey(shortcut.id),  // Key is required for ReorderableListView
      margin: const EdgeInsets.only(bottom: 12),
      child: Stack(
        children: [
          // Main shortcut card
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onShortcutTap(shortcut);
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      // Drag handle icon for reordering
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
                              color: Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Icon(
                              Icons.drag_handle,
                              color: Colors.grey[600],
                              size: 16,
                            ),
                          ),
                        ),
                      ),

                      // Shortcut icon
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Image.asset(
                            shortcut.iconPath,
                            width: 28,
                            height: 28,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.star,
                                color: Colors.blue,
                                size: 24,
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Shortcut label and address preview
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              shortcut.label,
                              style: AppTypography.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 4),
                            Text(
                              shortcut.address ?? 'Tap to navigate',
                              style: AppTypography.textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // Edit button (integrated into the row)
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _showEditOptions(shortcut),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Icon(
                              Icons.edit,
                              size: 20,
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

    void _onReorder(int oldIndex, int newIndex) {
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

    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Shortcut order updated',
          style: AppTypography.textTheme.bodyMedium?.copyWith(color: Colors.white),
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Widget _buildShortcutItem(dynamic shortcut, Key key) {
    return Container(
      key: key,  // Important for ReorderableListView
      margin: const EdgeInsets.only(bottom: 12),
      child: Stack(
        children: [
          // Main shortcut card
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onShortcutTap(shortcut);
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      // Drag handle icon
                      Icon(
                        Icons.drag_handle,
                        color: Colors.grey[400],
                        size: 24,
                      ),
                      SizedBox(width: 12),

                      // Shortcut icon with error handling
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          // Use Icon as the default and only attempt to load the asset if it's available
                          child: _buildSafeIcon(shortcut.iconPath),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Shortcut details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              shortcut.label,
                              style: AppTypography.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 4),
                            Text(
                              shortcut.address ?? 'Tap to navigate',
                              style: AppTypography.textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // Edit button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _showEditOptions(shortcut),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Icon(
                              Icons.edit,
                              size: 20,
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

  // Helper method to safely load icons with fallbacks
  Widget _buildSafeIcon(String iconPath) {
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
        errorBuilder: (context, error, stackTrace) {
          // On error, use the icon
          return Icon(
            iconData,
            color: Colors.blue,
            size: 24,
          );
        },
      ),
    );
  }

  Widget _buildAddButton([double bottomPadding = 0]) {
    return Container(
      width: double.infinity,
      // Add additional padding at the bottom to respect system navigation
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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

  void _showEditOptions(dynamic shortcut) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header with shortcut name
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                shortcut.label,
                style: AppTypography.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // Options
            _buildOptionTile(
              icon: Icons.drive_file_rename_outline,
              title: 'Rename Shortcut',
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog(shortcut);
              },
            ),

            _buildOptionTile(
              icon: Icons.delete_outline,
              title: 'Delete Shortcut',
              textColor: Colors.red,
              iconColor: Colors.red,
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(shortcut);
              },
            ),

            const SizedBox(height: 8),

            // Cancel button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Cancel',
                  style: AppTypography.textTheme.labelLarge?.copyWith(
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? textColor,
    Color? iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.grey[50],
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
                color: textColor ?? Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(dynamic shortcut) {
    final TextEditingController controller = TextEditingController(text: shortcut.label);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Rename Shortcut',
          style: AppTypography.textTheme.titleLarge,
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Shortcut Name',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          maxLength: 15,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'CANCEL',
              style: AppTypography.textTheme.labelLarge,
            ),
          ),
          ElevatedButton(
            onPressed: () {
              // In a real implementation, you would update the shortcut name
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Rename functionality will be implemented soon'),
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

  void _showDeleteConfirmation(dynamic shortcut) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Shortcut?',
          style: AppTypography.textTheme.titleLarge,
        ),
        content: Text(
          'Are you sure you want to delete "${shortcut.label}"? This action cannot be undone.',
          style: AppTypography.textTheme.bodyLarge,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'CANCEL',
              style: AppTypography.textTheme.labelLarge,
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