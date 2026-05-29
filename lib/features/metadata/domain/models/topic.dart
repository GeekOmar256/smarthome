// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';
part 'topic.freezed.dart';
part 'topic.g.dart';

@freezed
class Topic with _$Topic {
  const factory Topic({
    required String id,
    required String title,
    @Default(false) bool isCompleted,
    /// Set in Phase 4 after per-topic merge.
    String? videoSegmentPath,
  }) = _Topic;

  factory Topic.create(String title) =>
      Topic(id: const Uuid().v4(), title: title);

  factory Topic.fromJson(Map<String, dynamic> json) => _$TopicFromJson(json);
}
