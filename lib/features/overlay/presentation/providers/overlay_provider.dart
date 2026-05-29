import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../../../../core/services/permission_service.dart';

enum OverlayStatus { hidden, visible, collapsed }

class OverlayNotifier extends StateNotifier<OverlayStatus> {
  OverlayNotifier(this._permissionService) : super(OverlayStatus.hidden);

  final PermissionService _permissionService;

  Future<void> showOverlay() async {
    if (Platform.isAndroid) {
      final granted = await _permissionService.requestOverlayPermission();
      if (!granted) return;

      await FlutterOverlayWindow.showOverlay(
        height: 64,
        width: 64,
        alignment: OverlayAlignment.centerRight,
        enableDrag: true,
        flag: OverlayFlag.defaultFlag,
        overlayTitle: 'Teacher Recorder',
      );
    }
    state = OverlayStatus.visible;
  }

  Future<void> hideOverlay() async {
    if (Platform.isAndroid) {
      final isActive = await FlutterOverlayWindow.isActive();
      if (isActive) await FlutterOverlayWindow.closeOverlay();
    }
    state = OverlayStatus.hidden;
  }

  void toggleCollapse() {
    if (state == OverlayStatus.hidden) return;
    state = state == OverlayStatus.collapsed
        ? OverlayStatus.visible
        : OverlayStatus.collapsed;
    FlutterOverlayWindow.shareData({'action': 'toggleCollapse'});
  }

  /// Send a control signal to the overlay mini-app.
  void sendSignal(String action) {
    FlutterOverlayWindow.shareData({'action': action});
  }
}

final overlayProvider =
    StateNotifierProvider<OverlayNotifier, OverlayStatus>((ref) {
  return OverlayNotifier(ref.read(permissionServiceProvider));
});
