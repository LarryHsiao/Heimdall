import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall/data/jira_user.dart';
import 'package:heimdall/data/mentioned_comment.dart';
import 'package:heimdall/ui/mention_field.dart';

Widget _hostFor({
  required Future<List<JiraUser>> Function(String) onSearchUsers,
  required Future<void> Function(MentionedComment) onSubmit,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Column(
        children: [
          const SizedBox(height: 400),
          Padding(
            padding: const EdgeInsets.all(16),
            child: MentionField(
              enabled: true,
              hintText: 'Add a comment',
              onSearchUsers: onSearchUsers,
              onSubmit: onSubmit,
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> _typeInto(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
}

void main() {
  group('MentionField search-trigger', () {
    testWidgets('typing @la fires onSearchUsers with "la" after debounce',
        (tester) async {
      final queries = <String>[];

      await tester.pumpWidget(_hostFor(
        onSearchUsers: (q) async {
          queries.add(q);
          return const [];
        },
        onSubmit: (_) async {},
      ));

      await _typeInto(tester, '@la');
      await tester.pump(const Duration(milliseconds: 350));

      const expected = ['la'];
      expect(queries, expected);
    });

    testWidgets('@ mid-word (no boundary before) does not fire search',
        (tester) async {
      final queries = <String>[];

      await tester.pumpWidget(_hostFor(
        onSearchUsers: (q) async {
          queries.add(q);
          return const [];
        },
        onSubmit: (_) async {},
      ));

      await _typeInto(tester, 'foo@bar');
      await tester.pump(const Duration(milliseconds: 350));

      expect(queries, isEmpty);
    });

    testWidgets('@ after a space DOES fire search', (tester) async {
      final queries = <String>[];

      await tester.pumpWidget(_hostFor(
        onSearchUsers: (q) async {
          queries.add(q);
          return const [];
        },
        onSubmit: (_) async {},
      ));

      await _typeInto(tester, 'cc @la');
      await tester.pump(const Duration(milliseconds: 350));

      const expected = ['la'];
      expect(queries, expected);
    });
  });

  group('MentionField commit', () {
    testWidgets('tapping a suggestion inserts @Display and emits a mention',
        (tester) async {
      const galadriel = JiraUser(
        accountId: 'g1',
        displayName: 'Galadriel',
      );
      MentionedComment? submitted;

      await tester.pumpWidget(_hostFor(
        onSearchUsers: (_) async => const [galadriel],
        onSubmit: (c) async {
          submitted = c;
        },
      ));

      await _typeInto(tester, 'cc @gala');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      expect(find.text('Galadriel'), findsOneWidget);

      await tester.tap(find.text('Galadriel'));
      await tester.pump();

      const expectedText = 'cc @Galadriel ';
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, expectedText);

      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      expect(submitted, isA<MentionedText>());
      final adf = submitted!.adfDoc();
      final firstParagraph =
          (adf['content'] as List).first as Map<String, dynamic>;
      final nodes = firstParagraph['content'] as List;
      expect(nodes[0], {'type': 'text', 'text': 'cc '});
      expect(nodes[1], {
        'type': 'mention',
        'attrs': {'id': 'g1', 'text': '@Galadriel'},
      });
    });
  });

  group('MentionField backspace atom', () {
    testWidgets('backspace at the right edge of a mention deletes it whole',
        (tester) async {
      const aragorn = JiraUser(
        accountId: 'a1',
        displayName: 'Aragorn',
      );

      await tester.pumpWidget(_hostFor(
        onSearchUsers: (_) async => const [aragorn],
        onSubmit: (_) async {},
      ));

      await _typeInto(tester, 'hi @ara');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      await tester.tap(find.text('Aragorn'));
      await tester.pump();

      const beforeBackspace = 'hi @Aragorn ';
      var field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, beforeBackspace);

      // Move caret to the right edge of '@Aragorn' (just before the trailing space).
      field.controller!.selection =
          const TextSelection.collapsed(offset: 11);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();

      const expectedAfter = 'hi  ';
      field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, expectedAfter);
    });
  });

  group('MentionField submit without mention', () {
    testWidgets('plain text submits as PlainComment', (tester) async {
      MentionedComment? submitted;

      await tester.pumpWidget(_hostFor(
        onSearchUsers: (_) async => const [],
        onSubmit: (c) async {
          submitted = c;
        },
      ));

      await _typeInto(tester, 'just text');

      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      expect(submitted, isA<PlainComment>());
    });
  });
}
