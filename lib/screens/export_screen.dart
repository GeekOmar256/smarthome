import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/export/export_notifier.dart';
import '../features/export/export_state.dart';
import '../features/transcription/presentation/providers/transcript_provider.dart';

/// Phase 4–5: Merge segments, generate transcript, review output.
class ExportScreen extends ConsumerWidget {
  final String sessionId;

  const ExportScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final export = ref.watch(exportProvider);
    final transcript = ref.watch(transcriptProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Export Session'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Merge section
          _SectionCard(
            title: 'Video Export',
            child: switch (export.status) {
              ExportStatus.idle => FilledButton.icon(
                  onPressed: () =>
                      ref.read(exportProvider.notifier).exportSession(sessionId),
                  icon: const Icon(Icons.merge_type),
                  label: const Text('Merge & Export Video'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ExportStatus.merging => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(value: export.progress),
                    const SizedBox(height: 8),
                    Text('Merging… ${(export.progress * 100).toInt()}%'),
                  ],
                ),
              ExportStatus.done => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 32),
                    const SizedBox(height: 8),
                    const Text('Merge complete!'),
                    const SizedBox(height: 4),
                    SelectableText(
                      export.finalVideoPath ?? '',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    if (export.topicVideoPaths.isNotEmpty) ...[
                      Text(
                        'Per-topic files (${export.topicVideoPaths.length}):',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      ...export.topicVideoPaths.map(
                        (path) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: SelectableText(
                            path,
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ExportStatus.error => _ErrorView(message: export.errorMessage),
            },
          ),

          const SizedBox(height: 16),

          // Transcript section (only available after export is done)
          _SectionCard(
            title: 'Speech-to-Text Transcript',
            child: export.status != ExportStatus.done
                ? const Text(
                    'Complete the video export first.',
                    style: TextStyle(color: Colors.grey),
                  )
                : switch (transcript.status) {
                    TranscriptStatus.idle => FilledButton.icon(
                        onPressed: () => ref
                            .read(transcriptProvider.notifier)
                            .generateForSession(
                                export.finalVideoPath!, sessionId),
                        icon: const Icon(Icons.record_voice_over),
                        label: const Text('Generate Transcript'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                    TranscriptStatus.extractingAudio ||
                    TranscriptStatus.transcribing ||
                    TranscriptStatus.writingFile =>
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LinearProgressIndicator(value: transcript.progress),
                          const SizedBox(height: 8),
                          Text(_transcriptStatusLabel(transcript.status)),
                        ],
                      ),
                    TranscriptStatus.done => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 32),
                          const SizedBox(height: 8),
                          const Text('Transcript saved!'),
                          const SizedBox(height: 4),
                          SelectableText(
                            transcript.transcriptPath ?? '',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          if ((transcript.transcriptText ?? '').isNotEmpty) ...[
                            const SizedBox(height: 12),
                            const Text(
                              'Preview:',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                transcript.transcriptText!.length > 500
                                    ? '${transcript.transcriptText!.substring(0, 500)}…'
                                    : transcript.transcriptText!,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ],
                      ),
                    TranscriptStatus.error =>
                      _ErrorView(message: transcript.errorMessage),
                  },
          ),
        ],
      ),
    );
  }

  String _transcriptStatusLabel(TranscriptStatus status) => switch (status) {
        TranscriptStatus.extractingAudio => 'Extracting audio…',
        TranscriptStatus.transcribing => 'Transcribing speech…',
        TranscriptStatus.writingFile => 'Saving transcript…',
        _ => 'Processing…',
      };
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            child,
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String? message;
  const _ErrorView({this.message});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.error_outline, color: Colors.red),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message ?? 'An unknown error occurred.',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ],
    );
  }
}
