import 'package:cloud_firestore/cloud_firestore.dart';

/// Turns a Firestore stream failure into a sentence a student can read.
///
/// Copied into the leader module rather than imported from the member module:
/// role folders must not depend on each other, and the wording is short enough
/// that a shared file in `common/` isn't worth asking a teammate to add.
///
/// [subject] is dropped into the fallback — pass `'tasks'` or `'members'`,
/// lower case and unpunctuated.
String describeLoadError(Object error, {required String subject}) {
  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
        return "You don't have access to this.";
      case 'unavailable':
      case 'deadline-exceeded':
      case 'network-request-failed':
        return 'Connection problem. Check your internet and try again.';
      // First run of `users.where(groupId).orderBy(name)` without the composite
      // index lands here. The console link creates it; until then the Members
      // tab and the member-count card would otherwise show a vague failure.
      case 'failed-precondition':
        return 'This screen needs a database index that is still building. '
            'Try again in a minute.';
    }
  }

  return "Couldn't load your $subject. Please try again.";
}
