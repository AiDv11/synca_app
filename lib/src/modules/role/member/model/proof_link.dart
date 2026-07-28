import 'package:url_launcher/url_launcher.dart';

/// Checking, tidying and opening a proof-of-work link.
///
/// Kept in the member module because that is the only place proof is captured
/// today. Move it to `core/utils` the day the leader module needs to open the
/// same links from a review screen.
///
/// Proof is deliberately just a URL. Synca does not host files — a student's
/// work already lives in a Google Doc, a Figma file or a GitHub commit, and
/// asking them to upload a copy would create a second version that immediately
/// goes stale. A link always points at the current state of the work.
abstract final class ProofLink {
  /// Turns what the member typed into something storable, or null if it is not
  /// a usable link.
  ///
  /// Returns null for two different reasons — empty input and invalid input —
  /// which is why callers should check [isValid] first when they need to tell
  /// the two apart. Empty is fine; proof is optional.
  ///
  /// The scheme is added when it is missing, because people type `docs.google
  /// .com/...` far more often than they type the `https://` in front of it.
  /// Storing it without a scheme would break `Uri.parse` later, at the point of
  /// opening, where the failure is much harder to explain.
  static String? normalise(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final withScheme = _hasScheme(trimmed) ? trimmed : 'https://$trimmed';

    final uri = Uri.tryParse(withScheme);
    if (uri == null || !_looksLikeWebAddress(uri)) return null;

    return uri.toString();
  }

  /// Is this something we are willing to store as proof?
  ///
  /// Empty counts as valid. The field is optional, so "nothing typed" is not an
  /// error the member should be shouted at for — it just means no proof yet.
  static bool isValid(String raw) {
    return raw.trim().isEmpty || normalise(raw) != null;
  }

  /// Does this task actually carry proof?
  ///
  /// Not the same question as `proofUrl != null`, and every reader must ask it
  /// this way instead. Removing proof writes an **empty string** rather than
  /// deleting the field, so a task with no evidence can hold `null` (never had
  /// any) or `''` (had some, removed). A plain null check treats the second as
  /// proof that exists, which paints an empty link chip on the card and an
  /// unearned "Proof uploaded" row on the timeline.
  ///
  /// One helper rather than `?.isNotEmpty ?? false` at each call site, so the
  /// two representations are collapsed in exactly one place and a third reader
  /// added later cannot get it wrong.
  static bool hasProof(String? url) => url != null && url.trim().isNotEmpty;

  /// Opens [url] in the browser. True if the handoff worked.
  ///
  /// `LaunchMode.externalApplication` sends the link to the real browser rather
  /// than an in-app web view. That matters here: the target is usually a Google
  /// Doc or GitHub, where the member is already signed in. An in-app view has
  /// its own cookie jar, so it would show a login wall for a document they can
  /// already read.
  ///
  /// Returns false rather than throwing when there is nothing to handle the
  /// link, so the caller can show a message instead of crashing.
  static Future<bool> open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;

    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// A short version for display, e.g. `docs.google.com`.
  ///
  /// A full proof URL can be two hundred characters of document id. Showing the
  /// host tells the member what kind of thing they are about to open, which is
  /// the useful part, and fits on one line.
  static String displayLabel(String url) {
    final host = Uri.tryParse(url)?.host ?? '';
    if (host.isEmpty) return url;

    // `www.` is noise — every reader mentally strips it anyway.
    return host.startsWith('www.') ? host.substring(4) : host;
  }

  static bool _hasScheme(String value) =>
      value.startsWith('http://') || value.startsWith('https://');

  /// A real web address needs a host, and a host needs a dot in it.
  ///
  /// The dot check is what rejects `https://mywork`, which parses perfectly
  /// well as a URI but is not somewhere a marker can go and look. This is
  /// deliberately loose — the goal is catching typos, not policing which sites
  /// are acceptable evidence.
  static bool _looksLikeWebAddress(Uri uri) {
    return (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.contains('.') &&
        !uri.host.startsWith('.') &&
        !uri.host.endsWith('.');
  }
}
