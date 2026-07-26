import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../entity/app_user.dart';

/// Everything to do with signing in, signing up and signing out.
///
/// This is the only place in the auth module that talks to Firebase directly.
/// ViewModels call these methods; widgets never do. That separation is the
/// point of MVVM — swap Firebase for something else later and only this file
/// changes.
///
/// None of these methods catch errors. Firebase throws [FirebaseAuthException]
/// (with a `code` like `'email-already-in-use'` or `'wrong-password'`), and the
/// ViewModel is the right layer to catch that and turn it into a message the
/// user can read. A service that swallows errors leaves the UI unable to tell
/// success from failure.
class AuthService {
  /// The two Firebase objects are constructor parameters with defaults rather
  /// than being hardcoded inside the methods. Normal app code just writes
  /// `AuthService()` and gets the real Firebase; a test can pass in fakes.
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  /// Shorthand for the `users` collection so the name is spelled once.
  /// A typo in a collection name doesn't error — it silently reads an empty
  /// collection, which is a miserable bug to track down.
  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  /// Creates a new account, in two steps.
  ///
  /// 1. Firebase Auth creates the credentials and returns a `uid`.
  /// 2. We write the profile (name, role) to `users/{uid}` in Firestore.
  ///
  /// Both steps are needed because Firebase Auth stores no custom fields — it
  /// knows the email and password, but not that this person is a group leader.
  ///
  /// `async` + `await`: talking to Firebase goes over the network, which takes
  /// time. `Future<AppUser>` means "an AppUser, eventually". `await` pauses
  /// this method until the network call finishes, without freezing the UI.
  ///
  /// Note the caveat: if step 1 succeeds and step 2 fails (no connection, for
  /// example), the account exists with no profile. [getCurrentUser] returns
  /// null in that case, so the UI can send them back to complete registration.
  Future<AppUser> register({
    required String email,
    required String password,
    required String name,
    required UserRole role,
  }) async {
    final cleanEmail = email.trim();

    final credential = await _auth.createUserWithEmailAndPassword(
      email: cleanEmail,
      password: password,
    );

    // Firebase types `user` as nullable, but it is never null immediately
    // after a successful creation — `!` asserts that.
    final uid = credential.user!.uid;

    final appUser = AppUser(
      uid: uid,
      email: cleanEmail,
      name: name.trim(),
      role: role,
    );

    // `.doc(uid)` names the document after the user's uid instead of letting
    // Firestore generate a random id. That way a profile can always be fetched
    // directly from a uid — no query needed.
    await _users.doc(uid).set(appUser.toMap());

    return appUser;
  }

  /// Signs an existing user in, then loads their profile.
  ///
  /// Firebase Auth alone would only tell us "these credentials are valid". We
  /// need the role to know which home screen to show, and that lives in
  /// Firestore, so we fetch it straight after.
  ///
  /// Returns null if the credentials were fine but no profile document exists
  /// (see the caveat on [register]).
  Future<AppUser?> login({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    return getCurrentUser();
  }

  /// Signs the current user out.
  ///
  /// Firebase keeps the session on the device between app launches, so without
  /// this the user would stay logged in forever. After this call
  /// [getCurrentUser] returns null.
  Future<void> logout() => _auth.signOut();

  /// The signed-in user's full profile, or null if nobody is signed in.
  ///
  /// `_auth.currentUser` is instant and local — no network call — because
  /// Firebase caches the session on the device. Only the Firestore read that
  /// follows touches the network.
  ///
  /// Returns null in two different situations: nobody is signed in, or the
  /// credentials exist but the profile document doesn't. Both mean "we have no
  /// usable user", so the UI treats them the same and shows the login screen.
  Future<AppUser?> getCurrentUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;

    final snapshot = await _users.doc(firebaseUser.uid).get();

    // `.data()` is null when the document doesn't exist.
    final data = snapshot.data();
    if (data == null) return null;

    return AppUser.fromMap(data);
  }
}
