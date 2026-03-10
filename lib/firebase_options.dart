// File generated manually via Firebase CLI configurations to bypass flutterfire issues.
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
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the flutterfire cli.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the flutterfire cli.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC0zJJ488zNCBcy1ndWob5bx41gGbPnU5k',
    appId: '1:54223815037:web:429f2b6bb0e6cf410b4c14',
    messagingSenderId: '54223815037',
    projectId: 'halabessa-card-game1',
    authDomain: 'halabessa-card-game1.firebaseapp.com',
    storageBucket: 'halabessa-card-game1.firebasestorage.app',
    measurementId: 'G-P42HX4EXYW',
    databaseURL: 'https://halabessa-card-game1-default-rtdb.firebaseio.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBhzPD2BYU_jtIXClvp3WrRu818oJuMVjk',
    appId: '1:54223815037:android:a5de8787c5ee81600b4c14',
    messagingSenderId: '54223815037',
    projectId: 'halabessa-card-game1',
    storageBucket: 'halabessa-card-game1.firebasestorage.app',
    databaseURL: 'https://halabessa-card-game1-default-rtdb.firebaseio.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAIuSJXCHGPw3WT1iZ4OIIhE_-QzzfwEFk',
    appId: '1:54223815037:ios:816ca98e5695208b0b4c14',
    messagingSenderId: '54223815037',
    projectId: 'halabessa-card-game1',
    storageBucket: 'halabessa-card-game1.firebasestorage.app',
    iosBundleId: 'com.halabessa.game',
    databaseURL: 'https://halabessa-card-game1-default-rtdb.firebaseio.com',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAIuSJXCHGPw3WT1iZ4OIIhE_-QzzfwEFk',
    appId: '1:54223815037:ios:816ca98e5695208b0b4c14',
    messagingSenderId: '54223815037',
    projectId: 'halabessa-card-game1',
    storageBucket: 'halabessa-card-game1.firebasestorage.app',
    iosBundleId: 'com.halabessa.game',
    databaseURL: 'https://halabessa-card-game1-default-rtdb.firebaseio.com',
  );
}
