/// Form validation rules, shared by the login and register pages.
///
/// Flutter's `TextFormField` expects a validator with this exact shape:
/// take the current text, return `null` if it is acceptable, or return an
/// error message `String` to display under the field. Returning null means
/// "no error" — it reads backwards at first, but that's the contract.
///
/// These live in `core/utils` so the email rule is written once. Two copies of
/// a regex in two files is two chances to fix a bug in only one of them.
abstract final class Validators {
  /// Matches `something@something.something`.
  ///
  /// Deliberately loose. Perfectly validating an email address with a regex is
  /// famously impossible, and being strict mostly rejects real addresses. This
  /// catches the honest typos (missing `@`, missing domain); the only real
  /// proof an address works is sending mail to it.
  static final RegExp _emailPattern = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

  /// Rejects empty or whitespace-only input.
  ///
  /// [fieldName] is folded into the message so one method serves every field:
  /// `required(value, 'Name')` produces "Name is required".
  static String? required(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Checks the field isn't empty, then that it looks like an email.
  static String? email(String? value) {
    final emptyError = required(value, 'Email');
    if (emptyError != null) return emptyError;

    if (!_emailPattern.hasMatch(value!.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  /// Checks the field isn't empty, then that it meets Firebase's minimum
  /// length of 6 characters.
  ///
  /// Firebase would reject a short password anyway, but only after a network
  /// round trip and with a less friendly message. Catching it on the device is
  /// instant and free.
  static String? password(String? value) {
    final emptyError = required(value, 'Password');
    if (emptyError != null) return emptyError;

    if (value!.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }
}
