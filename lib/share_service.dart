import 'package:flutter/services.dart';

/// استقبال الروابط من زر «مشاركة» في أي تطبيق (يوتيوب، المتصفح...).
class ShareService {
  static const _ch = MethodChannel('adel_tube/share');

  /// الرابط الذي فُتح به التطبيق (تشغيل بارد)، إن وُجد.
  static Future<String?> initial() => _ch.invokeMethod<String>('getInitial');

  /// مشاركة جديدة والتطبيق مفتوح.
  static void listen(void Function(String text) onShared) {
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'onShared') onShared(call.arguments as String);
    });
  }
}
