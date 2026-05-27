import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/session_metadata.dart';
import '../../domain/models/topic.dart';

const _kMetadataKey = 'session_metadata';

class MetadataNotifier extends StateNotifier<SessionMetadata> {
  MetadataNotifier() : super(SessionMetadata.empty());

  void setSubject(String subject) =>
      state = state.copyWith(subject: subject);

  void setChapter(String chapter) =>
      state = state.copyWith(chapter: chapter);

  void addTopic(String title) {
    if (title.trim().isEmpty) return;
    state = state.copyWith(topics: [...state.topics, Topic.create(title.trim())]);
    persist();
  }

  void removeTopic(String id) {
    state = state.copyWith(
      topics: state.topics.where((t) => t.id != id).toList(),
    );
    persist();
  }

  void reorderTopics(int oldIndex, int newIndex) {
    final list = [...state.topics];
    final item = list.removeAt(oldIndex);
    list.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, item);
    state = state.copyWith(topics: list);
    persist();
  }

  void markTopicComplete(String id) {
    state = state.copyWith(
      topics: state.topics
          .map((t) => t.id == id ? t.copyWith(isCompleted: true) : t)
          .toList(),
    );
  }

  void setTopicVideoPath(String id, String path) {
    state = state.copyWith(
      topics: state.topics
          .map((t) => t.id == id ? t.copyWith(videoSegmentPath: path) : t)
          .toList(),
    );
  }

  bool get isValid =>
      state.subject.trim().isNotEmpty &&
      state.chapter.trim().isNotEmpty &&
      state.topics.isNotEmpty;

  Future<void> persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMetadataKey, jsonEncode(state.toJson()));
  }

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kMetadataKey);
    if (raw != null) {
      try {
        state = SessionMetadata.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        // Corrupt data — start fresh
        state = SessionMetadata.empty();
      }
    }
  }

  void reset() {
    state = SessionMetadata.empty();
    SharedPreferences.getInstance().then((p) => p.remove(_kMetadataKey));
  }
}

final metadataProvider =
    StateNotifierProvider<MetadataNotifier, SessionMetadata>((ref) {
  return MetadataNotifier()..restore();
});
