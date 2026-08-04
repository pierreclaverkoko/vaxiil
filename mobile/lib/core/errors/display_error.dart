import 'package:vaxiil_mobile/core/errors/failures.dart';

/// Sanitize and truncate API / gateway error strings for UI banners.
const int kDisplayErrorMaxLength = 200;

bool _looksLikeHtml(String text) {
  final t = text.trim().toLowerCase();
  if (t.startsWith('<!doctype') || t.startsWith('<html')) {
    return true;
  }
  final tags = RegExp(r'</?[a-z][\w:-]*\b[^>]*>', caseSensitive: false)
      .allMatches(text);
  return tags.length >= 2;
}

String sanitizeErrorMessage(String raw) {
  var text = raw;
  if (_looksLikeHtml(text)) {
    text = text
        .replaceAll(
          RegExp(r'<script[\s\S]*?</script>', caseSensitive: false),
          ' ',
        )
        .replaceAll(
          RegExp(r'<style[\s\S]*?</style>', caseSensitive: false),
          ' ',
        )
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
  }
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}

({String display, String full}) truncateErrorMessage(
  String raw, {
  int max = kDisplayErrorMaxLength,
}) {
  final full = sanitizeErrorMessage(raw);
  if (full.length <= max) {
    return (display: full, full: full);
  }
  final cut = full.substring(0, max - 1).trimRight();
  return (display: '$cut…', full: full);
}

String displayErrorMessage(Object error) {
  if (error is Failure) {
    return truncateErrorMessage(error.message).display;
  }
  return truncateErrorMessage(error.toString()).display;
}
