import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../services/user_provider.dart';

class AppInitializer extends StatefulWidget {
  final Widget child;

  const AppInitializer({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  _AppInitializerState createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // Use post-frame callback to ensure widget tree is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeUserData();
    });
  }

  Future<void> _initializeUserData() async {
    if (!mounted) return;

    try {
      // Access the UserProvider and load data if user is logged in
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.loadUserData();
      print('User data initialized at app startup');
    } catch (e) {
      print('Error initializing user data: $e');
    }

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Just return the child - splash screen will handle visual loading state
    return widget.child;
  }
}