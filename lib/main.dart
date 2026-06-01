import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'ui/ticket_window.dart';
import 'ui/ticket_window_args.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final args = await _ticketWindowArgs();
  runApp(args == null ? const HeimdallApp() : TicketWindow(args: args));
}

/// The ticket payload this engine was launched with, or null for the main
/// window. Any failure — plugin unavailable, empty arguments, or a malformed
/// payload — falls through to the main window rather than crashing.
Future<TicketWindowArgs?> _ticketWindowArgs() async {
  try {
    final controller = await WindowController.fromCurrentEngine();
    final raw = controller.arguments;
    if (raw.isEmpty) return null;
    return TicketWindowArgs.decode(raw);
  } catch (_) {
    return null;
  }
}
