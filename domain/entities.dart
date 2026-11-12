enum DownloadStatus { queued, running, paused, done, failed, canceled }

class FormatOption {
  final String id;
  final String ext;
  final int? height;
  final String? vcodec;
  final String? acodec;
  final int? size; // بالبايت (قد يكون تقديرياً)
  final int? abr;
  final String? note;

  const FormatOption({
    required this.id,
    required this.ext,
    this.height,
    this.vcodec,
    this.acodec,
    this.size,
    this.abr,
    this.note,
  });

  bool get hasVideo => vcodec != null && vcodec != 'none';
  bool get hasAudio => acodec != null && acodec != 'none';

  factory FormatOption.fromMap(Map m) => FormatOption(
        id: '${m['id']}',
        ext: '${m['ext'] ?? ''}',
        height: (m['height'] as num?)?.toInt(),
        vcodec: m['vcodec'] as String?,
        acodec: m['acodec'] as String?,
        size: (m['size'] as num?)?.toInt(),
        abr: (m['abr'] as num?)?.toInt(),
        note: m['note'] as String?,
      );
}

class MediaInfo {
  final String url;
  final String title;
  final String? thumbnail;
  final String? uploader;
  final int? duration;
  final List<FormatOption> formats;

  const MediaInfo({
    required this.url,
    required this.title,
    this.thumbnail,
    this.uploader,
    this.duration,
    required this.formats,
  });

  factory MediaInfo.fromMap(String url, Map m) => MediaInfo(
        url: url,
        title: '${m['title'] ?? 'بدون عنوان'}',
        thumbnail: m['thumbnail'] as String?,
        uploader: m['uploader'] as String?,
        duration: (m['duration'] as num?)?.toInt(),
        formats: ((m['formats'] as List?) ?? [])
            .map((e) => FormatOption.fromMap(Map.from(e as Map)))
            .toList(),
      );
}

/// خيار جودة جاهز للعرض والتحميل.
class QualityChoice {
  final String label;
  final String subtitle;
  final String selector; // -f الخاص بـ yt-dlp
  final bool audioOnly;
  final String? audioFormat; // mp3 | m4a | best
  const QualityChoice({
    required this.label,
    required this.subtitle,
    required this.selector,
    this.audioOnly = false,
    this.audioFormat,
  });
}

class DownloadTask {
  final String id;
  final String url;
  final String title;
  final String? thumbnail;
  final String label;
  final String selector;
  final bool audioOnly;
  final String? audioFormat;
  final DownloadStatus status;
  final double progress; // 0..1
  final int? etaSeconds;
  final String? uri; // content:// داخل المعرض (MediaStore)
  final String? mime;
  final String? error;

  const DownloadTask({
    required this.id,
    required this.url,
    required this.title,
    this.thumbnail,
    required this.label,
    required this.selector,
    required this.audioOnly,
    this.audioFormat,
    this.status = DownloadStatus.queued,
    this.progress = 0,
    this.etaSeconds,
    this.uri,
    this.mime,
    this.error,
  });

  DownloadTask copyWith({
    DownloadStatus? status,
    double? progress,
    int? etaSeconds,
    String? uri,
    String? mime,
    String? error,
  }) =>
      DownloadTask(
        id: id,
        url: url,
        title: title,
        thumbnail: thumbnail,
        label: label,
        selector: selector,
        audioOnly: audioOnly,
        audioFormat: audioFormat,
        status: status ?? this.status,
        progress: progress ?? this.progress,
        etaSeconds: etaSeconds ?? this.etaSeconds,
        uri: uri ?? this.uri,
        mime: mime ?? this.mime,
        error: error ?? this.error,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'title': title,
        'thumbnail': thumbnail,
        'label': label,
        'selector': selector,
        'audioOnly': audioOnly,
        'audioFormat': audioFormat,
        'status': status.name,
        'progress': progress,
        'uri': uri,
        'mime': mime,
        'error': error,
      };

  factory DownloadTask.fromJson(Map<String, dynamic> j) => DownloadTask(
        id: j['id'],
        url: j['url'],
        title: j['title'],
        thumbnail: j['thumbnail'],
        label: j['label'],
        selector: j['selector'],
        audioOnly: j['audioOnly'] ?? false,
        audioFormat: j['audioFormat'],
        status: DownloadStatus.values.byName(j['status']),
        progress: (j['progress'] as num?)?.toDouble() ?? 0,
        uri: j['uri'],
        mime: j['mime'],
        error: j['error'],
      );
}
