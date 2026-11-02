import 'package:google_sign_in/google_sign_in.dart';

import '../config.dart';
import '../db/repository.dart' show AppException;

/// What we keep from the Google account.
class GoogleProfile {
  const GoogleProfile(
      {required this.id, required this.email, required this.name});
  final String id; // stable Google account id
  final String email;
  final String name;
}

/// Thin wrapper around google_sign_in (v7 API).
/// Needs internet only at the moment of signing in.
class GoogleAuthService {
  GoogleAuthService._();

  static bool _initialised = false;

  static bool get isConfigured => !kGoogleWebClientId.startsWith('PASTE');

  static Future<void> _init() async {
    if (_initialised) return;
    await GoogleSignIn.instance.initialize(serverClientId: kGoogleWebClientId);
    _initialised = true;
  }

  static Future<GoogleProfile> signIn() async {
    if (!isConfigured) {
      throw AppException(
          'Google sign-in is not set up yet. Add your Web client ID in lib/config.dart.');
    }
    try {
      await _init();
      final account = await GoogleSignIn.instance.authenticate();
      return GoogleProfile(
        id: account.id,
        email: account.email,
        name: account.displayName ?? '',
      );
    } on GoogleSignInException catch (e) {
      // Android also reports some setup mistakes (wrong SHA-1, wrong client
      // ID) as "canceled", so the message mentions both.
      if (e.code.name == 'canceled') {
        throw AppException(
            'Google sign-in was cancelled. If you did not cancel it, check the SHA-1 and client ID setup.');
      }
      throw AppException('Google sign-in failed (${e.code.name}).');
    } catch (_) {
      throw AppException(
          'Google sign-in failed. Check your internet connection and the setup steps.');
    }
  }

  /// Never throws: logging out must work even when offline.
  static Future<void> signOut() async {
    if (!isConfigured) return;
    try {
      await _init();
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }
}
