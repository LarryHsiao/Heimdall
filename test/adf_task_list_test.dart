import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall/data/adf.dart';

void main() {
  group('AdfMarkdown taskList', () {
    test('renders task items as GFM checkboxes by state', () {
      final doc = {
        'type': 'doc',
        'content': [
          {
            'type': 'taskList',
            'attrs': {'localId': 'a'},
            'content': [
              {
                'type': 'taskItem',
                'attrs': {'state': 'DONE'},
                'content': [
                  {'type': 'text', 'text': 'Spike auth'}
                ],
              },
              {
                'type': 'taskItem',
                'attrs': {'state': 'TODO'},
                'content': [
                  {'type': 'text', 'text': 'Wire role guard'}
                ],
              },
            ],
          },
        ],
      };

      const expected = '- [x] Spike auth\n- [ ] Wire role guard';
      final actual = AdfMarkdown(doc).text();
      expect(actual, expected);
    });

    test('missing state defaults to unchecked', () {
      final doc = {
        'type': 'doc',
        'content': [
          {
            'type': 'taskList',
            'content': [
              {
                'type': 'taskItem',
                'content': [
                  {'type': 'text', 'text': 'No state set'}
                ],
              },
            ],
          },
        ],
      };

      const expected = '- [ ] No state set';
      final actual = AdfMarkdown(doc).text();
      expect(actual, expected);
    });

    test('inline marks survive inside a task item', () {
      final doc = {
        'type': 'doc',
        'content': [
          {
            'type': 'taskList',
            'content': [
              {
                'type': 'taskItem',
                'attrs': {'state': 'TODO'},
                'content': [
                  {
                    'type': 'text',
                    'text': 'bold',
                    'marks': [
                      {'type': 'strong'}
                    ],
                  },
                  {'type': 'text', 'text': ' and italic'},
                ],
              },
            ],
          },
        ],
      };

      const expected = '- [ ] **bold** and italic';
      final actual = AdfMarkdown(doc).text();
      expect(actual, expected);
    });

    test('an empty task list produces no output', () {
      final doc = {
        'type': 'doc',
        'content': [
          {'type': 'taskList', 'content': const <dynamic>[]},
        ],
      };

      const expected = '';
      final actual = AdfMarkdown(doc).text();
      expect(actual, expected);
    });
  });

  group('flipTaskItem', () {
    Map<String, dynamic> docWith(List<String> states) {
      return {
        'type': 'doc',
        'content': [
          {
            'type': 'taskList',
            'content': [
              for (var i = 0; i < states.length; i++)
                {
                  'type': 'taskItem',
                  'attrs': {'localId': 'id-$i', 'state': states[i]},
                  'content': [
                    {'type': 'text', 'text': 'item $i'}
                  ],
                },
            ],
          },
        ],
      };
    }

    List<String> statesOf(Map<String, dynamic> doc) {
      final list =
          ((doc['content'] as List).first as Map)['content'] as List;
      return [
        for (final n in list)
          ((n as Map)['attrs'] as Map)['state'] as String,
      ];
    }

    test('flips the Nth taskItem and leaves the others untouched', () {
      final input = docWith(['TODO', 'DONE', 'TODO']);

      const expected = ['TODO', 'TODO', 'TODO'];
      final actual = statesOf(flipTaskItem(input, 1));
      expect(actual, expected);
    });

    test('flips TODO to DONE', () {
      final input = docWith(['TODO']);
      const expected = ['DONE'];
      expect(statesOf(flipTaskItem(input, 0)), expected);
    });

    test('treats out-of-range index as a no-op', () {
      final input = docWith(['TODO', 'DONE']);
      const expected = ['TODO', 'DONE'];
      expect(statesOf(flipTaskItem(input, 5)), expected);
    });

    test('does not mutate the input document', () {
      final input = docWith(['TODO']);
      flipTaskItem(input, 0);
      expect(statesOf(input), const ['TODO']);
    });

    test('counts taskItems across nested content in document order', () {
      final input = {
        'type': 'doc',
        'content': [
          {
            'type': 'taskList',
            'content': [
              {
                'type': 'taskItem',
                'attrs': {'state': 'TODO'},
                'content': [
                  {'type': 'text', 'text': 'outer'}
                ],
              },
            ],
          },
          {
            'type': 'panel',
            'attrs': {'panelType': 'info'},
            'content': [
              {
                'type': 'taskList',
                'content': [
                  {
                    'type': 'taskItem',
                    'attrs': {'state': 'TODO'},
                    'content': [
                      {'type': 'text', 'text': 'inside panel'}
                    ],
                  },
                ],
              },
            ],
          },
        ],
      };

      final flipped = flipTaskItem(input, 1);
      final outer = ((flipped['content'] as List).first as Map)['content']
          as List;
      final panelTasks = ((((flipped['content'] as List)[1] as Map)['content']
          as List)
          .first as Map)['content'] as List;
      expect(((outer.first as Map)['attrs'] as Map)['state'], 'TODO');
      expect(((panelTasks.first as Map)['attrs'] as Map)['state'], 'DONE');
    });
  });
}
