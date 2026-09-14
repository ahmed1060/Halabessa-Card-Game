import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ErrorHandler {
  static String getAuthErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'auth_invalid_email'.tr();
        case 'user-disabled':
          return 'auth_user_disabled'.tr();
        case 'user-not-found':
          return 'auth_user_not_found'.tr();
        case 'wrong-password':
          return 'auth_wrong_password'.tr();
        case 'email-already-in-use':
          return 'auth_email_already_in_use'.tr();
        case 'weak-password':
          return 'auth_weak_password'.tr();
        case 'operation-not-allowed':
          return 'auth_operation_not_allowed'.tr();
        case 'invalid-credential':
          return 'auth_invalid_credential'.tr();
        case 'too-many-requests':
          return 'auth_too_many_requests'.tr();
        case 'network-request-failed':
          return 'auth_network_error'.tr();
        default:
          return getFirebaseErrorMessage(error);
      }
    }
    
    if (error is FirebaseException) {
      return getFirebaseErrorMessage(error);
    }
    
    final errorStr = error.toString();
    if (errorStr.contains('room_expired')) {
      return 'room_expired'.tr();
    }
    if (errorStr.contains('room_is_full') || errorStr.contains('room-full')) {
      return 'error_room_full'.tr();
    }
    if (errorStr.contains('room_not_found') || errorStr.contains('not-found')) {
      return 'error_not_found'.tr();
    }
    
    // Fallback for non-firebase errors
    return 'error_general'.tr(args: [error.toString()]);
  }

  static String getFirebaseErrorMessage(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'error_permission_denied'.tr();
      case 'unavailable':
        return 'error_service_unavailable'.tr();
      case 'not-found':
        return 'error_not_found'.tr();
      case 'room-full':
        return 'error_room_full'.tr();
      default:
        return 'error_general'.tr(args: [error.message ?? error.code]);
    }
  }
}
