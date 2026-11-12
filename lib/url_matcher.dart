/// يستخرج أول رابط http/https من أي نص (الحافظة، المشاركة، اللصق).
class UrlMatcher {
  static final _re = RegExp(r'https?://[^\s<>"]+', caseSensitive: false);
  static final _trailing = RegExp(r'[)\]}.,;!?]+$');

  static String? firstUrl(String? text) {
    if (text == null) return null;
    final m = _re.firstMatch(text);
    if (m == null) return null;
    return m.group(0)!.replaceAll(_trailing, '');
  }

  static String host(String url) =>
      Uri.tryParse(url)?.host.replaceFirst('www.', '') ?? '';
}

String formatBytes(int? bytes) {
  if (bytes == null || bytes <= 0) return 'غير معروف';
  const units = ['B', 'KB', 'MB', 'GB'];
  double v = bytes.toDouble();
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(i < 2 ? 0 : 1)} ${units[i]}';
}

String formatDuration(int? seconds) {
  if (seconds == null || seconds <= 0) return '';
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
}
