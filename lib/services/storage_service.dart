import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:project_navigo/utils/firebase_utils.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseUtils _firebaseUtils = FirebaseUtils();

  /// Upload profile image to Firebase Storage
  Future<Map<String, String>> uploadProfileImage(String userId, File imageFile) async {
    return _firebaseUtils.safeOperation(() async {
      // Create a unique filename using timestamp
      final String extension = path.extension(imageFile.path);
      final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}$extension';
      final storagePath = 'users/$userId/profile/$fileName';

      // Reference to the file location
      final storageRef = _storage.ref().child(storagePath);

      // Upload the file
      final uploadTask = storageRef.putFile(
        imageFile,
        SettableMetadata(
          contentType: 'image/${extension.replaceFirst('.', '')}',
          customMetadata: {
            'userId': userId,
            'uploadDate': DateTime.now().toIso8601String(),
          },
        ),
      );

      // Monitor upload progress if needed
      // uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
      //   final progress = snapshot.bytesTransferred / snapshot.totalBytes;
      //   print('Upload progress: $progress');
      // });

      // Get the download URL
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      return {
        'url': downloadUrl,
        'path': storagePath,
      };
    }, 'uploadProfileImage');
  }

  /// Delete profile image from Firebase Storage
  // In lib/services/storage_service.dart
  Future<void> deleteProfileImage(String? storagePath) async {
    // Skip if path is null or empty
    if (storagePath == null || storagePath.isEmpty) {
      print('No previous profile image to delete');
      return;
    }

    return _firebaseUtils.safeOperation(() async {
      try {
        print('Attempting to delete image at path: $storagePath');
        final ref = _storage.ref().child(storagePath);
        await ref.delete();
        print('Successfully deleted previous profile image');
      } catch (e) {
        print('Error deleting profile image: $e');
        // Don't throw if image doesn't exist - just log it
        if (e is FirebaseException && e.code == 'object-not-found') {
          print('Image not found - may have been deleted already');
        } else {
          // For other errors, we might want to rethrow
          rethrow;
        }
      }
    }, 'deleteProfileImage');
  }
}