# Changelog

All notable changes to Heimdall are recorded here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); the project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.4.17] — 2026-06-10

### Fixed

- The Windows installer derives its version from `pubspec.yaml` rather than a hard-coded literal, so the installer version no longer drifts from the app version.

## [1.4.14] — 2026-06-01

### Added

- Filter the ticket table by more than one assignee at once: the assignee control is now a checkbox menu that stays open across picks, and reads "N assignees" once several are chosen.
- Open a ticket in its own desktop window from the detail view's title bar, so a list and one or more tickets can sit side by side.

### Changed

- The ticket detail now refreshes the whole ticket — status, assignee, priority, description, sub-tasks, links — on its interval poll, not just comments. The interval eased from 30s to 60s to spare needless calls, and a watched window keeps refreshing while it is visible but unfocused, pausing only when minimized or hidden.

## [1.4.13] — 2026-05-29

### Added

- Expand or collapse every parent's filter-hidden sub-tasks at once from a new toolbar button; the choice persists across launches. Per-row unfold icons still override an individual parent within a session.

## [1.4.12] — 2026-05-29

_Release-pipeline bump; no user-facing changes._

## [1.4.11] — 2026-05-28

### Fixed

- Markdown links and blockquotes in ticket descriptions now read correctly in dark mode.

## [1.4.10] — 2026-05-22

### Added

- Row pulse — rows that changed or newly arrived on a poll briefly pulse, so motion marks what moved.
- Comment timestamps render as relative time ("5m ago", "yesterday").
- Cmd/Ctrl+Enter submits a comment, bypassing the empty-field guard.
- Confirmation prompt before deleting a saved filter.

### Changed

- Ticket polling continues while the window is unfocused.

### Fixed

- Multi-ticker crash on the section view.

## [1.4.9] — 2026-05-22

### Fixed

- The GitHub-release script (`release_github.ps1`) accepts TeamCity's short tag names.

## [1.4.8] — 2026-05-22

### Added

- Windows build and GitHub release scripts for TeamCity CI; the Windows signing certificate is guarded from accidental commit.

## [1.4.7] — 2026-05-21

_Release-pipeline bump; no user-facing changes._

## [1.4.6] — 2026-05-21

_Release-pipeline bump; no user-facing changes._

## [1.4.5] — 2026-05-21

### Fixed

- macOS signing selects the certificate by its SHA-1, avoiding ambiguity when several Developer ID identities share a common name.
- The team-id extraction error message refers to the `IDENTITY_NAME` variable.

## [1.4.4] — 2026-05-21

_Release-pipeline bump; no user-facing changes._

## [1.4.3] — 2026-05-21

_Release-pipeline bump; no user-facing changes._

## [1.4.2] — 2026-05-21

_Release-pipeline bump; no user-facing changes._

## [1.4.1] — 2026-05-21

### Added

- Live ticket preview in the filter edit view.

## [1.4.0] — 2026-05-19

### Added

- @-mention autocomplete in the comments composer.

### Changed

- The macOS DMG is signed with entitlements and an embedded provisioning profile.

## [1.3.1] — 2026-05-18

### Added

- JQL field autocomplete — typing in the JQL box now offers field names and keyword completions, and value suggestions that are context-aware (proposed values depend on the field being filtered).
- Appearance toggle — Light / Dark / System mode, persisted across launches.

## [1.3.0] — 2026-05-14

### Added

- The active tab auto-refreshes every 60 seconds.

## [1.2.0] — 2026-05-12

### Added

- Assignees can be set from both the detail page and the table.
- A filtered parent's hidden sub-tasks surface inline — an indicator on the parent row expands the sub-tasks the filter had elided.

## [1.1.1] — 2026-05-11

### Added

- Inline task lists in the description — ADF `taskList`/`taskItem` nodes render as GFM checkboxes with their TODO/DONE state preserved.
- Task-list toggling — tap a checkbox in the description to flip TODO↔DONE. Heimdall PUTs the modified description back to Jira and updates the local view optimistically; on failure the tick reverts and a snackbar names the error.

## [1.1.0] — 2026-05-11

### Added

- In-app ticket detail page — header, metadata bar, description rendered as Markdown, people, and a comments pane (right on wide windows, below on narrow ones).
- Comments pane auto-refreshes every 30 s while the window is focused; pauses when blurred or hidden.
- Attachment gallery on the detail page — image thumbnails wrap below the description; tap opens full size in a zoomable dialog. Non-image files appear as filename chips that open in the browser.
- Inline image rendering inside descriptions — Jira's rendered HTML is paired positionally with ADF media nodes; loads carry the same Basic auth header the gateway uses.
- Search field beside the tab strip — live-filters visible rows by key, summary, assignee, or status (substring, case-insensitive, in memory).
- "Open by key" action in the AppBar — type a ticket key like `PSG-1234` and press Enter to jump straight to its detail page.
- Sub-tasks and Links sections on the detail page — sub-tasks list flat; links group by their directional label (`blocks`, `is blocked by`, `relates to`). Each row carries type icon, key, summary, and status; tap opens that ticket's detail page on top of the navigation stack.
- Inno Setup script for the Windows installer.
- Developer ID provisioning profile embedded in macOS builds.

### Changed

- macOS install instructions lead with the DMG; the `xattr` quarantine path was corrected.
- README documents GitHub Issues as the project's tracker.

## [1.0.0] — 2026-05-06

### Added

- Initial Flutter desktop scaffold for macOS and Windows.
- Credentials form (base URL, email, API token) backed by `flutter_secure_storage`.
- Filter list management — add, edit, delete; filter ID or raw JQL.
- Ticket list view: per-filter sections with key, summary, and status chip.
- Status transitions on the table's Status cell — pops a sorted transition menu in place.
- Click-through to the default browser via `url_launcher`.
- Manual refresh and pull-to-refresh.
- Empty states for missing credentials and empty filter list.
- App icon — three cream cards stacked diagonally on an indigo rounded square, each bearing a gold bar; reads as a ticket queue. Generated by `tools/generate_icon.py` (Pillow) and propagated to macOS and Windows targets via `flutter_launcher_icons`.
