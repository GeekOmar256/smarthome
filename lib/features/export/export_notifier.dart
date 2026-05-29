import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'export_state.dart';
import '../segments/domain/segment_manager.dart';
import '../segments/presentation/providers/segment_provider.dart';
import '../metadata/presentation/providers/metadata_provider.dart';
import '../../core/services/ffmpeg_service.dart';

class ExportNotifier extends StateNotifier<ExportState> {
  ExportNotifier(this._ref) : super(const ExportState());

  final Ref _ref;

  Future<void> exportSession(String sessionId) async {
    state = state.copyWith(status: ExportStatus.merging, progress: 0.05);

    try {
      final segments = _ref.read(segmentProvider).segments;
      final metadata = _ref.read(metadataProvider);
      final topicMap = _ref.read(segmentProvider).topicCompletionMap;
      final manager = _ref.read(segmentManagerProvider);

      // Step 1: per-topic merge
      state = state.copyWith(progress: 0.1);
      final topicResults = await manager.assignSegmentsToTopics(
        segments: segments,
        topics: metadata.topics,
        topicCompletionMap: topicMap,
        sessionId: sessionId,
      );
      state = state.copyWith(
        progress: 0.6,
        topicVideoPaths: topicResults.map((r) => r.mergedPath).toList(),
      );

      // Step 2: final merge
      final finalPath = await manager.mergeFinal(
        topicResults: topicResults,
        sessionId: sessionId,
      );
      state = state.copyWith(
        status: ExportStatus.done,
        progress: 1.0,
        finalVideoPath: finalPath,
      );
    } on FfmpegException catch (e) {
      state = state.copyWith(
        status: ExportStatus.error,
        errorMessage: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        status: ExportStatus.error,
        errorMessage: e.toString(),
      );
    }
  }
}

final exportProvider =
    StateNotifierProvider<ExportNotifier, ExportState>((ref) {
  return ExportNotifier(ref);
});
