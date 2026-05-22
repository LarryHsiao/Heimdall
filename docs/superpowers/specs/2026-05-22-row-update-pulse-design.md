# Row-Update Pulse in the Ticket List

**Status** Draft — awaiting review.
**Author** Larry Hsiao, drafted with Claude Opus 4.7.
**Date** 2026-05-22.

## Summary

When the 60-second poll surfaces a ticket whose visible fields have changed, or a ticket that was not in the filter on the previous tick, the row tints — a soft pulse using the same swatch as the row's hover tint (`theme.colorScheme.surfaceContainerHigh`), which fades to transparent over about five seconds. Motion is the signal, not colour: a hard appearance, a steady decay. Removals stay silent: a row that falls out of the filter simply vanishes, no farewell pulse. The pulse is long enough that a user glancing back at the window after a moment can still catch it, but it does not linger — once the fade completes, the list returns to rest.

Plain background restoration is the default state. Pulses fire only on subsequent polls — never on the very first load, where every row is technically "new" and the whole list would otherwise flash on startup.

## Decisions

1. **Trigger granularity** — any visible field change, plus new arrivals, get a pulse. Status, assignee, summary, priority, parent, and issue-type are the watched fields; anything else the list never shows, so a change there must not pulse.
2. **One swatch** — `theme.colorScheme.surfaceContainerHigh`, the same colour as the existing row hover tint. Motion-as-signal: the eye catches the appearance and the decay, not a colour shift. *Changed* and *arrived* pulse identically — both diff branches write the same kind of mark. No hard-coded hex; the swatch comes from the active scheme, so light and dark themes both pick the right value. When a row is both hovered and pulsing, the hover tint already paints the same colour, so the pulse adds nothing visible on top — accepted: hover already signals attention, doubling is redundant.
3. **Duration** — peak on poll arrival, linear fade to fully transparent over 5 000 ms. Long enough that the user catches it on a delayed glance back at the window, short enough that the list returns to rest well before the next poll fires.
4. **Removals are silent** — a row that fell out of the filter just disappears. Retaining a transient row for a farewell pulse is overscoped.
5. **Initial bootstrap suppressed** — the first `_doLoad()` call seeds the previous-state baseline but emits no pulses. Pulses fire only on subsequent `_pollActiveSection()` and `_doLoad()` ticks.
6. **Page-level diff** — the diff lives in `_TicketsPageState`, at `_patchSection`. The row widget is dumb: it receives the section's pulse map and computes per-row alpha from `DateTime.now()`.
7. **Per-tab tracking** — each `FilterSection` carries its own previous-tickets snapshot for diffing; pulses are scoped to the tab that the changed ticket belongs to. Switching tabs does not re-pulse history.

## Architecture

### The diff seam

A single `Map<String, DateTime> _pulses` lives on `_TicketsPageState`, keyed by `JiraTicket.key`. The value is the moment the pulse began.

`_patchSection(JiraFilter filter, List<JiraTicket> tickets)` is the only seam that ever writes to this map. On each call:

1. Look up the section's *previous* ticket list (from `_data.sections`).
2. For each ticket in the *new* list, decide whether to pulse:
   - Previous list had no entry for this key → pulse (newly arrived).
   - Previous list had an entry, and any watched field differs → pulse (changed).
   - Otherwise → no pulse; if a stale entry exists in the map, leave it (its tween will fade on its own).
3. Write `DateTime.now()` into the map for each key that should pulse.
4. After writing, purge entries whose value is older than the fade duration (5 s) plus a small slack — keeps the map bounded.
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

`_Row` is a data carrier declared at `lib/ui/tickets_page.dart:647`. Rendering happens in `SectionViewState._bodyRow` at the same file (around line 1045), which already returns a `TableRow` whose `decoration: BoxDecoration(color: …)` flips on hover. Both hover and pulse paint the same colour (`surfaceContainerHigh`) into that same slot — the difference is who supplies the alpha.

`SectionView` (line 691) gains one new constructor parameter:

```dart
final Map<String, DateTime> pulses;
```

The page passes the filtered-to-this-section subset on each rebuild. `SectionViewState` mixes in `SingleTickerProviderStateMixin` and owns a `Ticker` created once in `initState`, started and stopped by `_syncTicker` as live pulses come and go. The ticker drives `setState` while any pulse in `pulses` is still within its 5-second fade window; when all pulses decay it stops, ready to start again on the next change.

Per-row pulse alpha is computed in `_bodyRow` from `DateTime.now().difference(pulseAt)` against the fade duration, yielding a value in `[0.0, 1.0]` that decays linearly. The `TableRow.decoration.color` becomes:

```dart
final swatch = theme.colorScheme.surfaceContainerHigh;
final pulseAlpha = _pulseAlphaFor(t.key);   // 0.0 when no live pulse
final color = hovered || pulseAlpha > 0
    ? swatch.withOpacity(hovered ? 1.0 : pulseAlpha)
    : null;
```

When a row is both hovered and pulsing, hover wins (alpha = 1.0). No per-row `TweenAnimationBuilder` is needed. The ticker-driven setState rebuilds the table each frame, and the alpha is recomputed afresh from `pulseAt` against `DateTime.now()` — the decay is monotonic and continuous, no per-widget animation state to track.

### Initial-bootstrap suppression

`_TicketsPageState` carries one boolean — `_hasLoadedOnce` — initially false. In `_doLoad()`, after the first successful `_load()` returns, we record the per-section ticket snapshots but emit no pulses, then flip the flag. From that moment forward, every `_patchSection` call (whether from the poll or a manual refresh) follows the diff path above.

### Map hygiene

The map is purged after every write — entries with `at < now - 2.5 s` are dropped. Worst case, the map carries one entry per visible ticket per filter, all of them less than 2.5 s old. No background timer is needed; the purge piggy-backs on the existing write seam.

## Testing

Two layers cover the spec's branches:

1. **Pure helpers** (`test/row_pulse_test.dart` unit tests over `lib/ui/row_pulse.dart`) — `ticketChanged` covers each watched field; `pulseAlpha` covers the linear decay at boundary and midpoint; `nextPulses` covers arrival, change, no-op, hygiene, and a stale-entry overwrite. The bootstrap-silence branch is covered by the empty-`previous` calls.
2. **Widget tests** (`test/row_pulse_test.dart` widget tests pumping `SectionView`) — verify that a fresh pulse paints `surfaceContainerHigh` at a clearly-pulsed alpha (`> 0.5`) on the row's `TableRow.decoration.color`, that a pulse past the fade window paints `null`, and that an empty pulse map paints `null`.

The end-to-end "poll fires → row pulses" wiring inside `_TicketsPageState` is verified by a manual app run. `TicketsPage` constructs its own `Jira` / `Vault` / `Filters` / `Preferences` and has no injection seam; adding one is overscoped for this change.

## Out of scope

- **Per-cell pulses.** A change in `statusName` does not isolate the Status column; the whole row tints. Per-cell diffing was offered, rejected for complexity and weak payoff.
- **Removal farewell.** Rows that fall out of the filter vanish with no pulse.
- **Persistent "unread" markers.** The pulse is ephemeral; no badge survives the fade.
- **Configurable colours or duration.** The defaults named here are the only path; no settings surface.
- **Cross-tab pulse aggregation.** A change in tab B does not light up tab B's tab indicator from tab A. The pulse is scoped to the row in its own tab.
