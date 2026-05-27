import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  Future<bool> requestRecordingPermissions() async {
    final permissions = <Permission>[
      Permission.microphone,
      if (Platform.isAndroid) ...[
        Permission.notification,
        Permission.storage,
      ],
    ];

    final statuses = await permissions.request();
    return statuses.values.every((s) => s.isGranted || s.isLimited);
  }

  Future<bool> requestOverlayPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.systemAlertWindow.request();
      return status.isGranted;
    }
    return true;
  }

  Future<bool> get hasOverlayPermission async {
    if (Platform.isAndroid) {
      return Permission.systemAlertWindow.isGranted;
    }
    return true;
  }
}

final permissionServiceProvider = Provider<PermissionService>(
  (_) => PermissionService(),
);
