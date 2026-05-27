import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../features/recording/domain/recording_state.dart';
import '../features/recording/presentation/providers/recording_provider.dart';
import '../features/segments/presentation/providers/segment_provider.dart';
import '../features/overlay/presentation/providers/overlay_provider.dart';
import '../features/metadata/presentation/providers/metadata_provider.dart';
import 'export_screen.dart';

/// Phase 1–4: Main recording controls + topic checklist.
class RecordingScreen extends ConsumerStatefulWidget {
  const RecordingScreen({super.key});

  @override
  ConsumerState<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends ConsumerState<RecordingScreen> {
  final String _sessionId = const Uuid().v4();
  DateTime? _segmentStart;

  @override
  void initState() {
    super.initState();
    ref.read(recordingProvider.notifier).setSession(_sessionId);
    _listenToOverlaySignals();
  }

  void _listenToOverlaySignals() {
    // Overlay signals arrive via FlutterOverlayWindow.overlayListener in main engine
    // and are routed here via the overlayProvider.
  }

  Future<void> _startOrResume() async {
    _segmentStart = DateTime.now();
    await ref.read(recordingProvider.notifier).startRecording();
    ref.read(overlayProvider.notifier).sendSignal('recordingStarted');
  }

  Future<void> _pause() async {
    final path = await ref.read(recordingProvider.notifier).pauseRecording();
    if (path != null && _segmentStart != null) {
      final duration = DateTime.now().difference(_segmentStart!);
      ref.read(segmentProvider.notifier).addSegment(path, duration);
      _segmentStart = null;
    }
    ref.read(overlayProvider.notifier).sendSignal('recordingStopped');
  }

  Future<void> _stop() async {
    await _pause();
    // Navigate to export screen
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ExportScreen(sessionId: _sessionId),
        ),
      );
    }
  }

  void _markTopicFinished(String topicId) {
    ref.read(metadataProvider.notifier).markTopicComplete(topicId);
    ref.read(segmentProvider.notifier).markTopicFinished(topicId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Topic marked complete.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recordingState = ref.watch(recordingProvider);
    final segments = ref.watch(segmentProvider).segments;
    final metadata = ref.watch(metadataProvider);
    final isRecording = recordingState.status == RecordingStatus.recording;

    return Scaffold(
      appBar: AppBar(
        title: Text('${metadata.subject} — ${metadata.chapter}'),
        backgroundColor: isRecording ? Colors.red : Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Show overlay',
            icon: const Icon(Icons.picture_in_picture),
            onPressed: () => ref.read(overlayProvider.notifier).showOverlay(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Recording status banner
          _RecordingBanner(isRecording: isRecording, segmentCount: segments.length),

          // Topics checklist
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: metadata.topics.length,
              itemBuilder: (_, i) {
                final topic = metadata.topics[i];
                return Card(
                  child: ListTile(
                    leading: Icon(
                      topic.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: topic.isCompleted ? Colors.green : null,
                    ),
                    title: Text(topic.title),
                    subtitle: topic.isCompleted ? const Text('Completed') : null,
                    trailing: !topic.isCompleted
                        ? TextButton(
                            onPressed: () => _markTopicFinished(topic.id),
                            child: const Text('Finished'),
                          )
                        : null,
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _ControlBar(
            isRecording: isRecording,
            onStart: _startOrResume,
            onPause: _pause,
            onStop: _stop,
          ),
        ),
      ),
    );
  }
}

class _RecordingBanner extends StatelessWidget {
  final bool isRecording;
  final int segmentCount;

  const _RecordingBanner({required this.isRecording, required this.segmentCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: isRecording ? Colors.red.shade50 : Colors.grey.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            isRecording ? Icons.fiber_manual_record : Icons.pause_circle_outline,
            color: isRecording ? Colors.red : Colors.grey,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            isRecording ? 'Recording…' : 'Paused',
            style: TextStyle(
              color: isRecording ? Colors.red : Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text('Segments: $segmentCount', style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _ControlBar extends StatelessWidget {
  final bool isRecording;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onStop;

  const _ControlBar({
    required this.isRecording,
    required this.onStart,
    required this.onPause,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onStop,
            icon: const Icon(Icons.stop),
            label: const Text('Finish'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            onPressed: isRecording ? onPause : onStart,
            icon: Icon(isRecording ? Icons.pause : Icons.fiber_manual_record),
            label: Text(isRecording ? 'Pause' : 'Resume'),
            style: FilledButton.styleFrom(
              backgroundColor: isRecording ? Colors.orange : Colors.red,
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ),
      ],
    );
  }
}
