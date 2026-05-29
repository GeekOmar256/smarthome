import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

/// Minimal app rendered by flutter_overlay_window in its own Flutter engine.
/// Communicates with the main engine only via FlutterOverlayWindow.shareData.
class OverlayApp extends StatelessWidget {
  const OverlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _OverlayButton(),
    );
  }
}

class _OverlayButton extends StatefulWidget {
  const _OverlayButton();

  @override
  State<_OverlayButton> createState() => _OverlayButtonState();
}

class _OverlayButtonState extends State<_OverlayButton> {
  bool _isRecording = false;
  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    // Listen for state updates pushed from the main engine.
    FlutterOverlayWindow.overlayListener.listen((data) {
      if (data is Map) {
        final action = data['action'] as String?;
        if (action == 'toggleCollapse') {
          setState(() => _collapsed = !_collapsed);
        } else if (action == 'recordingStarted') {
          setState(() => _isRecording = true);
        } else if (action == 'recordingStopped') {
          setState(() => _isRecording = false);
        }
      }
    });
  }

  void _onTap() {
    FlutterOverlayWindow.shareData({
      'action': _isRecording ? 'stop' : 'start',
    });
    setState(() => _isRecording = !_isRecording);
  }

  @override
  Widget build(BuildContext context) {
    if (_collapsed) {
      return GestureDetector(
        onTap: () => setState(() => _collapsed = false),
        child: Container(
          width: 12,
          height: 48,
          decoration: BoxDecoration(
            color: _isRecording ? Colors.red : const Color(0xFF1565C0),
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _onTap,
      onLongPress: () => setState(() => _collapsed = true),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isRecording ? Colors.red : const Color(0xFF1565C0),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
        ),
        child: Icon(
          _isRecording ? Icons.stop : Icons.fiber_manual_record,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}
