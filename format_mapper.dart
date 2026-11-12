import '../../core/url_matcher.dart';
import '../../domain/entities.dart';

/// يحوّل صيغ yt-dlp الخام إلى خيارات مفهومة للمستخدم (فيديو / صوت).
class FormatMapper {
  static List<QualityChoice> video(MediaInfo info) {
    final audio = _bestAudio(info.formats);
    final byHeight = <int, FormatOption>{};

    for (final f in info.formats.where((f) => f.hasVideo && f.height != null)) {
      final cur = byHeight[f.height!];
      if (cur == null || _score(f) > _score(cur)) byHeight[f.height!] = f;
    }

    final heights = byHeight.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final h in heights)
        QualityChoice(
          label: '${h}p',
          subtitle:
              'MP4 • ${formatBytes((byHeight[h]!.size ?? 0) + (byHeight[h]!.hasAudio ? 0 : (audio?.size ?? 0)))}',
          selector: 'bestvideo[height<=$h]+bestaudio/best[height<=$h]',
        ),
    ];
  }

  static List<QualityChoice> audioChoices(MediaInfo info) {
    final size = formatBytes(_bestAudio(info.formats)?.size);
    return [
      QualityChoice(
        label: 'MP3',
        subtitle: 'تحويل إلى MP3 • ≈ $size',
        selector: 'bestaudio/best',
        audioOnly: true,
        audioFormat: 'mp3',
      ),
      QualityChoice(
        label: 'M4A',
        subtitle: 'جودة عالية بحجم صغير • ≈ $size',
        selector: 'bestaudio[ext=m4a]/bestaudio/best',
        audioOnly: true,
        audioFormat: 'm4a',
      ),
      QualityChoice(
        label: 'الأصلي',
        subtitle: 'أفضل صوت بدون تحويل • $size',
        selector: 'bestaudio/best',
        audioOnly: true,
        audioFormat: 'best',
      ),
    ];
  }

  static FormatOption? _bestAudio(List<FormatOption> fs) {
    final a = fs.where((f) => f.hasAudio && !f.hasVideo).toList();
    if (a.isEmpty) return null;
    a.sort((x, y) => (y.abr ?? 0).compareTo(x.abr ?? 0));
    return a.first;
  }

  static int _score(FormatOption f) =>
      (f.ext == 'mp4' ? 1 << 40 : 0) + (f.size ?? 0);
}
