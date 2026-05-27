// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';
import 'topic.dart';
part 'session_metadata.freezed.dart';
part 'session_metadata.g.dart';

@freezed
class SessionMetadata with _$SessionMetadata {
  const factory SessionMetadata({
    @Default('') String subject,
    @Default('') String chapter,
    @Default([]) List<Topic> topics,
    DateTime? sessionDate,
  }) = _SessionMetadata;

  factory SessionMetadata.empty() =>
      SessionMetadata(sessionDate: DateTime.now());

  factory SessionMetadata.fromJson(Map<String, dynamic> json) =>
      _$SessionMetadataFromJson(json);
}
