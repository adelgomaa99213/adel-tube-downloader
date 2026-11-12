import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities.dart';
import 'downloads_provider.dart';

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(downloadsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('التحميلات')),
      body: tasks.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                    'لا توجد تحميلات بعد. الصق رابطاً أو شاركه إلى التطبيق لتبدأ.',
                    textAlign: TextAlign.center),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: tasks.length,
              itemBuilder: (_, i) => _TaskCard(task: tasks[i]),
            ),
    );
  }
}

class _TaskCard extends ConsumerWidget {
  final DownloadTask task;
  const _TaskCard({required this.task});

  bool get _finishing =>
      task.status == DownloadStatus.running && task.progress >= 0.999;

  String _statusText() {
    switch (task.status) {
      case DownloadStatus.queued:
        return 'في الانتظار...';
      case DownloadStatus.running:
        if (_finishing) return 'جارٍ الدمج والحفظ في المعرض...';
        final eta = task.etaSeconds;
        return '${(task.progress * 100).toInt()}%'
            '${eta != null && eta > 0 ? '  |  متبقي $eta ث' : ''}';
      case DownloadStatus.paused:
        return 'متوقف مؤقتاً عند ${(task.progress * 100).toInt()}%';
      case DownloadStatus.done:
        return 'اكتمل - في المعرض';
      case DownloadStatus.failed:
        return 'انقطع التحميل. يمكنك الاستئناف من حيث توقف.';
      case DownloadStatus.canceled:
        return 'أُلغي';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.read(downloadsProvider.notifier);
    final running = task.status == DownloadStatus.running ||
        task.status == DownloadStatus.queued;
    final paused = task.status == DownloadStatus.paused;
    final failed = task.status == DownloadStatus.failed;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 80,
                  height: 48,
                  child: task.thumbnail == null
                      ? const ColoredBox(color: Colors.black12)
                      : Image.network(task.thumbnail!, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const ColoredBox(color: Colors.black12)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task.title,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    Text(task.label,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ]),
            if (running || paused || failed) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: task.status == DownloadStatus.queued || _finishing
                    ? null
                    : task.progress,
              ),
            ],
            const SizedBox(height: 6),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              children: [
                Text(_statusText(),
                    style: Theme.of(context).textTheme.bodySmall),
                if (task.status == DownloadStatus.running && !_finishing)
                  TextButton(
                      onPressed: () => n.pause(task.id),
                      child: const Text('إيقاف مؤقت')),
                if (paused || failed)
                  FilledButton.tonal(
                      onPressed: () => n.resume(task),
                      child: const Text('استئناف')),
                if (running && !_finishing || paused)
                  TextButton(
                      onPressed: () => n.cancel(task.id),
                      child: const Text('إلغاء')),
                if (task.status == DownloadStatus.canceled)
                  TextButton(
                      onPressed: () => n.resume(task),
                      child: const Text('إعادة')),
                if (task.status == DownloadStatus.done)
                  TextButton(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final ok = await n.open(task);
                      if (!ok) {
                        messenger.showSnackBar(const SnackBar(
                            content: Text('لا يوجد تطبيق يفتح هذا الملف')));
                      }
                    },
                    child: const Text('فتح'),
                  ),
                if (!running)
                  IconButton(
                      tooltip: 'حذف من القائمة',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => n.remove(task.id)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
