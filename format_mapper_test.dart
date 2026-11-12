import 'package:adel_tube_downloader/domain/entities.dart';
import 'package:adel_tube_downloader/features/quality/format_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

MediaInfo info(List<FormatOption> f) =>
    MediaInfo(url: 'https://a.com/v', title: 't', formats: f);

void main() {
  final formats = [
    const FormatOption(
        id: '1', ext: 'mp4', height: 1080, vcodec: 'avc1', acodec: 'none', size: 100),
    const FormatOption(
        id: '2', ext: 'webm', height: 1080, vcodec: 'vp9', acodec: 'none', size: 150),
    const FormatOption(
        id: '3', ext: 'mp4', height: 720, vcodec: 'avc1', acodec: 'none', size: 50),
    const FormatOption(
        id: '4', ext: 'm4a', vcodec: 'none', acodec: 'mp4a', abr: 128, size: 10),
    const FormatOption(
        id: '5', ext: 'webm', vcodec: 'none', acodec: 'opus', abr: 160, size: 12),
    // صور مصغرة (storyboard): لا فيديو ولا صوت
    const FormatOption(id: 'sb', ext: 'mhtml', vcodec: 'none', acodec: 'none'),
  ];

  test('دقات الفيديو مرتبة تنازلياً بلا تكرار', () {
    final v = FormatMapper.video(info(formats));
    expect(v.map((c) => c.label), ['1080p', '720p']);
  });

  test('الحجم = فيديو + أفضل صوت، وMP4 مفضّل', () {
    final v = FormatMapper.video(info(formats));
    expect(v.first.subtitle, 'MP4 • 112 B'); // 100 (mp4) + 12 (أعلى abr)
    expect(v.first.selector,
        'bestvideo[height<=1080]+bestaudio/best[height<=1080]');
  });

  test('خيارات الصوت ثلاثة وكلها صوتية', () {
    final a = FormatMapper.audioChoices(info(formats));
    expect(a.map((c) => c.label), ['MP3', 'M4A', 'الأصلي']);
    expect(a.every((c) => c.audioOnly), isTrue);
  });

  test('بلا صيغ: قائمة فيديو فارغة ولا انهيار', () {
    expect(FormatMapper.video(info([])), isEmpty);
    expect(FormatMapper.audioChoices(info([])).length, 3);
  });

  test('DownloadTask يُحفظ ويُقرأ كما هو', () {
    const t = DownloadTask(
      id: '1', url: 'https://a.com', title: 'x', label: '720p',
      selector: 's', audioOnly: false, status: DownloadStatus.paused,
      progress: 0.4, uri: 'content://m/1', mime: 'video/mp4',
    );
    final r = DownloadTask.fromJson(t.toJson());
    expect(r.status, DownloadStatus.paused);
    expect(r.progress, 0.4);
    expect(r.uri, 'content://m/1');
    expect(r.mime, 'video/mp4');
  });
}
