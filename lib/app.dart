import 'package:flutter/material.dart';

import 'ui/tickets_page.dart';

class HeimdallApp extends StatelessWidget {
  const HeimdallApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Heimdall',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const TicketsPage(),
    );
  }
}
