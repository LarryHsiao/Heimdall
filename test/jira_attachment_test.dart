import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall/data/jira_attachment.dart';

void main() {
  group('JiraAttachment.fromJson', () {
    test('reads every field from a full payload', () {
      final expected = const JiraAttachment(
        id: '10042',
        filename: 'screenshot.png',
        mimeType: 'image/png',
        contentUrl: 'https://x.atlassian.net/rest/api/3/attachment/content/10042',
        thumbnailUrl:
            'https://x.atlassian.net/rest/api/3/attachment/thumbnail/10042',
        size: 4096,
      );

      final actual = JiraAttachment.fromJson({
        'id': expected.id,
        'filename': expected.filename,
        'mimeType': expected.mimeType,
        'content': expected.contentUrl,
        'thumbnail': expected.thumbnailUrl,
        'size': expected.size,
      });

      expect(actual.id, expected.id);
      expect(actual.filename, expected.filename);
      expect(actual.mimeType, expected.mimeType);
      expect(actual.contentUrl, expected.contentUrl);
      expect(actual.thumbnailUrl, expected.thumbnailUrl);
      expect(actual.size, expected.size);
      expect(actual.isImage, isTrue);
    });

    test('defaults missing fields and reports non-image mime', () {
      final actual = JiraAttachment.fromJson(const {
        'id': '7',
        'mimeType': 'application/pdf',
      });

      const expectedFilename = '';
      const expectedContentUrl = '';
      const expectedThumbnailUrl = '';
      const expectedSize = 0;
      const expectedIsImage = false;

      expect(actual.id, '7');
      expect(actual.filename, expectedFilename);
      expect(actual.contentUrl, expectedContentUrl);
      expect(actual.thumbnailUrl, expectedThumbnailUrl);
      expect(actual.size, expectedSize);
      expect(actual.isImage, expectedIsImage);
    });

    test('treats an empty mime as non-image', () {
      final actual = JiraAttachment.fromJson(const {'id': '8'});

      const expectedIsImage = false;
      expect(actual.isImage, expectedIsImage);
    });
  });
}
