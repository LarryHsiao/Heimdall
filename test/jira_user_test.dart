import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall/data/jira_user.dart';

void main() {
  group('JiraUser.fromJson', () {
    test('reads every field from a full payload', () {
      final expected = const JiraUser(
        accountId: '5b10a2844c20165700ede21g',
        displayName: 'Galadriel',
        emailAddress: 'galadriel@lothlorien.example',
        avatarUrl: 'https://x.atlassian.net/avatar/48x48.png',
      );

      final actual = JiraUser.fromJson({
        'accountId': expected.accountId,
        'displayName': expected.displayName,
        'emailAddress': expected.emailAddress,
        'avatarUrls': {
          '48x48': expected.avatarUrl,
          '24x24': 'https://x.atlassian.net/avatar/24x24.png',
        },
      });

      expect(actual.accountId, expected.accountId);
      expect(actual.displayName, expected.displayName);
      expect(actual.emailAddress, expected.emailAddress);
      expect(actual.avatarUrl, expected.avatarUrl);
    });

    test('defaults missing fields and falls back through avatar sizes', () {
      final actual = JiraUser.fromJson(const {
        'accountId': '7',
        'avatarUrls': {'16x16': 'https://x.atlassian.net/avatar/16.png'},
      });

      const expectedDisplayName = '';
      const expectedEmail = '';
      const expectedAvatar = 'https://x.atlassian.net/avatar/16.png';

      expect(actual.accountId, '7');
      expect(actual.displayName, expectedDisplayName);
      expect(actual.emailAddress, expectedEmail);
      expect(actual.avatarUrl, expectedAvatar);
    });

    test('absent avatarUrls map yields empty avatar', () {
      final actual = JiraUser.fromJson(const {'accountId': '8'});

      const expectedAvatar = '';
      expect(actual.avatarUrl, expectedAvatar);
    });
  });
}
