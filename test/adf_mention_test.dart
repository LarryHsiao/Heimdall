import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall/data/adf.dart';

void main() {
  group('AdfMarkdown mention', () {
    test('renders a mention node as a bold @-prefixed display name', () {
      final doc = {
        'type': 'doc',
        'content': [
          {
            'type': 'paragraph',
            'content': [
              {'type': 'text', 'text': 'cc '},
              {
                'type': 'mention',
                'attrs': {'id': 'a1', 'text': '@Larry Hsiao'},
              },
              {'type': 'text', 'text': ' please'},
            ],
          },
        ],
      };

      const expected = 'cc **@Larry Hsiao** please';
      final actual = AdfMarkdown(doc).text();
      expect(actual, expected);
    });

    test('does not double the @ when the text attribute already carries it',
        () {
      final doc = {
        'type': 'doc',
        'content': [
          {
            'type': 'paragraph',
            'content': [
              {
                'type': 'mention',
                'attrs': {'id': 'a1', 'text': '@Aragorn'},
              },
            ],
          },
        ],
      };

      const expected = '**@Aragorn**';
      final actual = AdfMarkdown(doc).text();
      expect(actual, expected);
    });

    test('falls back to **@user** when text attribute is empty', () {
      final doc = {
        'type': 'doc',
        'content': [
          {
            'type': 'paragraph',
            'content': [
              {
                'type': 'mention',
                'attrs': {'id': 'a1', 'text': ''},
              },
            ],
          },
        ],
      };

      const expected = '**@user**';
      final actual = AdfMarkdown(doc).text();
      expect(actual, expected);
    });

    test('falls back to **@user** when text attribute is missing', () {
      final doc = {
        'type': 'doc',
        'content': [
          {
            'type': 'paragraph',
            'content': [
              {
                'type': 'mention',
                'attrs': {'id': 'a1'},
              },
            ],
          },
        ],
      };

      const expected = '**@user**';
      final actual = AdfMarkdown(doc).text();
      expect(actual, expected);
    });
  });
}
