enum ExportStatus { idle, merging, done, error }

class ExportState {
  final ExportStatus status;
  final double progress;
  final String? finalVideoPath;
  final List<String> topicVideoPaths;
  final String? errorMessage;

  const ExportState({
    this.status = ExportStatus.idle,
    this.progress = 0.0,
    this.finalVideoPath,
    this.topicVideoPaths = const [],
    this.errorMessage,
  });

  ExportState copyWith({
    ExportStatus? status,
    double? progress,
    String? finalVideoPath,
    List<String>? topicVideoPaths,
    String? errorMessage,
  }) =>
      ExportState(
        status: status ?? this.status,
        progress: progress ?? this.progress,
        finalVideoPath: finalVideoPath ?? this.finalVideoPath,
        topicVideoPaths: topicVideoPaths ?? this.topicVideoPaths,
        errorMessage: errorMessage,
      );
}
