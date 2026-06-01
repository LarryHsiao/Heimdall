import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall/data/jira_credentials.dart';
import 'package:heimdall/ui/ticket_window_args.dart';

void main() {
  group('TicketWindowArgs', () {
    const credentials = JiraCredentials(
      baseUrl: 'https://example.atlassian.net',
      email: 'watcher@bifrost',
      apiToken: 'gjallarhorn',
    );

    test('survives an encode/decode round-trip', () {
      const expectedKey = 'HEI-42';
      const args = TicketWindowArgs(
        ticketKey: expectedKey,
        credentials: credentials,
      );
      final restored = TicketWindowArgs.decode(args.encode());
      expect(restored.ticketKey, expectedKey);
      expect(restored.credentials.baseUrl, credentials.baseUrl);
      expect(restored.credentials.email, credentials.email);
      expect(restored.credentials.apiToken, credentials.apiToken);
    });

    test('decode throws on a malformed payload', () {
      expect(() => TicketWindowArgs.decode('not json'), throwsA(anything));
    });
  });
}
