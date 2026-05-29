// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';
part 'video_segment.freezed.dart';
part 'video_segment.g.dart';

/// A contiguous recorded chunk on disk.
/// Multiple segments exist when the user pauses and resumes.
@freezed
class VideoSegment with _$VideoSegment {
  const factory VideoSegment({
    required int index,
    required String filePath,
    /// Offset from start of the full session (sum of prior segment durations).
    required Duration startOffset,
    required Duration duration,
    /// Set in Phase 4 when the teacher marks a topic finished.
    String? topicId,
    @Default(false) bool isDeleted,
  }) = _VideoSegment;

  factory VideoSegment.fromJson(Map<String, dynamic> json) =>
      _$VideoSegmentFromJson(json);
}
