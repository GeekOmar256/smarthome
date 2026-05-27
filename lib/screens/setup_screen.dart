import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/metadata/presentation/providers/metadata_provider.dart';
import '../features/metadata/domain/models/topic.dart';
import 'recording_screen.dart';

/// Phase 2: Teacher enters Subject, Chapter, and Topics before recording.
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final _subjectCtrl = TextEditingController();
  final _chapterCtrl = TextEditingController();
  final _topicCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _chapterCtrl.dispose();
    _topicCtrl.dispose();
    super.dispose();
  }

  void _addTopic() {
    final title = _topicCtrl.text.trim();
    if (title.isEmpty) return;
    ref.read(metadataProvider.notifier).addTopic(title);
    _topicCtrl.clear();
  }

  void _startSession() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(metadataProvider.notifier)
      ..setSubject(_subjectCtrl.text.trim())
      ..setChapter(_chapterCtrl.text.trim());

    if (!ref.read(metadataProvider.notifier).isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one topic.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RecordingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final metadata = ref.watch(metadataProvider);
    final topics = metadata.topics;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Recording Session'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _subjectCtrl,
              decoration: const InputDecoration(
                labelText: 'Subject *',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Subject is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _chapterCtrl,
              decoration: const InputDecoration(
                labelText: 'Chapter *',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Chapter is required' : null,
            ),
            const SizedBox(height: 24),
            Text('Topics', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _topicCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Add a topic…',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addTopic(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _addTopic,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (topics.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No topics yet. Add at least one to continue.',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: topics.length,
                onReorder: ref.read(metadataProvider.notifier).reorderTopics,
                itemBuilder: (_, i) {
                  final topic = topics[i];
                  return ListTile(
                    key: ValueKey(topic.id),
                    leading: const Icon(Icons.drag_handle),
                    title: Text(topic.title),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () =>
                          ref.read(metadataProvider.notifier).removeTopic(topic.id),
                    ),
                  );
                },
              ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _startSession,
              icon: const Icon(Icons.fiber_manual_record),
              label: const Text('Start Recording'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
