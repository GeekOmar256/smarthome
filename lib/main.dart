import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'app.dart';
import 'overlay/overlay_entry.dart';

/// Normal app entry point.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: TeacherRecorderApp()));
}

/// Separate entry point used by flutter_overlay_window.
/// Annotated so the Dart VM keeps it even in tree-shaken release builds.
@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OverlayApp());
}
