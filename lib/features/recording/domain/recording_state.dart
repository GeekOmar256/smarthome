// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';
part 'recording_state.freezed.dart';

enum RecordingStatus { idle, requestingPermission, recording, paused, stopping, error }

@freezed
class RecordingState with _$RecordingState {
  const factory RecordingState({
    @Default(RecordingStatus.idle) RecordingStatus status,
    /// Path of the segment currently being recorded.
    String? currentSegmentPath,
    /// Wall-clock time when the current segment started.
    DateTime? segmentStartedAt,
    String? errorMessage,
  }) = _RecordingState;
}
