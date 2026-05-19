# @-Mention in the Comments Pane

**Status** Draft — awaiting review.
**Author** Larry Hsiao, drafted with Claude Opus 4.7.
**Date** 2026-05-19.

## Summary

Add true Jira `@`-mentions to Heimdall's comments composer. Typing `@` opens a floating overlay near the caret listing matching users from the Jira instance; picking a name commits a styled atomic mention into the field. On send, the comment posts as an ADF document with `mention` nodes — Jira's notify chain fires. Incoming mentions in existing comments render as bold `**@Display Name**` in the markdown view.

The README's *Out of Scope* line for `mentions` yields. Plain-text comments continue to work as before; mention is additive.

## Decisions

1. **Shape** — true ADF `mention` nodes on post; not plain-text tags.
2. **User source** — `/rest/api/3/user/search?query=…`. Broader than `/user/assignable/search`; covers stakeholders and watchers, matches Jira's own picker.
3. **Popup** — floating overlay anchored at the caret. Vertical list with name. Arrow keys move highlight; Enter or Tab commits; Esc dismisses. Click commits.
4. **Atom behavior** — committed mention renders bold via `TextEditingController.buildTextSpan`; backspace at the right edge of a `MentionRange` deletes the whole token in one stroke. Sidecar map tracks `(accountId, displayName, start, length)`.
5. **Trigger boundary** — `@` opens the overlay only when the character before it is start-of-text, whitespace, or punctuation. Mid-word `@` is a literal character.
6. **Failure posture** — search request errors render an empty overlay (no chips), matching the JQL autocomplete idiom. The field still saves a plain comment without a mention.

## Architecture

### Surface and flow

The Comments composer keeps its place — right pane on wide windows, below the description on narrow. The plain `TextField` becomes a `MentionField` of the same outward shape (hint, send icon, posting spinner) plus two new behaviors:

- **Typing `@`** at a word boundary opens a floating overlay anchored near the caret. As characters follow, the overlay lists matching users from `/user/search`, debounced 300 ms (matches the JQL value-suggestion cadence). Names render with their display name; arrow keys move the highlight; Enter or Tab commits; Esc dismisses. Click commits.
- **A committed mention** inserts as `@Display Name `, styled bold inline via `TextEditingController.buildTextSpan`. Atom: backspace at the right edge of the run deletes the whole token. If a mention's text is mutated mid-stream (a character inserted inside it), its `MentionRange` entry drops and the run reverts to plain text; on post it becomes a plain text run with no `mention` node.

### Data shape

A small seam, two concretes, one value type — domain nouns all.

```
abstract interface class MentionedComment {
  Map<String, dynamic> adfDoc();
}

class PlainComment implements MentionedComment { … }
class MentionedText  implements MentionedComment { … }

class MentionRange {
  final String accountId;
  final String displayName;
  final int start;
  final int length;
}
```

`PlainComment` carries the existing `_adfFromPlain` logic, lifted from `lib/data/jira.dart`. `MentionedText` weaves text runs and ADF `mention` nodes around `MentionRange` entries at paragraph level. A range that straddles a `\n` paragraph break is split into two text runs around the break.

An ADF `mention` node has the shape:

```
{ "type": "mention", "attrs": { "id": "<accountId>", "text": "@Display Name" } }
```

`JiraComment.body` already carries the raw ADF map — no change to that model.

### Networking

One new method on the `Jira` gateway, shaped like its siblings:

```
Future<List<JiraUser>> searchUsers(String query, JiraCredentials credentials)
```

Endpoint: `GET /rest/api/3/user/search?query=…&maxResults=20`.

- Empty query short-circuits and returns `const []` (no fetch fires on bare `@`).
- Debounce lives in the widget (300 ms), not the gateway. The gateway is a plain remote.
- Failures stay quiet: a network slip, 401, or unknown query renders an empty overlay. The field still accepts text; a plain comment still saves.
- `maxResults: 20` — tighter than `assignableUsers`'s 50, since the overlay is small.

The post path's signature shifts:

```
Future<JiraComment> postComment(JiraTicket, MentionedComment, JiraCredentials)
```

Existing callers wrap plain text via `PlainComment(text)` — a one-line shim at the call site.

### Read path

`AdfMarkdown` (`lib/data/adf.dart`) learns one new node type. A `mention` node renders to `**@Display Name**` in markdown. When the `text` attribute is absent or empty, fallback is `**@user**`.

```
case 'mention':
  final attrs = (node['attrs'] as Map<String, dynamic>?) ?? const {};
  final display = (attrs['text'] as String?)?.trim();
  final label = (display == null || display.isEmpty) ? '@user' : display;
  out.write('**$label**');
  break;
```

No link emitted — Heimdall has no user page to link to. The 30 s comments poll surfaces freshly-posted mentions without a manual refresh.

### Composer widget

`lib/ui/mention_field.dart` is the only new file of moderate weight. Public shape:

```
class MentionField extends StatefulWidget {
  const MentionField({
    super.key,
    required this.enabled,
    required this.hintText,
    required this.onSearchUsers,  // (String query) async => List<JiraUser>
    required this.onSubmit,       // (MentionedComment) async => void
  });
}
```

State holds:

- `TextEditingController _controller` — overridden `buildTextSpan` reads `_ranges` and bolds the matched runs.
- `List<MentionRange> _ranges` — sidecar map.
- `OverlayEntry? _popup` + `LayerLink _link` to anchor the overlay to the field.
- `Timer? _debounce` for the 300 ms search cadence.
- `List<JiraUser> _suggestions` and `int _highlighted` for keyboard navigation.

Three private methods carry the moving parts, each under 25 lines per the style guide:

1. `_onTextChanged()` — re-aligns `_ranges` against the new text (shifts spans for inserts before them; drops ranges whose run was mutated); detects an active `@…` query at the caret; schedules the debounced `onSearchUsers` call.
2. `_commitMention(JiraUser u)` — replaces the active `@query` partial with `@${u.displayName} ` (trailing space), records the new `MentionRange`, dismisses the overlay.
3. `_handleKey(KeyEvent)` — when the overlay is open: Down/Up move highlight, Enter/Tab commit, Esc dismiss. When closed: Enter falls through to the field's normal newline.

The overlay uses `CompositedTransformFollower` + `LayerLink` so it tracks the field as the window resizes or the comments pane scrolls. Width pinned at ~240 px; max height ~240 px with internal scroll if results exceed.

Atom-delete works by intercepting backspace via `Shortcuts`/`Actions`: when the caret sits at the right edge of a `MentionRange`, the action deletes the entire span and removes the range; otherwise it falls through to default backspace.

### Wiring into `ticket_detail_page.dart`

`_commentInput()` replaces its inner `TextField` with `MentionField`. The page gains an `onSearchUsers` prop alongside the existing `onPostComment`. `_post()` becomes `_postMentioned(MentionedComment mc)`, threading the seam to `widget.onPostComment(mc)`. The prop type shifts from `Future<JiraComment> Function(String)` to `Future<JiraComment> Function(MentionedComment)`. Existing optimistic-append, polling, and error-snackbar behavior stay untouched.

### README

Two edits:

- **Out of Scope** — strike `mentions` from the list, leaving the others as they stand.
- **Why** — "plain-text comments" becomes "comments with @-mentions".
- **View → Comments pane** — add: *"Type `@` to mention a user; a popup lists matches from the Jira instance, Enter or click commits. Tagged users receive Jira's standard mention notification."*

## Tests

Each new branch names its expectation explicitly via a `final expected = …` declaration before assertion, per `general.md` style.

- `test/data/jira_test.dart` — `searchUsers` against a `DioAdapter`-mocked response: empty-query short-circuit, single-result, malformed-payload tolerance.
- `test/data/mentioned_comment_test.dart`:
  - `PlainComment.adfDoc()` produces the existing paragraph shape.
  - `MentionedText.adfDoc()` weaves text + mention nodes around ranges.
  - A range straddling `\n` splits into two text runs around the break.
  - An empty ranges list collapses to plain-text shape (identical to `PlainComment`).
- `test/data/adf_test.dart` — extends the existing converter tests:
  - A `mention` node renders `**@Display**`.
  - An empty `text` attribute falls back to `**@user**`.
- `test/ui/mention_field_test.dart` — widget tests:
  - Typing `@la` opens the overlay; the supplied `onSearchUsers` is called with `la`.
  - Arrow Down + Enter commits a highlighted mention.
  - Backspace at the right edge of a mention deletes the whole atom.
  - The controller's `buildTextSpan` bolds the mention range.
  - Typing `@` mid-word (no boundary) does NOT open the overlay.

## Files touched

**Modified**

- `lib/data/jira.dart` — add `searchUsers`; change `postComment` signature; lift `_adfFromPlain` into `PlainComment`.
- `lib/data/adf.dart` — extend the converter to handle the `mention` ADF node.
- `lib/ui/ticket_detail_page.dart` — replace `TextField` in `_commentInput()` with `MentionField`; thread `onSearchUsers` prop; shift `onPostComment` type.
- `README.md` — strike `mentions` from Out of Scope; update Why and View → Comments pane.

**New**

- `lib/data/mention_range.dart` — `MentionRange` value type.
- `lib/data/mentioned_comment.dart` — `MentionedComment` seam, `PlainComment` and `MentionedText` concretes.
- `lib/ui/mention_field.dart` — the composer widget.
- `test/data/mentioned_comment_test.dart`, `test/ui/mention_field_test.dart` — new test files; existing test files (`jira_test.dart`, `adf_test.dart`) extended.

## Step breakdown

Seven minimum-sized steps, each leaving the tree working and the test suite green.

1. **`Jira.searchUsers`** — isolated data-layer call, mockable Dio test.
2. **Domain seam** — `MentionedComment`, `PlainComment`, `MentionedText`, `MentionRange`. ADF emission unit-tested.
3. **Post path shift** — `Jira.postComment` takes `MentionedComment`; callers wrap plain text in `PlainComment`. Tree stays working.
4. **Read path** — extend `AdfMarkdown` for the `mention` node. Unit-tested.
5. **`MentionField` widget** — controller with `buildTextSpan`, sidecar map, overlay popup, debounced `searchUsers`, keyboard handling. Widget-tested.
6. **Wire-in** — swap the plain `TextField` in `_commentInput()` for `MentionField`.
7. **README** — strike `mentions` from Out of Scope; name the behavior under View → Comments pane.

## Risks and open considerations

- **Avatar imagery** — the overlay lists names only; avatar URLs are not fetched. If a future change wants thumbnails, `JiraUser` gains an `avatarUrl` field and the overlay row renders a 16 px image. Out of scope for this design.
- **`@` followed by no characters** — overlay opens at empty query but renders no chips (since `searchUsers` short-circuits on empty). Acceptable; the user types at least one char to see suggestions.
- **Right-to-left text** — Heimdall renders Markdown LTR; no RTL composer support is asked for here. The overlay's anchor uses caret pixel position, which works in either direction; styling is unchanged.
- **Multi-account orgs** — `/user/search` returns users from the Jira instance the credentials point at. Heimdall supports one credential set per install, so this matches.
- **Drafts** — Heimdall does not persist in-progress comment drafts; closing the detail page discards. The sidecar `_ranges` map shares that lifetime.

## Out of scope (deliberate)

- Editing existing comments to add or remove mentions.
- Mention groups (`@team` style) — not part of Jira's mention model on standard Cloud.
- Notifying-by-typing autocomplete on the description field — composer only.
- Persisting in-progress drafts across detail-page closes.

## Approval gate

After this spec is reviewed and approved, the work proceeds to the `writing-plans` skill, which converts the step breakdown into a per-step implementation plan. No code is written before that plan exists.
