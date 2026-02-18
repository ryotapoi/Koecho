# ADR 0004: History storage as JSON file

## Status

Accepted

## Context

Koecho needs to persist a history of pasted texts so users can review and copy them later. The history can grow to hundreds of entries, each containing arbitrary-length text and a timestamp. The app already uses UserDefaults (via the Settings class) for scalar configuration values and small JSON-encoded arrays (scripts, replacement rules).

## Considered Options

- **UserDefaults**: Store history entries as JSON data in UserDefaults alongside other settings. Simple, no new file management code.
- **JSON file in Application Support**: Store history as a standalone JSON file, separate from UserDefaults. Requires file I/O code but decouples history data from app preferences.
- **SwiftData / Core Data**: Use a database for structured storage. Provides querying and migration capabilities.

## Decision

We will store history entries as a JSON file in `~/Library/Application Support/com.ryotapoi.koecho/history.json`, while keeping history-related settings (enabled flag, max count, retention days) in UserDefaults via the existing Settings class.

UserDefaults is designed for small preference data and becomes unwieldy with large blobs. SwiftData adds framework complexity disproportionate to the need (a simple ordered list with no relational queries). A standalone JSON file keeps history data isolated, is easy to inspect and back up, and can be loaded synchronously at startup for the expected scale (~500 entries).

## Consequences

- History data is decoupled from app preferences, so resetting preferences does not erase history (and vice versa)
- The JSON file can be manually inspected, edited, or deleted by users
- No database migration overhead; schema changes require manual JSON migration
- Synchronous file I/O on the main thread is acceptable at ~500 entries but would need revisiting if the limit grows significantly
- HistoryStore requires a directory URL for dependency injection in tests, adding a parameter to its initializer
