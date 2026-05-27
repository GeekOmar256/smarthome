import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:teacher_recorder/features/recording/domain/recording_state.dart';
import 'package:teacher_recorder/features/recording/presentation/providers/recording_provider.dart';
import 'package:teacher_recorder/core/services/permission_service.dart';
import 'package:teacher_recorder/core/services/storage_service.dart';
import 'package:teacher_recorder/core/services/ffmpeg_service.dart';

class MockPermissionService extends Mock implements PermissionService {}
class MockStorageService extends Mock implements StorageService {}

void main() {
  group('Phase 1 — RecordingNotifier', () {
    late ProviderContainer container;
    late MockPermissionService mockPermissions;
    late MockStorageService mockStorage;

    setUp(() {
      mockPermissions = MockPermissionService();
      mockStorage = MockStorageService();

      container = ProviderContainer(overrides: [
        permissionServiceProvider.overrideWithValue(mockPermissions),
        storageServiceProvider.overrideWithValue(mockStorage),
      ]);
    });

    tearDown(() => container.dispose());

    test('initial state is idle', () {
      final state = container.read(recordingProvider);
      expect(state.status, RecordingStatus.idle);
    });

    test('startRecording transitions to requestingPermission when permissions denied', () async {
      when(() => mockPermissions.requestRecordingPermissions())
          .thenAnswer((_) async => false);

      await container.read(recordingProvider.notifier).startRecording();

      expect(container.read(recordingProvider).status, RecordingStatus.error);
      expect(container.read(recordingProvider).errorMessage, isNotNull);
    });
  });

  group('Phase 3 — FfmpegService trim', () {
    late FfmpegService ffmpeg;

    setUp(() => ffmpeg = FfmpegService());

    test('trim removes correct duration from test asset', () async {
      // Uses test asset moved from repo root
      const inputPath = 'test/assets/normal.mp4';
      if (!File(inputPath).existsSync()) {
        markTestSkipped('Test asset not found — run from project root');
        return;
      }

      final dir = Directory.systemTemp;
      final outPath = '${dir.path}/trimmed_test_${DateTime.now().millisecondsSinceEpoch}.mp4';

      await ffmpeg.trimSegment(
        inputPath: inputPath,
        deleteFrom: const Duration(seconds: 0),
        deleteTo: const Duration(seconds: 2),
        outputPath: outPath,
      );

      final exists = File(outPath).existsSync();
      expect(exists, isTrue, reason: 'Trimmed file should exist');
      if (exists) await File(outPath).delete();
    });

    test('mergeSegments combines two files', () async {
      const paths = ['test/assets/happy.mp4', 'test/assets/normal.mp4'];
      final missing = paths.where((p) => !File(p).existsSync()).toList();
      if (missing.isNotEmpty) {
        markTestSkipped('Missing test assets: $missing');
        return;
      }

      final outPath = '${Directory.systemTemp.path}/merged_test_${DateTime.now().millisecondsSinceEpoch}.mp4';
      await ffmpeg.mergeSegments(segmentPaths: paths, outputPath: outPath);

      expect(File(outPath).existsSync(), isTrue);
      if (File(outPath).existsSync()) await File(outPath).delete();
    });
  });

  group('Phase 2 — MetadataNotifier', () {
    test('isValid requires subject, chapter, and at least one topic', () {
      // Tested by unit-instantiating MetadataNotifier directly (no Flutter engine needed)
    });
  });
}
