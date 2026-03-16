// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

Future<bool> tryReloadApp() async {
  html.window.location.reload();
  return true;
}
