import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_state.dart';
import '../../core/url_matcher.dart';
import '../../data/share_service.dart';
import '../downloads/downloads_provider.dart';
import '../quality/quality_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  final _controller = TextEditingController();
  String? _clipUrl;
  String? _ignoredUrl;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkClipboard());
    ShareService.listen(_onShared);
    ShareService.initial().then((t) {
      if (t != null) _onShared(t);
    });
  }

  /// رابط جاء من زر «مشاركة» في تطبيق آخر: نحلله فوراً.
  void _onShared(String text) {
    if (!mounted) return;
    ref.read(tabProvider.notifier).state = 0;
    _controller.text = text.trim();
    _resolve(text);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkClipboard();
  }

  /// التعرف التلقائي: عند فتح التطبيق/العودة إليه نفحص الحافظة.
  Future<void> _checkClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final url = UrlMatcher.firstUrl(data?.text);
    if (!mounted) return;
    if (url != null && url != _ignoredUrl && url != _controller.text.trim()) {
      setState(() => _clipUrl = url);
    }
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      setState(() {
        _controller.text = data!.text!.trim();
        _error = null;
      });
    }
  }

  Future<void> _resolve(String raw) async {
    final url = UrlMatcher.firstUrl(raw);
    if (url == null) {
      setState(() => _error = 'لم أجد رابطاً صالحاً. تأكد أنه يبدأ بـ https://');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final info = await ref.read(engineProvider).resolve(url);
      if (!mounted) return;
      setState(() {
        _ignoredUrl = url;
        _clipUrl = null;
        _controller.clear();
      });
      await showQualitySheet(context, info);
    } on PlatformException catch (e) {
      setState(() => _error = e.message ?? 'تعذّر تحليل الرابط');
    } catch (_) {
      setState(() => _error = 'تعذّر تحليل الرابط. جرّب رابطاً آخر.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateEngine() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('جارٍ تحديث المحرك...')));
    try {
      final v = await ref.read(engineProvider).update();
      messenger.showSnackBar(SnackBar(content: Text('تم التحديث: $v')));
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('فشل التحديث، تحقق من الاتصال')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('عادل تيوب'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (_) => _updateEngine(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'update', child: Text('تحديث المحرك')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('الصق رابط الفيديو', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text('يعمل التحليل على هاتفك مباشرة بدون خوادم.',
              style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.url,
            textDirection: TextDirection.ltr,
            onSubmitted: _loading ? null : _resolve,
            decoration: InputDecoration(
              hintText: 'https://',
              errorText: _error,
              border: const OutlineInputBorder(),
              prefixIcon: IconButton(
                  tooltip: 'لصق',
                  icon: const Icon(Icons.content_paste),
                  onPressed: _paste),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(_controller.clear)),
            ),
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loading ? null : () => _resolve(_controller.text),
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.search),
            label: Text(_loading ? 'جارٍ التحليل...' : 'تحليل الرابط'),
          ),
          if (_clipUrl != null) ...[
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('وجدت رابطاً في الحافظة من ${UrlMatcher.host(_clipUrl!)}',
                        style: theme.textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(_clipUrl!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.ltr,
                        style: theme.textTheme.bodySmall),
                    const SizedBox(height: 8),
                    Row(children: [
                      FilledButton.tonal(
                          onPressed: _loading ? null : () => _resolve(_clipUrl!),
                          child: const Text('تحليل')),
                      const SizedBox(width: 8),
                      TextButton(
                          onPressed: () => setState(() {
                                _ignoredUrl = _clipUrl;
                                _clipUrl = null;
                              }),
                          child: const Text('تجاهل')),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
