import 'package:flutter/material.dart';

import 'data/appearance.dart';
import 'data/preferences.dart';
import 'data/refresh_timer.dart';
import 'ui/tickets_page.dart';

class HeimdallApp extends StatefulWidget {
  const HeimdallApp({super.key});

  @override
  State<HeimdallApp> createState() => _HeimdallAppState();
}

class _HeimdallAppState extends State<HeimdallApp> {
  static const _seed = Colors.indigo;

  final Preferences _prefs = Preferences();
  Appearance? _appearance;
  RefreshTimer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  Future<void> _hydrate() async {
    final mode = await _prefs.readThemeMode();
    final interval = await _prefs.readRefreshInterval();
    if (!mounted) return;
    setState(() {
      _appearance = Appearance(_prefs, mode);
      _refreshTimer = RefreshTimer(_prefs, interval);
    });
  }

  @override
  Widget build(BuildContext context) {
    final appearance = _appearance;
    final refreshTimer = _refreshTimer;
    if (appearance == null || refreshTimer == null) {
      return const MaterialApp(
        title: 'Heimdall',
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    return ListenableBuilder(
      listenable: appearance,
      builder: (_, _) => AppearanceScope(
        notifier: appearance,
        child: ListenableBuilder(
          listenable: refreshTimer,
          builder: (_, _) => RefreshTimerScope(
            notifier: refreshTimer,
            child: MaterialApp(
              title: 'Heimdall',
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(seedColor: _seed),
                useMaterial3: true,
              ),
              darkTheme: ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: _seed,
                  brightness: Brightness.dark,
                ),
                useMaterial3: true,
              ),
              themeMode: appearance.mode,
              home: const TicketsPage(),
            ),
          ),
        ),
      ),
    );
  }
}
