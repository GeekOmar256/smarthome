import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/recording_state.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/services/storage_service.dart';

/// MethodChannel name must match the one registered in MainActivity.kt.
const _kChannel = MethodChannel('com.teacher.teacher_recorder/recording');

class RecordingNotifier extends StateNotifier<RecordingState> {
  RecordingNotifier(this._permissionService, this._storageService)
      : super(const RecordingState());

  final PermissionService _permissionService;
  final StorageService _storageService;

  int _segmentIndex = 0;
  String? _currentSessionId;

  void setSession(String sessionId) {
    _currentSessionId = sessionId;
    _segmentIndex = 0;
  }

  Future<void> startRecording() async {
    if (state.status == RecordingStatus.recording) return;
    state = state.copyWith(status: RecordingStatus.requestingPermission);

    final granted = await _permissionService.requestRecordingPermissions();
    if (!granted) {
      state = state.copyWith(
        status: RecordingStatus.error,
        errorMessage: 'Microphone and storage permissions are required.',
      );
      return;
    }

    final sessionId = _currentSessionId ?? DateTime.now().millisecondsSinceEpoch.toString();
    _currentSessionId = sessionId;

    final outputPath = await _storageService.buildRecordingPath(sessionId, _segmentIndex);

    try {
      await _kChannel.invokeMethod<void>('startRecording', {'outputPath': outputPath});
      state = state.copyWith(
        status: RecordingStatus.recording,
        currentSegmentPath: outputPath,
        segmentStartedAt: DateTime.now(),
        errorMessage: null,
      );
    } on PlatformException catch (e) {
      state = state.copyWith(
        status: RecordingStatus.error,
        errorMessage: e.message,
      );
    }
  }

  /// Stops recording and returns the path of the completed segment file.
  Future<String?> stopRecording() async {
    if (state.status != RecordingStatus.recording) return null;
    state = state.copyWith(status: RecordingStatus.stopping);

    try {
      await _kChannel.invokeMethod<void>('stopRecording');
      final path = state.currentSegmentPath;
      _segmentIndex++;
      state = const RecordingState();
      return path;
    } on PlatformException catch (e) {
      state = state.copyWith(
        status: RecordingStatus.error,
        errorMessage: e.message,
      );
      return null;
    }
  }

  /// Convenience: stop current segment (pause), return path.
  Future<String?> pauseRecording() => stopRecording();
}

final recordingProvider =
    StateNotifierProvider<RecordingNotifier, RecordingState>((ref) {
  return RecordingNotifier(
    ref.read(permissionServiceProvider),
    ref.read(storageServiceProvider),
  );
});
