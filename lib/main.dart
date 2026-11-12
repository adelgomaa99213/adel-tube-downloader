import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_state.dart';
import 'domain/entities.dart';
import 'features/downloads/downloads_provider.dart';
import 'features/downloads/downloads_screen.dart';
import 'features/link/home_screen.dart';

void main() => runApp(const ProviderScope(child: AdelTubeApp()));

class AdelTubeApp extends StatelessWidget {
  const AdelTubeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'adel_tube_downloader',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0E5A66)),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0E5A66), brightness: Brightness.dark),
      ),
      home: const Shell(),
    );
  }
}

class Shell extends ConsumerWidget {
  const Shell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(tabProvider);
    final running = ref
        .watch(downloadsProvider)
        .where((t) => t.status == DownloadStatus.running)
        .length;

    return Scaffold(
      body: IndexedStack(
          index: index, children: const [HomeScreen(), DownloadsScreen()]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) =>
            ref.read(tabProvider.notifier).state = i,
        destinations: [
          const NavigationDestination(
              icon: Icon(Icons.link), label: 'الرئيسية'),
          NavigationDestination(
            icon: Badge(
                isLabelVisible: running > 0,
                label: Text('$running'),
                child: const Icon(Icons.download_outlined)),
            label: 'التحميلات',
          ),
        ],
      ),
    );
  }
}
