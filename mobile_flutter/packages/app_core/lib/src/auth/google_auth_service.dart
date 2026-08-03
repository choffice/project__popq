import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  GoogleAuthService({
    required String webClientId,
    FirebaseAuth? firebaseAuth,
  }) : _webClientId = webClientId,
        _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final String _webClientId;
  final FirebaseAuth _firebaseAuth;
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(serverClientId: _webClientId);
    _initialized = true;
  }

  Future<String> signInAndGetIdToken() async {
    await _ensureInitialized();

    final googleAccount = await GoogleSignIn.instance.authenticate();
    final googleAuth = googleAccount.authentication;

    if (googleAuth.idToken == null) {
      throw StateError('Google idToken을 받지 못했습니다.');
    }

    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );
    await _firebaseAuth.signInWithCredential(credential);

    return googleAuth.idToken!;
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    await GoogleSignIn.instance.signOut();
  }
}