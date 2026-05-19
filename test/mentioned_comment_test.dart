import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall/data/mention_range.dart';
import 'package:heimdall/data/mentioned_comment.dart';

void main() {
  group('PlainComment.adfDoc', () {
    test('single line wraps a paragraph with one text node', () {
      const expected = {
        'type': 'doc',
        'version': 1,
        'content': [
          {
            'type': 'paragraph',
            'content': [
              {'type': 'text', 'text': 'hello'},
            ],
          },
        ],
      };
      final actual = PlainComment('hello').adfDoc();
      expect(actual, expected);
    });

    test('empty input yields a single empty paragraph', () {
      const expected = {
        'type': 'doc',
        'version': 1,
        'content': [
          {'type': 'paragraph'},
        ],
      };
      final actual = PlainComment('').adfDoc();
      expect(actual, expected);
    });

    test('multiple lines each become their own paragraph', () {
      const expected = {
        'type': 'doc',
        'version': 1,
        'content': [
          {
            'type': 'paragraph',
            'content': [
              {'type': 'text', 'text': 'first'},
            ],
          },
          {'type': 'paragraph'},
          {
            'type': 'paragraph',
            'content': [
              {'type': 'text', 'text': 'third'},
            ],
          },
        ],
      };
      final actual = PlainComment('first\n\nthird').adfDoc();
      expect(actual, expected);
    });
  });

  group('MentionedText.adfDoc', () {
    test('empty range list emits the same shape as PlainComment', () {
      final expected = PlainComment('hello').adfDoc();
      final actual = const MentionedText('hello', []).adfDoc();
      expect(actual, expected);
    });

    test('single mention woven between text runs', () {
      const ranges = [
        MentionRange(
          accountId: 'a1',
          displayName: 'Larry Hsiao',
          start: 3,
          length: 12,
        ),
      ];
      const expected = {
        'type': 'doc',
        'version': 1,
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
      final actual =
          const MentionedText('cc @Larry Hsiao please', ranges).adfDoc();
      expect(actual, expected);
    });

    test('mention at start of paragraph omits the leading text run', () {
      const ranges = [
        MentionRange(
          accountId: 'a1',
          displayName: 'Larry',
          start: 0,
          length: 6,
        ),
      ];
      const expected = {
        'type': 'doc',
        'version': 1,
        'content': [
          {
            'type': 'paragraph',
            'content': [
              {
                'type': 'mention',
                'attrs': {'id': 'a1', 'text': '@Larry'},
              },
              {'type': 'text', 'text': ' here'},
            ],
          },
        ],
      };
      final actual = const MentionedText('@Larry here', ranges).adfDoc();
      expect(actual, expected);
    });

    test('mention at end of paragraph omits the trailing text run', () {
      const ranges = [
        MentionRange(
          accountId: 'a1',
          displayName: 'Larry',
          start: 4,
          length: 6,
        ),
      ];
      const expected = {
        'type': 'doc',
        'version': 1,
        'content': [
          {
            'type': 'paragraph',
            'content': [
              {'type': 'text', 'text': 'see '},
              {
                'type': 'mention',
                'attrs': {'id': 'a1', 'text': '@Larry'},
              },
            ],
          },
        ],
      };
      final actual = const MentionedText('see @Larry', ranges).adfDoc();
      expect(actual, expected);
    });

    test('two mentions in the same paragraph are both woven in order', () {
      const ranges = [
        MentionRange(
          accountId: 'a1',
          displayName: 'Aragorn',
          start: 0,
          length: 8,
        ),
        MentionRange(
          accountId: 'b2',
          displayName: 'Boromir',
          start: 13,
          length: 8,
        ),
      ];
      const expected = {
        'type': 'doc',
        'version': 1,
        'content': [
          {
            'type': 'paragraph',
            'content': [
              {
                'type': 'mention',
                'attrs': {'id': 'a1', 'text': '@Aragorn'},
              },
              {'type': 'text', 'text': ' and '},
              {
                'type': 'mention',
                'attrs': {'id': 'b2', 'text': '@Boromir'},
              },
            ],
          },
        ],
      };
      final actual =
          const MentionedText('@Aragorn and @Boromir', ranges).adfDoc();
      expect(actual, expected);
    });

    test('mention in one line; another line is plain text', () {
      const ranges = [
        MentionRange(
          accountId: 'a1',
          displayName: 'Larry',
          start: 3,
          length: 6,
        ),
      ];
      const expected = {
        'type': 'doc',
        'version': 1,
        'content': [
          {
            'type': 'paragraph',
            'content': [
              {'type': 'text', 'text': 'cc '},
              {
                'type': 'mention',
                'attrs': {'id': 'a1', 'text': '@Larry'},
              },
            ],
          },
          {
            'type': 'paragraph',
            'content': [
              {'type': 'text', 'text': 'please'},
            ],
          },
        ],
      };
      final actual = const MentionedText('cc @Larry\nplease', ranges).adfDoc();
      expect(actual, expected);
    });

    test('ranges given out of order are still woven in left-to-right order',
        () {
      const ranges = [
        MentionRange(
          accountId: 'b2',
          displayName: 'Boromir',
          start: 13,
          length: 8,
        ),
        MentionRange(
          accountId: 'a1',
          displayName: 'Aragorn',
          start: 0,
          length: 8,
        ),
      ];
      final actual =
          const MentionedText('@Aragorn and @Boromir', ranges).adfDoc();
      final first = (actual['content'] as List).first as Map;
      final nodes = first['content'] as List;
      expect(nodes.first['attrs']['id'], 'a1');
      expect(nodes.last['attrs']['id'], 'b2');
    });
  });
}
