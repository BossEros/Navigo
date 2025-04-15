import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:project_navigo/models/quick_access_shortcut_model.dart';
import 'package:project_navigo/services/utils/firebase_utils.dart';

class QuickAccessShortcutService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseUtils _firebaseUtils = FirebaseUtils();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get quick access shortcuts for the current user
  Future<List<QuickAccessShortcutModel>> getUserShortcuts() async {
    return _firebaseUtils.safeOperation(() async {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No user logged in');
      }

      final querySnapshot = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('quick_access_shortcuts')
          .orderBy('created_at')
          .get();

      return querySnapshot.docs
          .map((doc) => QuickAccessShortcutModel.fromFirestore(doc))
          .toList();
    }, 'getUserShortcuts');
  }

  // Add a new quick access shortcut
  Future<String> addShortcut({
    required String iconPath,
    required String label,
    required double lat,
    required double lng,
    required String address,
    String? placeId,
  }) async {
    return _firebaseUtils.safeOperation(() async {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No user logged in');
      }

      // Reference to the collection
      final shortcutsRef = _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('quick_access_shortcuts');

      // Create new shortcut data
      final Map<String, dynamic> shortcutData = {
        'icon_path': iconPath,
        'label': label,
        'lat': lat,
        'lng': lng,
        'address': address,
        'place_id': placeId,
        'created_at': FieldValue.serverTimestamp(),
      };

      // Add to Firestore
      final docRef = await shortcutsRef.add(shortcutData);
      return docRef.id;
    }, 'addShortcut');
  }

  // Save a list of shortcuts (works with the existing UI class)
  Future<void> saveShortcuts(List<dynamic> uiShortcuts) async {
    return _firebaseUtils.safeOperation(() async {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No user logged in');
      }

      // Reference to the collection
      final shortcutsRef = _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('quick_access_shortcuts');

      // Delete existing shortcuts
      final existingShortcuts = await shortcutsRef.get();
      final batch = _firestore.batch();

      for (var doc in existingShortcuts.docs) {
        batch.delete(doc.reference);
      }

      // Add new shortcuts
      for (var shortcut in uiShortcuts) {
        final docRef = shortcutsRef.doc();
        batch.set(docRef, {
          'icon_path': shortcut.iconPath,
          'label': shortcut.label,
          'lat': shortcut.location.latitude,
          'lng': shortcut.location.longitude,
          'address': shortcut.address,
          'place_id': shortcut.placeId,
          'created_at': FieldValue.serverTimestamp(),
        });
      }

      // Commit the batch
      await batch.commit();
    }, 'saveShortcuts');
  }

  // Delete a specific shortcut
  Future<void> deleteShortcut(String shortcutId) async {
    return _firebaseUtils.safeOperation(() async {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No user logged in');
      }

      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('quick_access_shortcuts')
          .doc(shortcutId)
          .delete();
    }, 'deleteShortcut');
  }
}