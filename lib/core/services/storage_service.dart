import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class StorageService {
  Future<String> buildRecordingPath(String sessionId, int segmentIndex) async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = p.join(dir.path, 'recordings', sessionId);
    await Directory(folder).create(recursive: true);
    return p.join(folder, 'seg_${segmentIndex.toString().padLeft(3, '0')}.mp4');
  }

  Future<String> buildTranscriptPath(String sessionId) async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = p.join(dir.path, 'transcripts');
    await Directory(folder).create(recursive: true);
    return p.join(folder, '${sessionId}_transcript.txt');
  }

  Future<String> buildAudioPath(String sessionId) async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = p.join(dir.path, 'transcripts');
    await Directory(folder).create(recursive: true);
    return p.join(folder, '${sessionId}_audio.wav');
  }

  Future<String> buildFinalVideoPath(String sessionId) async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = p.join(dir.path, 'recordings', sessionId);
    await Directory(folder).create(recursive: true);
    return p.join(folder, 'final.mp4');
  }

  Future<String> buildTopicVideoPath(String sessionId, String topicId) async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = p.join(dir.path, 'recordings', sessionId);
    await Directory(folder).create(recursive: true);
    return p.join(folder, 'topic_$topicId.mp4');
  }

  Future<String> buildConcatListPath(String tag) async {
    final dir = await getTemporaryDirectory();
    return p.join(dir.path, 'concat_$tag.txt');
  }
}

final storageServiceProvider = Provider<StorageService>((_) => StorageService());
