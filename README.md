# Heimdall

A small desktop window that lists Jira tickets from filters you choose. Read-only — the watchman, not the lawmaker.

Named for the Norse watchman of Bifröst, who marks what approaches.

## Why

Jira's web UI is heavy, slow, and screen-greedy. The friction is not its container — it is the editing chrome itself: the busy panels, the modal dialogs, the bloat. Heimdall ships only what the editing chrome was hiding: a list of titles and statuses, refreshed on demand.

Writes — transitions, comments, edits — are deliberately not in scope. The web handles those, and so does any Jira CLI. Heimdall *shows*.

## Requirements

- [Flutter](https://docs.flutter.dev/) 3.10+ (managed here via [FVM](https://fvm.app))
- An Atlassian account with an [API token](https://id.atlassian.com/manage-profile/security/api-tokens)
- Targets: macOS and Windows desktop

## Setup

```bash
git clone git@github.com:LarryHsiao/Heimdall.git
cd Heimdall
fvm flutter pub get
fvm flutter run -d macos     # or: -d windows
```

## First Run

1. The window opens to an empty state — *No credentials configured.*
2. Open **Settings** (gear icon) and enter:
   - **Base URL** — e.g. `https://your-org.atlassian.net`
   - **Email** — your Atlassian login
   - **API Token** — from `id.atlassian.com` → Security
3. Save, return, and tap **Add filter**. Each filter takes either:
   - A **filter ID** (e.g. `10363`) — Heimdall wraps it as `filter = 10363`
   - A raw **JQL** expression (e.g. `assignee = currentUser() AND resolution = Unresolved`)
4. Tickets render grouped by filter — `KEY · summary` with a status chip.
5. Click any row to open the ticket in the default browser.

## Storage

- **Credentials** — `flutter_secure_storage`: Keychain on macOS, Credential Manager on Windows.
- **Filter list** — `shared_preferences`: JSON-encoded, plain on disk.

## Out of Scope

- Tray residency, menu-bar icon, background polling.
- Writes of any kind — transitions, comments, edits.
- Boards, sprints, admin, full-text search.
- Default filters shipped with the app — every filter is user-added.

## Roadmap

- Window-position and size memory (`window_manager`).
- Auto-refresh on a configurable timer.
- Tests beyond the boot smoke test.

## Project Layout

```
lib/
  main.dart              entry
  app.dart               MaterialApp shell
  data/
    jira_credentials.dart   model
    jira_filter.dart        model + JQL coercion
    jira_ticket.dart        model
    vault.dart              credentials in secure storage
    filters.dart            filters in shared_preferences
    jira.dart               REST gateway (/rest/api/3/search/jql)
  ui/
    tickets_page.dart       main view
    settings_page.dart      credentials form
    filters_page.dart       filter list management
    filter_form_page.dart   add / edit a filter
```
