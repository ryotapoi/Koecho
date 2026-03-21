# ADR 0002: Window scene + NavigationSplitView for settings UI

## Status

Accepted

## Context

Koecho needs a unified settings window to host script management (existing), general settings (new), and future pages (replacement rules, hotkey configuration). The standard approach in SwiftUI is to use a `Settings` scene, which automatically wires Cmd+, to open the settings window.

However, Koecho is a MenuBarExtra-only app with `LSUIElement = YES`. It has no standard menu bar, so the `Settings` scene's automatic Cmd+, keyboard shortcut does not function.

The layout should follow the macOS System Settings / Xcode Settings pattern: a fixed sidebar listing categories on the left, with the selected category's detail view on the right.

## Considered Options

- **Settings scene**: Standard SwiftUI approach. Automatic Cmd+, integration. But non-functional in MenuBarExtra-only apps without a standard menu bar.
- **Window scene + TabView**: Explicit window management. Familiar tab UI, but does not match the macOS System Settings / Xcode Settings sidebar layout.
- **Window scene + NavigationSplitView**: Explicit window management. Sidebar + detail layout matches macOS System Settings and Xcode Settings patterns. Full control over sidebar width and visibility.
- **Multiple Window scenes**: One window per settings category. Fragments the settings experience and increases window management burden.

## Decision

We will use a `Window` scene with a `NavigationSplitView` (fixed sidebar + detail) to host all settings pages. The sidebar has a fixed width with the toggle button removed.

## Consequences

- Settings pages (General, Scripts, future additions) are unified in a single window with a sidebar consistent with macOS conventions
- Adding new pages requires adding a case to `SettingsPage` enum and a corresponding view
- Cmd+, is not available as a shortcut. LSUIElement apps lack a main menu bar, so non-functional shortcuts are not displayed per macOS conventions
- No dependency on `Settings` scene behavior, which may vary across macOS versions for MenuBarExtra-only apps
- Pages that need their own list+detail layout (e.g., Scripts) use `HStack` + `Divider` within the detail area instead of nested `NavigationSplitView`
