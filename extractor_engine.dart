import '../../domain/entities.dart';

abstract class ExtractorEngine {
  Future<MediaInfo> resolve(String url);
  Future<void> download(DownloadTask task);

  /// إيقاف مؤقت: تبقى الملفات الجزئية ليُستأنف منها.
  Future<void> pause(String id);

  /// إلغاء: تُحذف الملفات الجزئية.
  Future<void> cancel(String id);
  Future<bool> open(String uri, String? mime);
  Future<String> update();

  /// {id, type: progress|saving|done|paused|failed|canceled, progress, eta, uri, mime, error}
  Stream<Map<String, dynamic>> get events;
}
