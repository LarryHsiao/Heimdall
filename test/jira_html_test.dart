import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall/data/jira.dart';

void main() {
  group('inlineImagesFromHtml', () {
    test('returns img src URLs in document order', () {
      const html = '''
<p>first paragraph</p>
<span class="image-wrap"><img src="https://x.atlassian.net/rest/api/3/attachment/content/10042" /></span>
<p>middle</p>
<img src="https://x.atlassian.net/rest/api/3/attachment/content/10043" alt="b">
''';

      final expected = const [
        'https://x.atlassian.net/rest/api/3/attachment/content/10042',
        'https://x.atlassian.net/rest/api/3/attachment/content/10043',
      ];

      final actual = inlineImagesFromHtml(html);
      expect(actual, expected);
    });

    test('returns an empty list when no img tags are present', () {
      const html = '<p>nothing here</p>';
      const expected = <String>[];
      final actual = inlineImagesFromHtml(html);
      expect(actual, expected);
    });

    test('returns an empty list on empty input', () {
      const expected = <String>[];
      final actual = inlineImagesFromHtml('');
      expect(actual, expected);
    });

    test('decodes HTML entities in the src URL', () {
      const html =
          '<img src="https://x.atlassian.net/file?id=1&amp;v=2"/>';
      final expected = const ['https://x.atlassian.net/file?id=1&v=2'];
      final actual = inlineImagesFromHtml(html);
      expect(actual, expected);
    });

    test('accepts single-quoted src attributes', () {
      const html = "<img src='https://example.com/a.png'>";
      final expected = const ['https://example.com/a.png'];
      final actual = inlineImagesFromHtml(html);
      expect(actual, expected);
    });
  });
}
