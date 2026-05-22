# Row-Update Pulse in the Ticket List

**Status** Draft — awaiting review.
**Author** Larry Hsiao, drafted with Claude Opus 4.7.
**Date** 2026-05-22.

## Summary

When the 60-second poll surfaces a ticket whose visible fields have changed, or a ticket that was not in the filter on the previous tick, the row briefly tints — a soft pulse that fades to transparent over about two seconds. Yellow for *changed*, green for *arrived*. Removals stay silent: a row that falls out of the filter simply vanishes, no farewell pulse. The pulse is ephemeral; the user notices on the glance, and the list returns to rest.

Plain background restoration is the default state. Pulses fire only on subsequent polls — never on the very first load, where every row is technically "new" and the whole list would otherwise flash on startup.

## Decisions

1. **Trigger granularity** — any visible field change, plus new arrivals, get a pulse. Status, assignee, summary, priority, parent, and issue-type are the watched fields; anything else the list never shows, so a change there must not pulse.
2. **Two flavours** — yellow tint for *changed*, green tint for *arrived*. Drawn from the current `ColorScheme`'s container variants (`tertiaryContainer` for changed, `secondaryContainer` for arrived) so light and dark themes both behave; no hard-coded hex.
3. **Duration** — peak on poll arrival, linear fade to fully transparent over 2000 ms. Ephemeral by design — the user catches it on the glance.
4. **Removals are silent** — a row that fell out of the filter just disappears. Retaining a transient row for a farewell pulse is overscoped.
5. **Initial bootstrap suppressed** — the first `_doLoad()` call seeds the previous-state baseline but emits no pulses. Pulses fire only on subsequent `_pollActiveSection()` and `_doLoad()` ticks.
6. **Page-level diff** — the diff lives in `_TicketsPageState`, at `_patchSection`. The row widget is dumb: it receives a `Pulse?` and tweens accordingly.
7. **Per-tab tracking** — each `FilterSection` carries its own previous-tickets snapshot for diffing; pulses are scoped to the tab that the changed ticket belongs to. Switching tabs does not re-pulse history.

## Architecture

### The diff seam

A single `Map<String, _PulseEvent>` lives on `_TicketsPageState`, keyed by `JiraTicket.key`. The value names the kind and the moment the pulse began:

```dart
enum PulseKind { changed, arrived }

class _PulseEvent {
  const _PulseEvent({required this.kind, required this.at});
  final PulseKind kind;
  final DateTime at;
}
```

`_patchSection(JiraFilter filter, List<JiraTicket> tickets)` is the only seam that ever writes to this map. On each call:

1. Look up the section's *previous* ticket list (from `_data.sections`).
2. For each ticket in the *new* list, decide its pulse:
   - Previous list had no entry for this key → `PulseKind.arrived`.
   - Previous list had an entry, and any watched field differs → `PulseKind.changed`.
   - Otherwise → no pulse; if a stale entry exists in the map, leave it (its tween will fade on its own).
3. Write the resulting `_PulseEvent` into the map, stamped with `DateTime.now()`.
4. After writing, purge entries whose `at` is older than the fade duration (2 s) plus a small slack — keeps the map bounded.
5. Skip steps 1–4 if the page has not yet completed its first load — that is the bootstrap path, and pulses are suppressed.

`JiraTicket` (in `lib/data/jira_ticket.dart`) bears no `==`/`hashCode` override, so reference equality is the default and useless for this purpose. The diff is therefore a field-by-field comparison via a single private helper, the watched set named in one place:

```dart
bool _ticketChanged(JiraTicket previous, JiraTicket current) =>
    previous.summary != current.summary ||
    previous.statusName != current.statusName ||
    previous.statusCategory != current.statusCategory ||
    previous.assignee != current.assignee ||
    previous.priority != current.priority ||
    previous.issueType != current.issueType ||
    previous.parentKey != current.parentKey;
```

(Field names match the existing `JiraTicket`: `assignee` is a plain `String`, `issueType` not `issueTypeName`, `priority` a plain `String`.)

### Where the pulse renders

`_Row` is a data carrier declared at `lib/ui/tickets_page.dart:647`. Rendering happens in `SectionViewState._bodyRow` at the same file (around line 1045), which already returns a `TableRow` whose `decoration: BoxDecoration(color: …)` flips on hover. The pulse tint composites onto that same `color` slot — hover and pulse stack via `Color.alphaBlend` when both are active, with hover dominant.

`SectionView` (line 691) gains one new constructor parameter:

```dart
final Map<String, _PulseEvent> pulses;
```

The page passes the filtered-to-this-section subset on each rebuild. `SectionViewState` mixes in `SingleTickerProviderStateMixin` and owns a `Ticker` that drives `setState` while any pulse in `pulses` is still within its 2-second fade window. When all pulses decay, the ticker stops. When a fresh pulse arrives (the page passes a non-empty map after an update), the ticker (re-)starts.

Per-row pulse alpha is computed in `_bodyRow` from `DateTime.now().difference(pulse.at)` against the fade duration; the colour is taken from `theme.colorScheme.tertiaryContainer` (changed) or `secondaryContainer` (arrived), with its opacity scaled by `1.0 - elapsed / 2s`, clamped at zero. The `TableRow.decoration.color` then becomes:

```dart
final base = hovered ? theme.colorScheme.surfaceContainerHigh : null;
final tint = _tintFor(t.key);                // null when no live pulse
final color = tint == null
    ? base
    : (base == null ? tint : Color.alphaBlend(base, tint));
```

No per-row `TweenAnimationBuilder` is needed. The ticker-driven setState rebuilds the table each frame, and the alpha is recomputed afresh from `pulse.at` against `DateTime.now()` — the decay is monotonic and continuous, no per-widget animation state to track.

### Initial-bootstrap suppression

`_TicketsPageState` carries one boolean — `_hasLoadedOnce` — initially false. In `_doLoad()`, after the first successful `_load()` returns, we record the per-section ticket snapshots but emit no pulses, then flip the flag. From that moment forward, every `_patchSection` call (whether from the poll or a manual refresh) follows the diff path above.

### Map hygiene

The map is purged after every write — entries with `at < now - 2.5 s` are dropped. Worst case, the map carries one entry per visible ticket per filter, all of them less than 2.5 s old. No background timer is needed; the purge piggy-backs on the existing write seam.

## Testing

A widget test under `test/row_pulse_test.dart` exercises three branches:

1. **Arrival** — render `_TicketsPage` with a stub `Jira` that returns one ticket on first load and a second ticket on the next poll. Pump past the poll interval, then verify the new row's background colour at `t = 0` is the `secondaryContainer` and at `t = 2 s` is back to the row's resting colour.
2. **Change** — same setup, but the second poll returns the same key with a different `statusName`. Verify `tertiaryContainer` tint at `t = 0`, decayed by `t = 2 s`.
3. **Bootstrap silence** — first load returns three tickets. Verify no row carries any pulse tint at `t = 0`.

Time is driven by `tester.pump(Duration)` against `_pollInterval` and the fade window; no wall-clock waits. The Jira stub follows the existing `data/jira.dart` test idiom — Dio swapped for a mock.

## Out of scope

- **Per-cell pulses.** A change in `statusName` does not isolate the Status column; the whole row tints. Per-cell diffing was offered, rejected for complexity and weak payoff.
- **Removal farewell.** Rows that fall out of the filter vanish with no pulse.
- **Persistent "unread" markers.** The pulse is ephemeral; no badge survives the fade.
- **Configurable colours or duration.** The defaults named here are the only path; no settings surface.
- **Cross-tab pulse aggregation.** A change in tab B does not light up tab B's tab indicator from tab A. The pulse is scoped to the row in its own tab.
