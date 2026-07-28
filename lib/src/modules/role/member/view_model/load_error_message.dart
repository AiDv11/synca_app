import 'package:cloud_firestore/cloud_firestore.dart';

/// Turns whatever a Firestore stream threw into a sentence a student can read.
///
/// One shared function rather than a copy in each ViewModel. These strings are
/// user-facing copy: two copies would eventually be reworded separately, and
/// the Tasks tab would start apologising differently from the Timeline for the
/// same underlying failure.
///
/// Nothing here reveals a Firebase error code, an exception type or a stack
/// trace. Those go to `debugPrint` at the call site, where the developer sees
/// them in `flutter run` and the student never does. A raw code on screen tells
/// a marker nothing and tells a student less.
///
/// [subject] is the thing that failed to load, dropped into the fallback
/// message — pass `'tasks'` or `'timeline'`, lower case and unpunctuated.
String describeLoadError(Object error, {required String subject}) {
  if (error is FirebaseException) {
    switch (error.code) {
      // The security rules refused the read. Almost always means the query is
      // asking for something outside the user's group.
      case 'permission-denied':
        return "You don't have access to this.";

      // Firestore reports a dead or unreachable backend as `unavailable`, and
      // a request that ran out of time as `deadline-exceeded`. Both mean the
      // same thing to a student on campus wifi.
      // `network-request-failed` comes from the Auth SDK rather than Firestore,
      // but can surface on the same path, so it is folded in here.
      case 'unavailable':
      case 'deadline-exceeded':
      case 'network-request-failed':
        return 'Connection problem. Check your internet and try again.';
    }
  }

  // Everything else, including non-Firebase exceptions. Deliberately vague:
  // if we cannot say something specific and true, guessing is worse than
  // admitting we do not know. The Retry button is the useful part.
  return "Couldn't load your $subject. Please try again.";
}
