import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FirebaseSmsService {
  /// Triggers real Firebase Phone Authentication SMS dispatch
  static Future<void> sendSmsOtp({
    required String phoneNumber,
    required BuildContext context,
    required Function(String verificationId) onCodeSent,
    required Function() onAutoVerified,
    required Function(String error) onError,
  }) async {
    try {
      final FirebaseAuth auth = FirebaseAuth.instance;

      await auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Automatic SMS Code retrieval (common on Android devices)
          try {
            await auth.signInWithCredential(credential);
            onAutoVerified();
          } catch (_) {
            onAutoVerified();
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('Firebase Phone Auth Failed: ${e.code} - ${e.message}');
          onError(e.message ?? e.code);
        },
        codeSent: (String verificationId, int? resendToken) {
          debugPrint('Firebase SMS Code Sent to $phoneNumber! VerificationId: $verificationId');
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint('Firebase Code Auto Retrieval Timeout: $verificationId');
        },
      );
    } catch (e) {
      onError(e.toString());
    }
  }

  /// Validates the 6-digit SMS code entered by the user
  static Future<bool> verifySmsCode({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final AuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode.trim(),
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      return true;
    } catch (e) {
      debugPrint('Firebase SMS Verification Failed: $e');
      return false;
    }
  }
}
