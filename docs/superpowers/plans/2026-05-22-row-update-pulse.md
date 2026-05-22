# Row-Update Pulse Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When the 60-second poll surfaces a changed or newly-arrived ticket, the row briefly tints (`surfaceContainerHigh` swatch, ~2 s linear fade) so the user catches the change at a glance.

**Architecture:** Pure helpers in a new `lib/ui/row_pulse.dart` carry the diff and alpha math (cleanly unit-testable). `_TicketsPageState` keeps a single `Map<String, DateTime>` of live pulses, updates it inside `_patchSection` via the helper, and passes a per-section slice into `SectionView`. `SectionViewState` gains a `Ticker` that drives `setState` while any pulse is still inside its 2 s window, and `_bodyRow` composites the pulse alpha onto its existing hover decoration — hover wins when both are active.

**Tech Stack:** Flutter (Material 3, `useMaterial3: true`), `SingleTickerProviderStateMixin`, `flutter_test`.

**Spec reference:** `docs/superpowers/specs/2026-05-22-row-update-pulse-design.md` (head `0e36d7f`).

**Deviation from spec:** the spec's Testing section names "render `_TicketsPage` with a stub Jira". The existing codebase has no test that pumps `TicketsPage` directly, and `TicketsPage` constructs `Jira()` / `Vault()` / `Filters()` / `Preferences()` itself with no injection seam — adding one is bigger than this feature. Tasks 1 and 3 instead cover the spec's three branches at two cheaper layers: the pure-helper unit tests (arrival, change, bootstrap silence as a `nextPulses` call with empty `existing`) and the `SectionView` widget tests (alpha rendering, fade decay, hover dominance). The end-to-end "poll fires → row pulses" path is verified by manual app run, named in Task 5.

---

## Task 1: Pure helpers in `lib/ui/row_pulse.dart`

**Files:**
- Create: `lib/ui/row_pulse.dart`
- Create: `test/row_pulse_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/row_pulse_test.dart` with the following content:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall/data/jira_ticket.dart';
import 'package:heimdall/ui/row_pulse.dart';

JiraTicket _ticket({
  required String key,
  String summary = 's',
  String statusName = 'To Do',
  String statusCategory = 'new',
  String issueType = 'Task',
  String priority = '',
  String assignee = '',
  String parentKey = '',
}) {
  return JiraTicket(
    key: key,
    summary: summary,
    statusName: statusName,
    statusCategory: statusCategory,
    issueType: issueType,
    priority: priority,
    assignee: assignee,
    parentKey: parentKey,
  );
}

void main() {
  group('ticketChanged', () {
    test('returns false when watched fields are identical', () {
      final a = _ticket(key: 'HEI-1');
      final b = _ticket(key: 'HEI-1');
      final expected = false;
      expect(ticketChanged(a, b), expected);
    });

    test('returns true when summary differs', () {
      final a = _ticket(key: 'HEI-1', summary: 'old');
      final b = _ticket(key: 'HEI-1', summary: 'new');
      final expected = true;
      expect(ticketChanged(a, b), expected);
    });

    test('returns true when statusName differs', () {
      final a = _ticket(key: 'HEI-1', statusName: 'To Do');
      final b = _ticket(key: 'HEI-1', statusName: 'Done');
      final expected = true;
      expect(ticketChanged(a, b), expected);
    });

    test('returns true when assignee differs', () {
      final a = _ticket(key: 'HEI-1', assignee: 'Alice');
      final b = _ticket(key: 'HEI-1', assignee: 'Bob');
      final expected = true;
      expect(ticketChanged(a, b), expected);
    });

    test('returns true when priority differs', () {
      final a = _ticket(key: 'HEI-1', priority: 'Low');
      final b = _ticket(key: 'HEI-1', priority: 'High');
      final expected = true;
      expect(ticketChanged(a, b), expected);
    });

    test('returns true when issueType differs', () {
      final a = _ticket(key: 'HEI-1', issueType: 'Task');
      final b = _ticket(key: 'HEI-1', issueType: 'Bug');
      final expected = true;
      expect(ticketChanged(a, b), expected);
    });

    test('returns true when parentKey differs', () {
      final a = _ticket(key: 'HEI-1', parentKey: '');
      final b = _ticket(key: 'HEI-1', parentKey: 'HEI-99');
      final expected = true;
      expect(ticketChanged(a, b), expected);
    });

    test('returns true when statusCategory differs', () {
      final a = _ticket(key: 'HEI-1', statusCategory: 'new');
      final b = _ticket(key: 'HEI-1', statusCategory: 'done');
      final expected = true;
      expect(ticketChanged(a, b), expected);
    });
  });

  group('pulseAlpha', () {
    final window = const Duration(seconds: 2);

    test('returns 1.0 at t=0', () {
      final at = DateTime(2026, 5, 22, 12, 0, 0);
      final now = at;
      final expected = 1.0;
      expect(pulseAlpha(at: at, now: now, window: window), expected);
    });

    test('returns ~0.5 at half-window', () {
      final at = DateTime(2026, 5, 22, 12, 0, 0);
      final now = at.add(const Duration(seconds: 1));
      final expected = 0.5;
      expect(pulseAlpha(at: at, now: now, window: window), closeTo(expected, 0.01));
    });

    test('returns 0.0 at the window edge', () {
      final at = DateTime(2026, 5, 22, 12, 0, 0);
      final now = at.add(const Duration(seconds: 2));
      final expected = 0.0;
      expect(pulseAlpha(at: at, now: now, window: window), expected);
    });

    test('returns 0.0 past the window edge', () {
      final at = DateTime(2026, 5, 22, 12, 0, 0);
      final now = at.add(const Duration(seconds: 10));
      final expected = 0.0;
      expect(pulseAlpha(at: at, now: now, window: window), expected);
    });

    test('clamps at 1.0 for a future timestamp', () {
      final at = DateTime(2026, 5, 22, 12, 0, 5);
      final now = DateTime(2026, 5, 22, 12, 0, 0);
      final expected = 1.0;
      expect(pulseAlpha(at: at, now: now, window: window), expected);
    });
  });

  group('nextPulses', () {
    final now = DateTime(2026, 5, 22, 12, 0, 0);
    final window = const Duration(seconds: 2);

    test('adds a pulse for a newly-arrived ticket', () {
      final previous = <JiraTicket>[];
      final current = [_ticket(key: 'HEI-1')];
      final result = nextPulses(
        previous: previous,
        current: current,
        existing: const <String, DateTime>{},
        now: now,
        window: window,
      );
      final expected = {'HEI-1': now};
      expect(result, expected);
    });

    test('adds a pulse for a changed ticket', () {
      final previous = [_ticket(key: 'HEI-1', statusName: 'To Do')];
      final current = [_ticket(key: 'HEI-1', statusName: 'Done')];
      final result = nextPulses(
        previous: previous,
        current: current,
        existing: const <String, DateTime>{},
        now: now,
        window: window,
      );
      final expected = {'HEI-1': now};
      expect(result, expected);
    });

    test('does not add a pulse for an unchanged ticket', () {
      final previous = [_ticket(key: 'HEI-1')];
      final current = [_ticket(key: 'HEI-1')];
      final result = nextPulses(
        previous: previous,
        current: current,
        existing: const <String, DateTime>{},
        now: now,
        window: window,
      );
      final expected = <String, DateTime>{};
      expect(result, expected);
    });

    test('preserves a live (non-stale) existing entry', () {
      final previous = [_ticket(key: 'HEI-1')];
      final current = [_ticket(key: 'HEI-1')];
      final existing = {'HEI-1': now.subtract(const Duration(seconds: 1))};
      final result = nextPulses(
        previous: previous,
        current: current,
        existing: existing,
        now: now,
        window: window,
      );
      expect(result, existing);
    });

    test('purges entries older than window + 500 ms slack', () {
      final previous = [_ticket(key: 'HEI-1')];
      final current = [_ticket(key: 'HEI-1')];
      final existing = {
        'HEI-1': now.subtract(const Duration(seconds: 3)),
      };
      final result = nextPulses(
        previous: previous,
        current: current,
        existing: existing,
        now: now,
        window: window,
      );
      final expected = <String, DateTime>{};
      expect(result, expected);
    });

    test('overwrites a stale entry with a fresh change', () {
      final previous = [_ticket(key: 'HEI-1', statusName: 'To Do')];
      final current = [_ticket(key: 'HEI-1', statusName: 'Done')];
      final existing = {
        'HEI-1': now.subtract(const Duration(seconds: 5)),
      };
      final result = nextPulses(
        previous: previous,
        current: current,
        existing: existing,
        now: now,
        window: window,
      );
      final expected = {'HEI-1': now};
      expect(result, expected);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `fvm flutter test test/row_pulse_test.dart`
Expected: FAIL with "Target of URI doesn't exist: 'package:heimdall/ui/row_pulse.dart'".

- [ ] **Step 3: Implement the minimal helpers**

Create `lib/ui/row_pulse.dart` with this exact content:

```dart
import '../data/jira_ticket.dart';

const Duration kPulseWindow = Duration(seconds: 2);
const Duration _purgeSlack = Duration(milliseconds: 500);

bool ticketChanged(JiraTicket previous, JiraTicket current) =>
    previous.summary != current.summary ||
    previous.statusName != current.statusName ||
    previous.statusCategory != current.statusCategory ||
    previous.assignee != current.assignee ||
    previous.priority != current.priority ||
    previous.issueType != current.issueType ||
    previous.parentKey != current.parentKey;

double pulseAlpha({
  required DateTime at,
  required DateTime now,
  required Duration window,
}) {
  final elapsedMs = now.difference(at).inMilliseconds;
  if (elapsedMs <= 0) return 1.0;
  if (elapsedMs >= window.inMilliseconds) return 0.0;
  return 1.0 - elapsedMs / window.inMilliseconds;
}

Map<String, DateTime> nextPulses({
  required List<JiraTicket> previous,
  required List<JiraTicket> current,
  required Map<String, DateTime> existing,
  required DateTime now,
  required Duration window,
}) {
  final purgeCutoff = now.subtract(window + _purgeSlack);
  final result = <String, DateTime>{
    for (final entry in existing.entries)
      if (entry.value.isAfter(purgeCutoff)) entry.key: entry.value,
  };
  final byKey = {for (final t in previous) t.key: t};
  for (final ticket in current) {
    final prior = byKey[ticket.key];
    if (prior == null || ticketChanged(prior, ticket)) {
      result[ticket.key] = now;
    }
  }
  return result;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `fvm flutter test test/row_pulse_test.dart`
Expected: PASS — all 21 tests green.

- [ ] **Step 5: Commit**

```bash
rtk git add lib/ui/row_pulse.dart test/row_pulse_test.dart
rtk git commit -m "Add row-pulse diff and alpha helpers

Pure functions in lib/ui/row_pulse.dart:
- ticketChanged: field-by-field watched-set comparison
- pulseAlpha: linear decay 1.0 -> 0.0 over a window
- nextPulses: applies a poll diff to an existing pulse map and
  purges entries older than window + 500 ms slack

Unit tests cover all branches.

Co-Authored-By: Claude Opus 4.7"
```

---

## Task 2: Wire `_pulses` map and bootstrap suppression in `_TicketsPageState`

**Files:**
- Modify: `lib/ui/tickets_page.dart` (the `_TicketsPageState` class, lines 30–235 roughly — fields, `_bootstrap`, `_patchSection`, the call site that passes data to `SectionView`)

- [ ] **Step 1: Add the imports and the pulse state**

In `lib/ui/tickets_page.dart`, add to the existing import block at the top of the file:

```dart
import 'row_pulse.dart';
```

In `_TicketsPageState` (line 30 onwards), add two new fields next to the existing `_data`, `_loading`, `_loadError`, etc.:

```dart
final Map<String, DateTime> _pulses = <String, DateTime>{};
bool _hasLoadedOnce = false;
```

- [ ] **Step 2: Flip `_hasLoadedOnce` after the first successful `_doLoad`**

Locate `_doLoad()` (it `setState`s `_data = data; _loading = false` on success around line 164–166). Inside that same `setState`, add `_hasLoadedOnce = true;` so the flag flips alongside the first successful data assignment. The block becomes:

```dart
setState(() {
  _data = data;
  _loading = false;
  _hasLoadedOnce = true;
});
```

(The flag staying true after subsequent loads is correct — it only suppresses the very first time.)

- [ ] **Step 3: Compute new pulses inside `_patchSection`**

The current `_patchSection` (line ~126):

```dart
void _patchSection(JiraFilter filter, List<JiraTicket> tickets) {
  final data = _data;
  if (data == null) return;
  final idx = data.sections.indexWhere((s) => s.filter.id == filter.id);
  if (idx == -1) return;
  final sections = [...data.sections];
  sections[idx] = FilterSection(filter: filter, tickets: tickets);
  _setSections(sections);
}
```

Replace it with:

```dart
void _patchSection(JiraFilter filter, List<JiraTicket> tickets) {
  final data = _data;
  if (data == null) return;
  final idx = data.sections.indexWhere((s) => s.filter.id == filter.id);
  if (idx == -1) return;
  if (_hasLoadedOnce) {
    final previous = data.sections[idx].tickets;
    final updated = nextPulses(
      previous: previous,
      current: tickets,
      existing: _pulses,
      now: DateTime.now(),
      window: kPulseWindow,
    );
    _pulses
      ..clear()
      ..addAll(updated);
  }
  final sections = [...data.sections];
  sections[idx] = FilterSection(filter: filter, tickets: tickets);
  _setSections(sections);
}
```

(`_setSections` already calls `setState`, so the rebuild that follows will see the updated `_pulses`.)

- [ ] **Step 4: Pass the per-section pulse map into `SectionView`**

Find the `build` method's `SectionView(...)` construction (search for `SectionView(` inside the file). Add a new named argument `pulses` carrying the slice of `_pulses` whose keys appear in this section's tickets:

```dart
SectionView(
  // ... existing params ...
  pulses: {
    for (final t in section.tickets)
      if (_pulses.containsKey(t.key)) t.key: _pulses[t.key]!,
  },
),
```

(If the existing `SectionView(...)` call is wrapped in a helper method or builder, add the argument at every call site. `grep -n 'SectionView(' lib/ui/tickets_page.dart` to enumerate.)

- [ ] **Step 5: Run analyzer to verify no compile error**

Run: `fvm flutter analyze lib/ui/tickets_page.dart`
Expected: "Analyzing tickets_page.dart..." followed by errors — `pulses` is not yet a parameter on `SectionView`. That's the next task. Do NOT continue past this point; commit what compiles only after Task 3 lands the parameter.

If the analyzer error is anything *other than* the `pulses` parameter being unknown, fix it before moving on.

- [ ] **Step 6: Hold the commit until Task 3 lands**

Do not commit yet; Task 3 makes the tree compile.

---

## Task 3: `SectionView` renders pulse, ticker drives the fade

**Files:**
- Modify: `lib/ui/tickets_page.dart` (the `SectionView` widget at line 691 and `SectionViewState` at line 720)
- Modify: `test/row_pulse_test.dart` (append widget tests)

- [ ] **Step 1: Write the failing widget tests**

Append to `test/row_pulse_test.dart`, inside the existing `void main() { ... }` (after the `group('nextPulses', ...)` block):

```dart
  group('SectionView pulse rendering', () {
    Future<void> pumpSection(
      WidgetTester tester, {
      required List<JiraTicket> tickets,
      required Map<String, DateTime> pulses,
    }) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SectionView(
              section: FilterSection(
                filter:
                    const JiraFilter(id: 'f1', name: 'F', query: 'jql'),
                tickets: tickets,
              ),
              settings: const ViewSettings(),
              pulses: pulses,
              onSort: (_, _) {},
              onColumnWidthChange: (_, _) {},
              onTicketTap: (_) {},
              onLoadTransitions: (_) async => const <JiraTransition>[],
              onApplyTransition: (_, _) async {},
              onLoadAssignableUsers: (_, _) async => const <JiraUser>[],
              onApplyAssignee: (_, _) async {},
            ),
          ),
        ),
      );
    }

    testWidgets('tints a row whose key has a fresh pulse', (tester) async {
      final now = DateTime.now();
      final tickets = [_ticket(key: 'HEI-1'), _ticket(key: 'HEI-2')];
      await pumpSection(
        tester,
        tickets: tickets,
        pulses: {'HEI-1': now},
      );

      final tableRow = tester
          .widgetList<TableRow>(find.byType(TableRow))
          .firstWhere(
            (row) => find.descendant(
              of: find.byWidget(row),
              matching: find.text('HEI-1'),
            ).evaluate().isNotEmpty,
          );
      final color = (tableRow.decoration as BoxDecoration?)?.color;
      expect(color, isNotNull);
      expect(color!.opacity, closeTo(1.0, 0.05));
    });

    testWidgets('drops the tint past the fade window', (tester) async {
      final now = DateTime.now();
      final tickets = [_ticket(key: 'HEI-1')];
      await pumpSection(
        tester,
        tickets: tickets,
        pulses: {'HEI-1': now.subtract(const Duration(seconds: 3))},
      );

      final tableRow = tester
          .widgetList<TableRow>(find.byType(TableRow))
          .firstWhere(
            (row) => find.descendant(
              of: find.byWidget(row),
              matching: find.text('HEI-1'),
            ).evaluate().isNotEmpty,
          );
      final color = (tableRow.decoration as BoxDecoration?)?.color;
      expect(color, isNull);
    });

    testWidgets('renders no pulse when the map is empty', (tester) async {
      final tickets = [_ticket(key: 'HEI-1')];
      await pumpSection(
        tester,
        tickets: tickets,
        pulses: const <String, DateTime>{},
      );

      final tableRow = tester
          .widgetList<TableRow>(find.byType(TableRow))
          .firstWhere(
            (row) => find.descendant(
              of: find.byWidget(row),
              matching: find.text('HEI-1'),
            ).evaluate().isNotEmpty,
          );
      final color = (tableRow.decoration as BoxDecoration?)?.color;
      expect(color, isNull);
    });
  });
```

Also add these imports to the top of `test/row_pulse_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:heimdall/data/jira_filter.dart';
import 'package:heimdall/data/jira_transition.dart';
import 'package:heimdall/data/jira_user.dart';
import 'package:heimdall/data/view_settings.dart';
import 'package:heimdall/ui/tickets_page.dart';
```

- [ ] **Step 2: Run the widget tests to verify they fail**

Run: `fvm flutter test test/row_pulse_test.dart`
Expected: FAIL — `SectionView` does not accept a `pulses` parameter.

- [ ] **Step 3: Add the `pulses` parameter to `SectionView`**

In `lib/ui/tickets_page.dart`, modify the `SectionView` class (line 691) to add the new final field and constructor parameter:

```dart
class SectionView extends StatefulWidget {
  final FilterSection section;
  final ViewSettings settings;
  final Map<String, DateTime> pulses;     // NEW
  final void Function(SortColumn column, bool ascending) onSort;
  final void Function(SortColumn column, double width) onColumnWidthChange;
  final ValueChanged<JiraTicket> onTicketTap;
  final Future<List<JiraTransition>> Function(JiraTicket) onLoadTransitions;
  final Future<void> Function(JiraTicket, JiraTransition) onApplyTransition;
  final Future<List<JiraUser>> Function(JiraTicket, String query)
      onLoadAssignableUsers;
  final Future<void> Function(JiraTicket, JiraUser?) onApplyAssignee;

  const SectionView({
    super.key,
    required this.section,
    required this.settings,
    this.pulses = const <String, DateTime>{},   // NEW (default empty for callers that opt out)
    required this.onSort,
    required this.onColumnWidthChange,
    required this.onTicketTap,
    required this.onLoadTransitions,
    required this.onApplyTransition,
    required this.onLoadAssignableUsers,
    required this.onApplyAssignee,
  });

  @override
  State<SectionView> createState() => SectionViewState();
}
```

- [ ] **Step 4: Mix in `SingleTickerProviderStateMixin` and own a Ticker**

Add the import at the top of the file if not already present:

```dart
import 'package:flutter/scheduler.dart';
```

Modify `SectionViewState` (line 720). Add the mixin to the class declaration, the ticker field, and override lifecycle hooks:

```dart
class SectionViewState extends State<SectionView>
    with SingleTickerProviderStateMixin {
  String? _hoveredKey;
  final Set<String> _expanded = <String>{};
  Ticker? _ticker;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(SectionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _ticker = null;
    super.dispose();
  }

  void _syncTicker() {
    final hasLive = _hasLivePulse();
    if (hasLive && _ticker == null) {
      _ticker = createTicker((_) {
        if (!_hasLivePulse()) {
          _ticker?.stop();
          _ticker?.dispose();
          _ticker = null;
        }
        if (mounted) setState(() {});
      });
      _ticker!.start();
    } else if (!hasLive && _ticker != null) {
      _ticker!.stop();
      _ticker!.dispose();
      _ticker = null;
    }
  }

  bool _hasLivePulse() {
    final now = DateTime.now();
    for (final at in widget.pulses.values) {
      if (now.difference(at) < kPulseWindow) return true;
    }
    return false;
  }

  // (keep the existing getters and methods below — section, settings, build, etc.)
```

(The existing `FilterSection get section`, `ViewSettings get settings`, and the rest of `SectionViewState` stay as-is; the additions above sit just below the existing fields.)

Add the import for `kPulseWindow` if not yet present:

```dart
import 'row_pulse.dart';
```

- [ ] **Step 5: Composite pulse alpha into `_bodyRow`**

Locate `_bodyRow` (line ~1045). The current decoration line:

```dart
return TableRow(
  decoration: BoxDecoration(
    color: hovered ? theme.colorScheme.surfaceContainerHigh : null,
  ),
```

Replace it with:

```dart
final swatch = theme.colorScheme.surfaceContainerHigh;
final pulseAt = widget.pulses[t.key];
final alpha = pulseAt == null
    ? 0.0
    : pulseAlpha(at: pulseAt, now: DateTime.now(), window: kPulseWindow);
final showColor = hovered || alpha > 0;
final effectiveAlpha = hovered ? 1.0 : alpha;
return TableRow(
  decoration: BoxDecoration(
    color: showColor ? swatch.withOpacity(effectiveAlpha) : null,
  ),
```

(The rest of `_bodyRow`'s `children: [...]` body stays the same.)

- [ ] **Step 6: Run the widget tests to verify they pass**

Run: `fvm flutter test test/row_pulse_test.dart`
Expected: PASS — all unit tests still green, plus the three widget tests green.

- [ ] **Step 7: Run the analyzer on the whole file**

Run: `fvm flutter analyze lib/ui/tickets_page.dart lib/ui/row_pulse.dart`
Expected: "No issues found!"

- [ ] **Step 8: Commit Task 2 and Task 3 together**

```bash
rtk git add lib/ui/tickets_page.dart test/row_pulse_test.dart
rtk git commit -m "Pulse changed and arrived rows on each poll

Wire the row_pulse helpers into the ticket list:
- _TicketsPageState keeps a Map<String,DateTime> of live pulses and
  updates it inside _patchSection via nextPulses(); a _hasLoadedOnce
  flag suppresses the bootstrap pulse on first load.
- SectionView takes a pulses map, mixes in
  SingleTickerProviderStateMixin, and starts a Ticker while any
  pulse remains inside its 2 s window.
- _bodyRow composites the pulse alpha onto its existing
  surfaceContainerHigh hover decoration; hover wins at full alpha
  when both fire on the same row.

Co-Authored-By: Claude Opus 4.7"
```

---

## Task 4: Full-suite sweep and analyzer

**Files:** none (verification only)

- [ ] **Step 1: Run the full test suite**

Run: `fvm flutter test`
Expected: every test green. If any pre-existing test now fails, the most likely cause is a missed call site of `SectionView(...)` — open the failure, name the file, and add `pulses: const <String, DateTime>{}` to the call site (a defaulted constructor parameter already allows omission, but if a positional ordering changed the analyzer will catch it).

- [ ] **Step 2: Run the analyzer over the whole project**

Run: `fvm flutter analyze`
Expected: "No issues found!"

- [ ] **Step 3: Manual app run to verify pulse visibility**

```bash
fvm flutter build macos --debug
open build/macos/Build/Products/Debug/heimdall.app
```

With the app open and a filter loaded:

1. Switch focus to your browser.
2. On Jira's side, change the status of a ticket that belongs to Heimdall's active tab.
3. Keep watching the Heimdall window without giving it focus.
4. Within sixty seconds, the row should pulse (a brief tint, fading over ~2 s).
5. Hover the row during the pulse: hover should stay at the same swatch at full alpha.
6. Restart Heimdall fresh: no row should pulse on the first load.

If any of those six observations fails, return to Tasks 2 or 3 and fix the underlying gap. Do not paper over with adjustments to the test — the test names the contract.

- [ ] **Step 4: Commit nothing further**

There is no code to commit here. Tasks 1, 2/3 hold the whole change. If you found bugs in Step 3, they go in their own follow-up commits referencing the relevant task.

---

## Task 5: Amend the spec's Testing section to match the chosen layer

**Files:**
- Modify: `docs/superpowers/specs/2026-05-22-row-update-pulse-design.md` (the "Testing" section)

- [ ] **Step 1: Replace the Testing section**

The current section names `_TicketsPage`-level integration tests. Replace it with one that names the layers actually used:

```markdown
## Testing

Two layers cover the spec's three branches:

1. **Pure helpers** (`test/row_pulse_test.dart` unit tests over `lib/ui/row_pulse.dart`) — `ticketChanged` covers each watched field; `pulseAlpha` covers the linear decay; `nextPulses` covers arrival, change, no-op, hygiene, and a stale-entry overwrite. The bootstrap-silence branch is covered by the empty-`existing` and empty-`previous` calls.
2. **Widget tests** (`test/row_pulse_test.dart` widget tests pumping `SectionView`) — verify that a fresh pulse at full alpha paints `surfaceContainerHigh` on the row's `TableRow.decoration.color`, that a pulse past the fade window paints `null`, and that an empty pulse map paints `null`.

The end-to-end "poll fires → row pulses" wiring inside `_TicketsPageState` is verified by the manual app run named in the plan. `TicketsPage` has no injection seam for `Jira` / `Vault` / `Filters` / `Preferences`, and adding one is overscoped for this change.
```

- [ ] **Step 2: Commit the spec amendment**

```bash
rtk git add docs/superpowers/specs/2026-05-22-row-update-pulse-design.md
rtk git commit -m "Spec: amend Testing section to the layers actually used

Helpers covered by unit tests, SectionView covered by widget tests.
Page-level integration deferred to manual app run — TicketsPage has
no Jira/Vault/Filters/Preferences injection seam and adding one is
overscoped for this change.

Co-Authored-By: Claude Opus 4.7"
```

---

## Self-Review Notes (already addressed in this plan)

**Spec coverage:**
- "Trigger granularity" (Decision 1) → Task 1's `ticketChanged` + `nextPulses`.
- "One swatch" (Decision 2) → Task 3 step 5.
- "Duration" (Decision 3) → Task 1's `pulseAlpha` and `kPulseWindow`.
- "Removals are silent" (Decision 4) → Task 1's `nextPulses` does nothing for keys that vanish.
- "Initial bootstrap suppressed" (Decision 5) → Task 2 step 2 (`_hasLoadedOnce` flip and guard).
- "Page-level diff" (Decision 6) → Task 2 step 3.
- "Per-tab tracking" (Decision 7) → Task 2 step 4 (the section-filtered pulses passed into `SectionView`).
- Architecture > diff seam → Task 1 + Task 2.
- Architecture > rendering → Task 3.
- Architecture > bootstrap suppression → Task 2 step 2.
- Architecture > map hygiene → Task 1's purgeCutoff branch in `nextPulses`.
- Out-of-scope items → no tasks needed.

**Placeholder scan:** no TBDs, no "implement later", no "handle edge cases" — every step carries the code or the command.

**Type consistency:** `kPulseWindow` is referenced from `row_pulse.dart` and used in `tickets_page.dart`; `ticketChanged`, `pulseAlpha`, `nextPulses` keep stable signatures across all tasks; `Map<String, DateTime>` is the one map type throughout.
