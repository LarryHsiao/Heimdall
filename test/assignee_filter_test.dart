import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall/ui/assignee_filter.dart';

void main() {
  group('AssigneeFilter accepts', () {
    test('empty selection accepts every assignee', () {
      const expected = true;
      const filter = AssigneeFilter();
      expect(filter.accepts('Aragorn'), expected);
      expect(filter.accepts(''), expected);
    });

    test('single selection accepts only that name', () {
      const filter = AssigneeFilter({'Aragorn'});
      expect(filter.accepts('Aragorn'), true);
      expect(filter.accepts('Boromir'), false);
    });

    test('multiple selection accepts any chosen name', () {
      const filter = AssigneeFilter({'Aragorn', 'Galadriel'});
      expect(filter.accepts('Aragorn'), true);
      expect(filter.accepts('Galadriel'), true);
      expect(filter.accepts('Boromir'), false);
    });

    test('the empty string stands for unassigned', () {
      const filter = AssigneeFilter({''});
      expect(filter.accepts(''), true);
      expect(filter.accepts('Aragorn'), false);
    });
  });

  group('AssigneeFilter toggled', () {
    test('adds a name not yet chosen', () {
      const expected = true;
      const filter = AssigneeFilter();
      final next = filter.toggled('Aragorn');
      expect(next.has('Aragorn'), expected);
    });

    test('removes a name already chosen', () {
      const expected = false;
      const filter = AssigneeFilter({'Aragorn'});
      final next = filter.toggled('Aragorn');
      expect(next.has('Aragorn'), expected);
      expect(next.isEmpty, true);
    });
  });

  group('AssigneeFilter pruned', () {
    test('drops selections absent from the valid set', () {
      const filter = AssigneeFilter({'Aragorn', 'Boromir'});
      final next = filter.pruned({'Aragorn'});
      expect(next.has('Aragorn'), true);
      expect(next.has('Boromir'), false);
    });

    test('empties when no selection survives', () {
      const expected = true;
      const filter = AssigneeFilter({'Aragorn', 'Boromir'});
      final next = filter.pruned({'Galadriel'});
      expect(next.isEmpty, expected);
    });

    test('keeps every selection when all are valid', () {
      const filter = AssigneeFilter({'Aragorn', 'Boromir'});
      final next = filter.pruned({'Aragorn', 'Boromir', 'Galadriel'});
      expect(next.has('Aragorn'), true);
      expect(next.has('Boromir'), true);
    });
  });
}
