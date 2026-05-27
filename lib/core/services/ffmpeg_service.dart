import 'dart:io';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/log_redirection_strategy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class FfmpegService {
  FfmpegService() {
    // Suppress verbose output in release mode to reduce allocations.
    FFmpegKitConfig.setLogRedirectionStrategy(
      LogRedirectionStrategy.neverPrintLogs,
    );
  }

  /// Trim [inputPath]: keep [0 .. deleteFrom] + [deleteTo .. end].
  /// Uses stream copy (-c copy) — no re-encoding, O(1) memory.
  Future<String> trimSegment({
    required String inputPath,
    required Duration deleteFrom,
    required Duration deleteTo,
    required String outputPath,
  }) async {
    final tmpDir = await getTemporaryDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final partA = p.join(tmpDir.path, 'trim_a_$ts.mp4');
    final partB = p.join(tmpDir.path, 'trim_b_$ts.mp4');
    final listPath = p.join(tmpDir.path, 'trim_list_$ts.txt');

    final keepA = deleteFrom.inMilliseconds / 1000.0;
    final seekB = deleteTo.inMilliseconds / 1000.0;

    // Part before deletion
    if (keepA > 0) {
      await _run('-i "$inputPath" -t $keepA -c copy "$partA"');
    }

    // Part after deletion
    await _run('-ss $seekB -i "$inputPath" -c copy "$partB"');

    // Concat the two parts
    final parts = <String>[];
    if (keepA > 0 && await File(partA).exists()) parts.add(partA);
    if (await File(partB).exists()) parts.add(partB);

    if (parts.isEmpty) throw const FfmpegException('Trim produced no output parts');
    if (parts.length == 1) {
      await File(parts.first).copy(outputPath);
    } else {
      await File(listPath).writeAsString(parts.map((f) => "file '$f'").join('\n'));
      await _run('-f concat -safe 0 -i "$listPath" -c copy "$outputPath"');
    }

    // Clean up temp parts
    for (final f in [partA, partB, listPath]) {
      final file = File(f);
      if (await file.exists()) await file.delete();
    }

    return outputPath;
  }

  /// Merge [segmentPaths] into [outputPath] using concat demuxer (stream copy).
  Future<String> mergeSegments({
    required List<String> segmentPaths,
    required String outputPath,
  }) async {
    if (segmentPaths.isEmpty) throw const FfmpegException('No segments to merge');
    if (segmentPaths.length == 1) {
      await File(segmentPaths.first).copy(outputPath);
      return outputPath;
    }

    final tmpDir = await getTemporaryDirectory();
    final listPath = p.join(tmpDir.path, 'merge_${DateTime.now().millisecondsSinceEpoch}.txt');
    await File(listPath).writeAsString(
      segmentPaths.map((f) => "file '$f'").join('\n'),
    );

    await _run('-f concat -safe 0 -i "$listPath" -c copy "$outputPath"');

    await File(listPath).delete();
    return outputPath;
  }

  /// Extract audio from [videoPath] as 16kHz mono PCM WAV (required by STT engines).
  Future<String> extractAudio({
    required String videoPath,
    required String outputWavPath,
  }) async {
    await _run(
      '-i "$videoPath" -vn -acodec pcm_s16le -ar 16000 -ac 1 "$outputWavPath"',
    );
    return outputWavPath;
  }

  Future<void> _run(String command) async {
    final session = await FFmpegKit.execute(command);
    final rc = await session.getReturnCode();
    if (!ReturnCode.isSuccess(rc)) {
      final logs = await session.getAllLogsAsString();
      throw FfmpegException('FFmpeg failed (cmd: $command)\n$logs');
    }
  }
}

class FfmpegException implements Exception {
  final String message;
  const FfmpegException(this.message);
  @override
  String toString() => 'FfmpegException: $message';
}

final ffmpegServiceProvider = Provider<FfmpegService>((_) => FfmpegService());
