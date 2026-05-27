import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../recording/domain/models/video_segment.dart';
import '../../metadata/domain/models/topic.dart';
import '../../../core/services/ffmpeg_service.dart';
import '../../../core/services/storage_service.dart';

class TopicSegmentResult {
  final Topic topic;
  final String mergedPath;
  const TopicSegmentResult({required this.topic, required this.mergedPath});
}

class SegmentManager {
  final FfmpegService _ffmpeg;
  final StorageService _storage;

  const SegmentManager(this._ffmpeg, this._storage);

  /// Assign contiguous segments to completed topics.
  /// [topicCompletionMap] maps topic.id → segment index at which
  /// the teacher tapped "Finished" for that topic.
  Future<List<TopicSegmentResult>> assignSegmentsToTopics({
    required List<VideoSegment> segments,
    required List<Topic> topics,
    required Map<String, int> topicCompletionMap,
    required String sessionId,
  }) async {
    final results = <TopicSegmentResult>[];
    final completedTopics = topics.where((t) => t.isCompleted).toList();

    int segStart = 0;
    for (final topic in completedTopics) {
      final segEnd = topicCompletionMap[topic.id] ?? segments.length - 1;
      final topicSegs = segments
          .where((s) => s.index >= segStart && s.index <= segEnd && !s.isDeleted)
          .toList();

      if (topicSegs.isNotEmpty) {
        final outPath = await _storage.buildTopicVideoPath(sessionId, topic.id);
        final mergedPath = await _mergeTopicSegments(topicSegs, outPath);
        results.add(TopicSegmentResult(topic: topic, mergedPath: mergedPath));
      }
      segStart = segEnd + 1;
    }

    return results;
  }

  Future<String> _mergeTopicSegments(
    List<VideoSegment> segs,
    String outPath,
  ) async {
    if (segs.length == 1) {
      await File(segs.first.filePath).copy(outPath);
      return outPath;
    }
    return _ffmpeg.mergeSegments(
      segmentPaths: segs.map((s) => s.filePath).toList(),
      outputPath: outPath,
    );
  }

  /// Final pass: merge all topic outputs into one master video.
  Future<String> mergeFinal({
    required List<TopicSegmentResult> topicResults,
    required String sessionId,
  }) async {
    if (topicResults.isEmpty) throw const FfmpegException('No topic results to merge');
    final outPath = await _storage.buildFinalVideoPath(sessionId);
    return _ffmpeg.mergeSegments(
      segmentPaths: topicResults.map((r) => r.mergedPath).toList(),
      outputPath: outPath,
    );
  }
}

final segmentManagerProvider = Provider<SegmentManager>((ref) {
  return SegmentManager(
    ref.read(ffmpegServiceProvider),
    ref.read(storageServiceProvider),
  );
});
