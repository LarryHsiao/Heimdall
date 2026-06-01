import 'dart:convert';

import '../data/jira_credentials.dart';

/// The payload handed to a freshly spawned ticket window.
///
/// A sub-window runs on its own Flutter engine and shares no memory with the
/// main window, so everything it needs — which ticket, and the credentials to
/// fetch it — crosses the boundary as a single encoded string.
class TicketWindowArgs {
  final String ticketKey;
  final JiraCredentials credentials;

  const TicketWindowArgs({required this.ticketKey, required this.credentials});

  String encode() => jsonEncode({
        'ticketKey': ticketKey,
        'credentials': credentials.toJson(),
      });

  factory TicketWindowArgs.decode(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return TicketWindowArgs(
      ticketKey: json['ticketKey'] as String,
      credentials: JiraCredentials.fromJson(
        json['credentials'] as Map<String, dynamic>,
      ),
    );
  }
}
