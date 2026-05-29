import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/transcript_service.dart';

enum TranscriptStatus { idle, extractingAudio, transcribing, writingFile, done, error }

class TranscriptState {
  final TranscriptStatus status;
  final double progress;
  final String? transcriptPath;
  final String? transcriptText;
  final String? errorMessage;

  const TranscriptState({
    this.status = TranscriptStatus.idle,
    this.progress = 0.0,
    this.transcriptPath,
    this.transcriptText,
    this.errorMessage,
  });

  TranscriptState copyWith({
    TranscriptStatus? status,
    double? progress,
    String? transcriptPath,
    String? transcriptText,
    String? errorMessage,
  }) =>
      TranscriptState(
        status: status ?? this.status,
        progress: progress ?? this.progress,
        transcriptPath: transcriptPath ?? this.transcriptPath,
        transcriptText: transcriptText ?? this.transcriptText,
        errorMessage: errorMessage,
      );
}

class TranscriptNotifier extends StateNotifier<TranscriptState> {
  TranscriptNotifier(this._service) : super(const TranscriptState());

  final TranscriptService _service;

  Future<void> generateForSession(String finalVideoPath, String sessionId) async {
    state = const TranscriptState(
      status: TranscriptStatus.extractingAudio,
      progress: 0.05,
    );

    try {
      final result = await _service.generateTranscript(
        videoPath: finalVideoPath,
        sessionId: sessionId,
        onProgress: (prog) {
          state = state.copyWith(
            progress: prog,
            status: prog < 0.3
                ? TranscriptStatus.extractingAudio
                : prog < 0.9
                    ? TranscriptStatus.transcribing
                    : TranscriptStatus.writingFile,
          );
        },
      );

      state = TranscriptState(
        status: TranscriptStatus.done,
        progress: 1.0,
        transcriptPath: result.transcriptPath,
        transcriptText: result.text,
      );
    } catch (e) {
      state = TranscriptState(
        status: TranscriptStatus.error,
        errorMessage: e.toString(),
      );
    }
  }
}

final transcriptProvider =
    StateNotifierProvider<TranscriptNotifier, TranscriptState>((ref) {
  return TranscriptNotifier(ref.read(transcriptServiceProvider));
});
