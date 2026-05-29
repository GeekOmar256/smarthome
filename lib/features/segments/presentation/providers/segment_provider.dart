import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/segment_manager.dart';
import '../../../recording/domain/models/video_segment.dart';
import '../../../../core/services/ffmpeg_service.dart';

enum SegmentOpStatus { idle, processing, done, error }

@immutable
class SegmentState {
  final List<VideoSegment> segments;
  final SegmentOpStatus status;
  final String? errorMessage;
  /// Maps topic.id → segment index when "Finished" was tapped.
  final Map<String, int> topicCompletionMap;

  const SegmentState({
    this.segments = const [],
    this.status = SegmentOpStatus.idle,
    this.errorMessage,
    this.topicCompletionMap = const {},
  });

  SegmentState copyWith({
    List<VideoSegment>? segments,
    SegmentOpStatus? status,
    String? errorMessage,
    Map<String, int>? topicCompletionMap,
  }) =>
      SegmentState(
        segments: segments ?? this.segments,
        status: status ?? this.status,
        errorMessage: errorMessage,
        topicCompletionMap: topicCompletionMap ?? this.topicCompletionMap,
      );

  Duration get totalDuration =>
      segments.where((s) => !s.isDeleted).fold(
        Duration.zero,
        (acc, s) => acc + s.duration,
      );
}

class SegmentNotifier extends StateNotifier<SegmentState> {
  SegmentNotifier(this._ffmpegService) : super(const SegmentState());

  final FfmpegService _ffmpegService;

  /// Called by RecordingNotifier after pause/stop with the completed file path.
  void addSegment(String filePath, Duration duration) {
    final offset = state.totalDuration;
    final seg = VideoSegment(
      index: state.segments.length,
      filePath: filePath,
      startOffset: offset,
      duration: duration,
    );
    state = state.copyWith(segments: [...state.segments, seg]);
  }

  /// Tag all segments since the last topic-finish as belonging to [topicId].
  void markTopicFinished(String topicId) {
    final lastSegIndex =
        state.segments.isNotEmpty ? state.segments.last.index : 0;
    final updated = {
      ...state.topicCompletionMap,
      topicId: lastSegIndex,
    };
    state = state.copyWith(topicCompletionMap: updated);
  }

  /// Delete a time range within segment at [segmentIndex].
  Future<void> deleteTimeRange({
    required int segmentIndex,
    required Duration deleteFrom,
    required Duration deleteTo,
  }) async {
    state = state.copyWith(status: SegmentOpStatus.processing);
    try {
      final seg = state.segments[segmentIndex];
      final outPath = seg.filePath.replaceAll('.mp4', '_trimmed.mp4');

      await compute(
        _trimInIsolate,
        _TrimParams(
          inputPath: seg.filePath,
          deleteFrom: deleteFrom,
          deleteTo: deleteTo,
          outputPath: outPath,
        ),
      );

      final newDuration = seg.duration - (deleteTo - deleteFrom);
      final trimmed = seg.copyWith(filePath: outPath, duration: newDuration);
      final newList = [...state.segments]..[segmentIndex] = trimmed;
      state = state.copyWith(segments: newList, status: SegmentOpStatus.done);
    } catch (e) {
      state = state.copyWith(
        status: SegmentOpStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  void removeSegment(int index) {
    final newList = state.segments
        .map((s) => s.index == index ? s.copyWith(isDeleted: true) : s)
        .toList();
    state = state.copyWith(segments: newList);
  }

  void reset() => state = const SegmentState();
}

// Top-level function — required by compute() (must not be a closure or instance method).
Future<void> _trimInIsolate(_TrimParams params) async {
  final ffmpeg = FfmpegService();
  await ffmpeg.trimSegment(
    inputPath: params.inputPath,
    deleteFrom: params.deleteFrom,
    deleteTo: params.deleteTo,
    outputPath: params.outputPath,
  );
}

class _TrimParams {
  final String inputPath;
  final Duration deleteFrom;
  final Duration deleteTo;
  final String outputPath;

  const _TrimParams({
    required this.inputPath,
    required this.deleteFrom,
    required this.deleteTo,
    required this.outputPath,
  });
}

final segmentProvider =
    StateNotifierProvider<SegmentNotifier, SegmentState>((ref) {
  return SegmentNotifier(ref.read(ffmpegServiceProvider));
});
