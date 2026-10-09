import 'dart:convert';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/auth/data/repositories/firebase_auth_repository.dart';
import 'supabase_backend_service.dart';

/// A status-only capability. It cannot sign in, read a profile or delete a
/// different account. Save before submitting so a lost response is recoverable.
class DeletionReceipt {
  final String uid;
  final String receipt;
  const DeletionReceipt(this.uid, this.receipt);
  static const preferenceKey = 'account_deletion_receipt_v1';
  static Future<DeletionReceipt?> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(
      preferenceKey,
    );
    if (raw == null) return null;
    try {
      final value = jsonDecode(raw) as Map<String, dynamic>;
      final uid = value['uid'];
      final receipt = value['receipt'];
      if (uid is String &&
          uid.isNotEmpty &&
          receipt is String &&
          RegExp(r'^[a-f0-9]{64}$').hasMatch(receipt)) {
        return DeletionReceipt(uid, receipt);
      }
    } catch (_) {
      /* Corrupt data is not authority to delete anything. */
    }
    return null;
  }

  static Future<DeletionReceipt> prepare(String uid) async {
    final existing = await load();
    if (existing != null) {
      if (existing.uid != uid) {
        throw const SupabaseBackendException('deletion_receipt_conflict');
      }
      return existing;
    }
    final random = Random.secure();
    final receipt = List.generate(
      32,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final saved = await (await SharedPreferences.getInstance()).setString(
      preferenceKey,
      jsonEncode({'uid': uid, 'receipt': receipt}),
    );
    if (!saved) {
      throw const SupabaseBackendException('deletion_receipt_not_saved');
    }
    return DeletionReceipt(uid, receipt);
  }

  static Future<void> forget() async {
    await (await SharedPreferences.getInstance()).remove(preferenceKey);
  }
}

class AccountDeletionService {
  static final _endpoint = Uri.parse(
    'https://jmlipglfgmuyegoroepu.supabase.co/functions/v1/halabessa-api',
  );
  static Future<Map<String, dynamic>> _post(
    Map<String, dynamic> body, {
    String? token,
  }) async {
    final response = await http
        .post(
          _endpoint,
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SupabaseBackendException(
        data['error'] as String? ?? 'backend_unavailable',
      );
    }
    return data;
  }

  static Future<Map<String, dynamic>> status(DeletionReceipt receipt) =>
      _post({'action': 'accountDeletionStatus', 'receipt': receipt.receipt});

  // Reauthentication only: never sign in/link or switch UID for deletion.
  static Future<Map<String, String>> reauthenticate(
    User user,
    String provider, {
    String? password,
  }) async {
    UserCredential? result;
    switch (provider) {
      case 'guest':
        if (!user.isAnonymous || user.providerData.isNotEmpty) {
          throw const SupabaseBackendException('requires_recent_login');
        }
        break;
      case 'password':
        if (user.email == null || password == null || password.isEmpty) {
          throw const SupabaseBackendException('requires_recent_login');
        }
        result = await user.reauthenticateWithCredential(
          EmailAuthProvider.credential(email: user.email!, password: password),
        );
        break;
      case 'google.com':
        if (kIsWeb) {
          result = await user.reauthenticateWithPopup(GoogleAuthProvider());
        } else {
          final account = await GoogleSignIn(
            clientId: defaultTargetPlatform == TargetPlatform.iOS
                ? FirebaseAuthRepository.googleIosClientId
                : null,
            serverClientId: FirebaseAuthRepository.googleWebClientId,
          ).signIn();
          if (account == null) {
            throw const SupabaseBackendException('reauthentication_cancelled');
          }
          final auth = await account.authentication;
          result = await user.reauthenticateWithCredential(
            GoogleAuthProvider.credential(
              idToken: auth.idToken,
              accessToken: auth.accessToken,
            ),
          );
        }
        break;
      case 'facebook.com':
        if (kIsWeb) {
          result = await user.reauthenticateWithPopup(FacebookAuthProvider());
        } else {
          final login = await FacebookAuth.instance.login();
          if (login.status != LoginStatus.success ||
              login.accessToken == null) {
            throw const SupabaseBackendException('reauthentication_cancelled');
          }
          result = await user.reauthenticateWithCredential(
            FacebookAuthProvider.credential(login.accessToken!.tokenString),
          );
        }
        break;
      case 'apple.com':
        result = kIsWeb
            ? await user.reauthenticateWithPopup(AppleAuthProvider())
            : await user.reauthenticateWithProvider(AppleAuthProvider());
        break;
      default:
        throw const SupabaseBackendException('unsupported_reauthentication');
    }
    if (FirebaseAuth.instance.currentUser?.uid != user.uid ||
        (result != null && result.user?.uid != user.uid)) {
      throw const SupabaseBackendException('deletion_account_changed');
    }
    final code = result?.additionalUserInfo?.authorizationCode;
    final credential = result?.credential;
    if (provider == 'apple.com') {
      if (code != null && code.isNotEmpty) {
        return {'appleToken': code, 'appleTokenType': 'CODE'};
      }
      if (credential is OAuthCredential &&
          credential.accessToken?.isNotEmpty == true) {
        return {
          'appleToken': credential.accessToken!,
          'appleTokenType': 'ACCESS_TOKEN',
        };
      }
      throw const SupabaseBackendException('apple_authorization_unavailable');
    }
    return {};
  }

  static Future<Map<String, dynamic>> submit(
    User user,
    Map<String, String> apple,
  ) async {
    if (FirebaseAuth.instance.currentUser?.uid != user.uid) {
      throw const SupabaseBackendException('deletion_account_changed');
    }
    final receipt = await DeletionReceipt.prepare(user.uid);
    final token = await user.getIdToken(true);
    if (token == null) throw const SupabaseBackendException('unauthenticated');
    try {
      return await _post({
        'action': 'requestAccountDeletion',
        'confirmation': 'DELETE MY ACCOUNT',
        'receipt': receipt.receipt,
        ...apple,
      }, token: token);
    } on SupabaseBackendException catch (error) {
      // These specific server rejections happen BEFORE creating a job. A
      // timeout/internal error is ambiguous: never discard its recovery key.
      if (const {
        'protected_account',
        'requires_recent_login',
        'deletion_target_forbidden',
        'deletion_confirmation_required',
      }.contains(error.code)) {
        await DeletionReceipt.forget();
      }
      rethrow;
    }
  }
}
