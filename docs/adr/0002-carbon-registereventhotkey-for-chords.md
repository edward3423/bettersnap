# Carbon `RegisterEventHotKey` for Chord registration

Chords are registered with Carbon's `RegisterEventHotKey` from `HIToolbox`, an API most people believe was discontinued in 2019. It was not: what Catalina killed was 32-bit Carbon, meaning the old Carbon *UI* framework. Hotkey registration survives, and it survives because Apple has never shipped a replacement - there is still no modern Cocoa API for a system-wide hotkey. Every app in this space bottoms out here, including Rectangle, Raycast, Alfred, `sindresorhus/KeyboardShortcuts`, and the `Snap.app` we are replacing.

We chose it because it is the only mechanism that satisfies [0001](./0001-zero-tcc-permissions-is-a-hard-constraint.md): matching happens inside WindowServer, so our process gets **zero wakeups** while the user types in other apps, and it needs no permission. The sole alternative, `CGEventTap`, requires an Input Monitoring prompt and wakes us on every keystroke system-wide.

Verified against this machine (macOS 26.5.2, build 25F84) rather than taken on faith: `_RegisterEventHotKey` is exported from the live dyld shared cache on the arm64e slice, and `CarbonEvents.h` declares it with **no deprecation attribute** - which is meaningful, because the same header carries 71 deprecation markers on other APIs, so Apple actively curates this file and has deliberately left the hotkey API unmarked.

## Consequences

We are depending on a legacy framework that Apple could in principle remove, so registration lives behind a `HotKeyBackend` protocol with `CarbonHotKeyBackend` as the only implementation. If the API ever disappears, swapping in a `CGEventTapBackend` is a contained, single-file change - though note that doing so would break [0001](./0001-zero-tcc-permissions-is-a-hard-constraint.md), so it is a last resort and not a neutral swap. The seam costs nothing to add now.

Carbon is main-thread only, so `HotKeyManager` is `@MainActor`.
