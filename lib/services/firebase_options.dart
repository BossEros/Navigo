import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'you can reconfigure this by running the FlutterFire CLI again.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBocnJgrDPDhhMcAf6CUoi-lXVLkIILdrc',
    appId: '1:708119345203:android:c1705ab50c12e6b1950b46',
    messagingSenderId: '708119345203',
    projectId: 'project-navigo',
    storageBucket: 'project-navigo.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDiDjKRyUbNGdhsqwaodCmDE6shp8_DDVc',
    appId: '1:708119345203:ios:3bd4f31a58f78128950b46',
    messagingSenderId: '708119345203',
    projectId: 'project-navigo',
    storageBucket: 'project-navigo.firebasestorage.app',
    androidClientId: '708119345203-k0l9q920h7ukiim9cs421u10cboq6jgk.apps.googleusercontent.com',
    iosClientId: '708119345203-9brggkqq6s0fq5p3vnil5hopso0cadb4.apps.googleusercontent.com',
    iosBundleId: 'com.example.projectNavigo',
  );
}
