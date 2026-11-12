import 'package:adel_tube_downloader/core/url_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UrlMatcher.firstUrl', () {
    test('يستخرج الرابط من وسط نص', () {
      expect(UrlMatcher.firstUrl('شاهد https://youtu.be/abc123?t=5 رائع'),
          'https://youtu.be/abc123?t=5');
    });
    test('يحذف علامات الترقيم الأخيرة', () {
      expect(UrlMatcher.firstUrl('(https://a.com/x).'), 'https://a.com/x');
    });
    test('يتجاهل الأسطر والمسافات حوله', () {
      expect(UrlMatcher.firstUrl('\n  https://a.com/v  \n'), 'https://a.com/v');
    });
    test('يعيد null عند عدم وجود رابط', () {
      expect(UrlMatcher.firstUrl(null), isNull);
      expect(UrlMatcher.firstUrl(''), isNull);
      expect(UrlMatcher.firstUrl('مرحبا'), isNull);
    });
    test('يرفض البروتوكولات التالفة وغير المدعومة', () {
      expect(UrlMatcher.firstUrl('htp://broken.com'), isNull);
      expect(UrlMatcher.firstUrl('ftp://x.com/file'), isNull);
      expect(UrlMatcher.firstUrl('https://'), isNull);
    });
    test('نص ضخم لا يسبب مشكلة', () {
      final big = '${'a ' * 5000}https://a.com/ok';
      expect(UrlMatcher.firstUrl(big), 'https://a.com/ok');
    });
  });

  test('host يحذف www', () {
    expect(UrlMatcher.host('https://www.youtube.com/watch?v=1'), 'youtube.com');
  });

  group('formatBytes / formatDuration', () {
    test('formatBytes', () {
      expect(formatBytes(null), 'غير معروف');
      expect(formatBytes(0), 'غير معروف');
      expect(formatBytes(512), '512 B');
      expect(formatBytes(1024), '1 KB');
      expect(formatBytes(1048576), '1.0 MB');
    });
    test('formatDuration', () {
      expect(formatDuration(null), '');
      expect(formatDuration(65), '1:05');
      expect(formatDuration(3725), '1:02:05');
    });
  });
}
