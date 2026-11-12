import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/url_matcher.dart';
import '../../domain/entities.dart';
import '../downloads/downloads_provider.dart';
import 'format_mapper.dart';

Future<void> showQualitySheet(BuildContext context, MediaInfo info) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => QualitySheet(info: info),
    );

class QualitySheet extends ConsumerWidget {
  final MediaInfo info;
  const QualitySheet({super.key, required this.info});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final video = FormatMapper.video(info);
    final audio = FormatMapper.audioChoices(info);

    return DefaultTabController(
      length: 2,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            _Header(info: info),
            const TabBar(tabs: [Tab(text: 'فيديو'), Tab(text: 'صوت')]),
            Expanded(
              child: TabBarView(children: [
                _ChoiceList(
                    info: info,
                    choices: video,
                    emptyText: 'لا توجد صيغ فيديو متاحة لهذا الرابط'),
                _ChoiceList(info: info, choices: audio, emptyText: ''),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final MediaInfo info;
  const _Header({required this.info});

  @override
  Widget build(BuildContext context) {
    final dur = formatDuration(info.duration);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 112,
            height: 64,
            child: info.thumbnail == null
                ? const ColoredBox(color: Colors.black12)
                : Image.network(info.thumbnail!, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const ColoredBox(color: Colors.black12)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(info.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                [if (info.uploader != null) info.uploader!, if (dur.isNotEmpty) dur]
                    .join('  |  '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _ChoiceList extends ConsumerWidget {
  final MediaInfo info;
  final List<QualityChoice> choices;
  final String emptyText;
  const _ChoiceList(
      {required this.info, required this.choices, required this.emptyText});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (choices.isEmpty) return Center(child: Text(emptyText));
    return ListView.separated(
      itemCount: choices.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final c = choices[i];
        return ListTile(
          leading: Icon(c.audioOnly ? Icons.music_note : Icons.movie_outlined),
          title: Text(c.label),
          subtitle: Text(c.subtitle),
          trailing: const Icon(Icons.download),
          onTap: () {
            final messenger = ScaffoldMessenger.of(context);
            ref.read(downloadsProvider.notifier).enqueue(info, c);
            Navigator.pop(context);
            messenger.showSnackBar(
                const SnackBar(content: Text('بدأ التحميل - تابعه من تبويب التحميلات')));
          },
        );
      },
    );
  }
}
