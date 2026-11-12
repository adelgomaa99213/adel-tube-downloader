import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/engine/extractor_engine.dart';
import '../../data/engine/ytdlp_engine.dart';
import '../../domain/entities.dart';

final engineProvider = Provider<ExtractorEngine>((ref) => YtDlpEngine());

final downloadsProvider =
    NotifierProvider<DownloadsNotifier, List<DownloadTask>>(
        DownloadsNotifier.new);

class DownloadsNotifier extends Notifier<List<DownloadTask>> {
  static const _key = 'tasks_v2';
  StreamSubscription? _sub;

  ExtractorEngine get _engine => ref.read(engineProvider);

  @override
  List<DownloadTask> build() {
    _sub = _engine.events.listen(_onEvent);
    ref.onDispose(() => _sub?.cancel());
    _load();
    return [];
  }

  /// عند تشغيل التطبيق: أي تحميل كان جارياً وقت الإغلاق/القتل يُستأنف تلقائياً
  /// من الملف الجزئي، ولا يبدأ من الصفر.
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;

    final loaded = <DownloadTask>[];
    final toResume = <DownloadTask>[];
    for (final e in jsonDecode(raw) as List) {
      final t = DownloadTask.fromJson(Map<String, dynamic>.from(e));
      if (t.status == DownloadStatus.running ||
          t.status == DownloadStatus.queued) {
        final q = t.copyWith(status: DownloadStatus.queued);
        loaded.add(q);
        toResume.add(q);
      } else {
        loaded.add(t);
      }
    }
    state = [...state, ...loaded];
    for (final t in toResume) {
      await _start(t);
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(state.map((t) => t.toJson()).toList()));
  }

  Future<void> enqueue(MediaInfo info, QualityChoice c) async {
    final task = DownloadTask(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      url: info.url,
      title: info.title,
      thumbnail: info.thumbnail,
      label: c.label,
      selector: c.selector,
      audioOnly: c.audioOnly,
      audioFormat: c.audioFormat,
    );
    state = [task, ...state];
    await _persist();
    await _start(task);
  }

  /// استئناف (بعد إيقاف مؤقت أو فشل أو انقطاع). يكمل من الملف الجزئي.
  Future<void> resume(DownloadTask t) async {
    _update(t.id, (x) => x.copyWith(status: DownloadStatus.queued, error: ''));
    await _start(t);
  }

  Future<void> _start(DownloadTask t) async {
    try {
      await _engine.download(t);
    } catch (_) {
      _update(
          t.id,
          (x) => x.copyWith(
              status: DownloadStatus.failed, error: 'تعذّر بدء التحميل'));
      await _persist();
    }
  }

  Future<void> pause(String id) => _engine.pause(id);
  Future<void> cancel(String id) => _engine.cancel(id);
  Future<bool> open(DownloadTask t) =>
      t.uri == null ? Future.value(false) : _engine.open(t.uri!, t.mime);

  Future<void> remove(String id) async {
    state = state.where((t) => t.id != id).toList();
    await _persist();
  }

  void _onEvent(Map<String, dynamic> e) {
    final id = e['id'] as String;
    switch (e['type']) {
      case 'progress':
        _update(
            id,
            (t) => t.copyWith(
                  status: DownloadStatus.running,
                  progress:
                      ((e['progress'] as num).toDouble() / 100).clamp(0.0, 1.0),
                  etaSeconds: (e['eta'] as num?)?.toInt(),
                ));
        return;
      case 'saving':
        _update(id,
            (t) => t.copyWith(status: DownloadStatus.running, progress: 1.0));
        return;
      case 'done':
        _update(
            id,
            (t) => t.copyWith(
                status: DownloadStatus.done,
                progress: 1.0,
                uri: e['uri'] as String?,
                mime: e['mime'] as String?));
      case 'paused':
        _update(id, (t) => t.copyWith(status: DownloadStatus.paused));
      case 'canceled':
        _update(id,
            (t) => t.copyWith(status: DownloadStatus.canceled, progress: 0));
      default:
        _update(
            id,
            (t) => t.copyWith(
                status: DownloadStatus.failed,
                error: (e['error'] as String?) ?? 'فشل التحميل'));
    }
    _persist();
  }

  void _update(String id, DownloadTask Function(DownloadTask) f) {
    state = [for (final t in state) t.id == id ? f(t) : t];
  }
}
