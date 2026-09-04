import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (kDebugMode) {
    print('Handling background message: ${message.messageId}');
  }
}

class FirebaseService {
  FirebaseService._();

  static bool _initialized = false;
  static String? _fcmToken;

  static String? get fcmToken => _fcmToken;

  /// Initialize Firebase Core and Messaging safely
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Initialize Firebase App
      await Firebase.initializeApp();
      _initialized = true;
      if (kDebugMode) {
        print('[FirebaseService] Firebase Core initialized successfully.');
      }

      // Set background handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Request Push Notification Permissions
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        if (kDebugMode) {
          print('[FirebaseService] User granted notification permission');
        }
        await _retrieveFcmToken();
      } else if (kDebugMode) {
        print('[FirebaseService] User declined or has provisional notification permission: ${settings.authorizationStatus}');
      }

      // Foreground message listener
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (kDebugMode) {
          print('[FirebaseService] Received foreground message: ${message.notification?.title}');
        }
      });

      // Notification opened app listener
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (kDebugMode) {
          print('[FirebaseService] Notification opened app: ${message.data}');
        }
      });

    } catch (e) {
      if (kDebugMode) {
        print('[FirebaseService] Notice: Firebase initialization skipped/failed: $e');
        print('[FirebaseService] (Ensure google-services.json / GoogleService-Info.plist are added to your platform folders)');
      }
    }
  }

  static Future<void> _retrieveFcmToken() async {
    try {
      _fcmToken = await FirebaseMessaging.instance.getToken();
      if (kDebugMode) {
        print('[FirebaseService] FCM Token: $_fcmToken');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[FirebaseService] Failed to get FCM token: $e');
      }
    }
  }
}
