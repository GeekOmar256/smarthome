import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter_isolate/flutter_isolate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:vosk_flutter/vosk_flutter.dart';
import '../../../core/services/ffmpeg_service.dart';
import '../../../core/services/storage_service.dart';

class TranscriptResult {
  final String transcriptPath;
  final String text;
  const TranscriptResult({required this.transcriptPath, required this.text});
}

class TranscriptService {
  final FfmpegService _ffmpeg;
  final StorageService _storage;

  const TranscriptService(this._ffmpeg, this._storage);

  Future<TranscriptResult> generateTranscript({
    required String videoPath,
    required String sessionId,
    void Function(double progress)? onProgress,
  }) async {
    final wavPath = await _storage.buildAudioPath(sessionId);
    final txtPath = await _storage.buildTranscriptPath(sessionId);

    // Step 1: extract audio (FFmpeg runs on its own internal thread)
    onProgress?.call(0.1);
    await _ffmpeg.extractAudio(videoPath: videoPath, outputWavPath: wavPath);

    // Step 2: transcribe in a flutter_isolate (plugin interop required for Vosk)
    onProgress?.call(0.3);
    final transcript = await _runVoskInIsolate(wavPath, onProgress);

    // Step 3: write .txt file
    onProgress?.call(0.95);
    await File(txtPath).writeAsString(transcript);

    onProgress?.call(1.0);
    return TranscriptResult(transcriptPath: txtPath, text: transcript);
  }

  Future<String> _runVoskInIsolate(
    String wavPath,
    void Function(double)? onProgress,
  ) async {
    final receivePort = ReceivePort();
    final isolate = await FlutterIsolate.spawn(
      _voskIsolateEntry,
      [wavPath, receivePort.sendPort],
    );

    final result = await receivePort.first;
    isolate.kill();

    if (result is String) return result;
    throw Exception('Vosk isolate returned unexpected type: ${result.runtimeType}');
  }
}

/// Top-level function — must be top-level for FlutterIsolate.spawn.
@pragma('vm:entry-point')
Future<void> _voskIsolateEntry(List<dynamic> args) async {
  final wavPath = args[0] as String;
  final sendPort = args[1] as SendPort;

  try {
    final modelPath = await _resolveVoskModelPath();
    final vosk = VoskFlutterPlugin.instance();
    final model = await vosk.createModel(modelPath);
    final recognizer = await vosk.createRecognizer(model: model, sampleRate: 16000);

    final file = File(wavPath);
    // Read and process in 4096-byte chunks to avoid loading 100s of MB at once.
    const chunkSize = 4096;
    final raf = await file.open();
    final buffer = StringBuffer();

    try {
      while (true) {
        final chunk = await raf.read(chunkSize);
        if (chunk.isEmpty) break;
        final accepted = await recognizer.acceptWaveformBytes(
          Uint8List.fromList(chunk),
        );
        if (accepted) {
          final partial = await recognizer.getResult();
          final text = partial.text.trim();
          if (text.isNotEmpty) {
            buffer.write(text);
            buffer.write(' ');
          }
        }
      }
    } finally {
      await raf.close();
    }

    final finalResult = await recognizer.getFinalResult();
    final finalText = finalResult.text.trim();
    if (finalText.isNotEmpty) buffer.write(finalText);

    recognizer.dispose();
    model.dispose();

    sendPort.send(buffer.toString().trim());
  } catch (e) {
    sendPort.send('TRANSCRIPT_ERROR: $e');
  }
}

Future<String> _resolveVoskModelPath() async {
  final dir = await getApplicationDocumentsDirectory();
  return p.join(dir.path, 'vosk_model');
}

final transcriptServiceProvider = Provider<TranscriptService>((ref) {
  return TranscriptService(
    ref.read(ffmpegServiceProvider),
    ref.read(storageServiceProvider),
  );
});
