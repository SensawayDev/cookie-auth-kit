// ignore_for_file: deprecated_member_use

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

String? readCookieValue(String name) {
  final cookieHeader = html.document.cookie;
  if (cookieHeader == null || cookieHeader.isEmpty) {
    return null;
  }

  final prefix = '$name=';
  for (final part in cookieHeader.split(';')) {
    final cookie = part.trim();
    if (cookie.startsWith(prefix)) {
      return Uri.decodeComponent(cookie.substring(prefix.length));
    }
  }
  return null;
}
