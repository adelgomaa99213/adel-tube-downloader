import 'package:flutter/services.dart';

import '../../domain/entities.dart';
import 'extractor_engine.dart';

class YtDlpEngine implements ExtractorEngine {
  static const _method = MethodChannel('adel_tube/engine');
  static const _events = EventChannel('adel_tube/progress');

  @override
  Future<MediaInfo> resolve(String url) async {
    final res = await _method.invokeMethod<Map>('getInfo', {'url': url});
    return MediaInfo.fromMap(url, Map.from(res!));
  }

  @override
  Future<void> download(DownloadTask t) => _method.invokeMethod('download', {
        'id': t.id,
        'url': t.url,
        'title': t.title,
        'selector': t.selector,
        'audioOnly': t.audioOnly,
        'audioFormat': t.audioFormat,
      });

  @override
  Future<void> pause(String id) => _method.invokeMethod('pause', {'id': id});

  @override
  Future<void> cancel(String id) => _method.invokeMethod('cancel', {'id': id});

  @override
  Future<bool> open(String uri, String? mime) async =>
      await _method.invokeMethod<bool>('open', {'uri': uri, 'mime': mime}) ??
      false;

  @override
  Future<String> update() async =>
      await _method.invokeMethod<String>('update') ?? '';

  @override
  Stream<Map<String, dynamic>> get events => _events
      .receiveBroadcastStream()
      .map((e) => Map<String, dynamic>.from(e as Map));
}
