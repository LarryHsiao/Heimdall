import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall/data/adf.dart';

void main() {
  group('AdfMarkdown media', () {
    test('mediaSingle becomes a markdown image with positional URI', () {
      final doc = {
        'type': 'doc',
        'version': 1,
        'content': [
          {
            'type': 'mediaSingle',
            'attrs': {'layout': 'center'},
            'content': [
              {
                'type': 'media',
                'attrs': {
                  'id': '5f5e3a1a-uuid',
                  'type': 'file',
                  'alt': 'screenshot',
                },
              },
            ],
          },
        ],
      };

      const expected = '![screenshot](jira-attachment:0)';
      final actual = AdfMarkdown(doc).text();
      expect(actual, expected);
    });

    test('mediaGroup numbers each child in document order', () {
      final doc = {
        'type': 'doc',
        'content': [
          {
            'type': 'mediaGroup',
            'content': [
              {
                'type': 'media',
                'attrs': {'id': 'a', 'type': 'file'},
              },
              {
                'type': 'media',
                'attrs': {'id': 'b', 'type': 'file', 'alt': 'two'},
              },
            ],
          },
        ],
      };

      const expected = '![](jira-attachment:0)\n\n![two](jira-attachment:1)';
      final actual = AdfMarkdown(doc).text();
      expect(actual, expected);
    });

    test('media without an id produces no output and does not advance index',
        () {
      final doc = {
        'type': 'doc',
        'content': [
          {
            'type': 'mediaSingle',
            'content': [
              {'type': 'media', 'attrs': {'type': 'file'}},
            ],
          },
          {
            'type': 'mediaSingle',
            'content': [
              {
                'type': 'media',
                'attrs': {'id': 'real', 'type': 'file'},
              },
            ],
          },
        ],
      };

      const expected = '![](jira-attachment:0)';
      final actual = AdfMarkdown(doc).text();
      expect(actual, expected);
    });

    test('mediaInline renders inside its paragraph using the running index',
        () {
      final doc = {
        'type': 'doc',
        'content': [
          {
            'type': 'mediaSingle',
            'content': [
              {
                'type': 'media',
                'attrs': {'id': 'first', 'type': 'file'},
              },
            ],
          },
          {
            'type': 'paragraph',
            'content': [
              {'type': 'text', 'text': 'See '},
              {
                'type': 'mediaInline',
                'attrs': {'id': 'second', 'type': 'file'},
              },
              {'type': 'text', 'text': ' below.'},
            ],
          },
        ],
      };

      const expected =
          '![](jira-attachment:0)\n\nSee ![](jira-attachment:1) below.';
      final actual = AdfMarkdown(doc).text();
      expect(actual, expected);
    });

    test('text() resets the index between calls on the same instance', () {
      final doc = {
        'type': 'doc',
        'content': [
          {
            'type': 'mediaSingle',
            'content': [
              {
                'type': 'media',
                'attrs': {'id': 'one', 'type': 'file'},
              },
            ],
          },
        ],
      };

      const expected = '![](jira-attachment:0)';
      final renderer = AdfMarkdown(doc);
      final first = renderer.text();
      final second = renderer.text();
      expect(first, expected);
      expect(second, expected);
    });
  });
}
