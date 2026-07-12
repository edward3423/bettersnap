# BetterSnap - instant Dock app switching with Option+Number

Terminology in this document is defined in [CONTEXT.md](../CONTEXT.md). Decisions are recorded in [docs/adr/](../docs/adr/).

## Context

`Snap.app` maps modifier+number to Dock slots, Windows-taskbar style, but it is slow. Verified against the binary:

- `lipo -archs` reports **`x86_64 i386`** - no arm64 slice, so every invocation runs through **Rosetta 2** on Apple Silicon. This, and not anything it does at runtime, is why it is slow.
- `nm -u` shows it imports `_RegisterEventHotKey` and calls `activateWithOptions:`, and imports **no `_AX*` symbols at all** - it is a zero-permission background agent. It also imports no `CGWindowList`, so it never checks whether an app is showing a window, which is why `⌥1` on Finder with no windows open appears to do nothing.

Goal: a native arm64 replacement that is instant, runs as a background agent, and is **completely inert when idle** - not "low power", but receiving no events and never being scheduled.

Scope: **personal tool, this Mac only.** Self-signed, no notarization, `LSMinimumSystemVersion 26.0`. No distribution concerns.

## Behaviour

- **Slot 1 is Finder. Slots 2..10 are the Pinned Apps in Dock order.** So Slot N is the Nth icon in your Dock. Recent Apps and `persistent-others` (Downloads, Trash) are ignored.
- Keys **1-9 and 0** (0 = Slot 10), matching Windows.
- Default Modifier Set: **Option**. Changeable to any combination of Control / Option / Command / Shift.
- **A Chord toggles.** Press to bring the app to you; press again to send it away. See [ADR 0003](../docs/adr/0003-second-press-hides.md) and [ADR 0006](../docs/adr/0006-let-launchservices-decide-how-to-show-an-app.md):

  | App state | Action |
  | --- | --- |
  | Frontmost, showing a Visible Window | **Hide** |
  | Showing a Visible Window, not frontmost | **Activate** - one Mach message |
  | Anything else: not running, Hidden, on another Space, no windows | **Open** - activate, then hand it to LaunchServices |

  A Chord Hides only when the app is genuinely showing you something. Hiding Finder-with-nothing-open - the most common state of the most-used Slot - would be invisible and read as broken.

  The last row is one case, not four, because those four states **cannot be told apart from outside the app**. Every app owns off-screen layer-0 windows indistinguishable from real ones, so "does this app have any windows" has no honest answer at zero permissions. `Open` delegates the question to the app, which is the only thing that knows. This is what clicking a Dock icon does.

- **All ten Chords are always registered**, including Slots with no app. An unbound Chord does nothing, and is swallowed rather than passed through: with the default Option modifier, `⌥8` no longer types `•`. This is the deliberate price of having no Dock watcher - see [ADR 0005](../docs/adr/0005-nothing-happens-until-a-key-is-pressed.md).
- **Holding a Chord acts once.** Auto-repeat is suppressed by gating on key release; a genuine double-tap still toggles at any speed.
- Menu bar icon, always visible. Clicking it opens a menu listing the live Slots (`⌥1 Finder`, `⌥2 System Settings`, …), the four Modifier checkboxes, and Quit. **There is no settings window and no login item.**

On the current Dock: `⌥1` Finder, `⌥2` System Settings, `⌥3` Safari, `⌥4` WhatsApp, `⌥5` iTerm2, `⌥6` Voice Assistant, `⌥7` App Store. Slots 8, 9, 10 are unbound and do nothing.

**Start on login** is cut from v1. It costs nothing to get by hand: System Settings > General > Login Items > `+`. That route needs no `SMAppService`, so the plan's biggest unknown is gone.

## Key technical decisions

| Concern | Decision | Why |
| --- | --- | --- |
| Chord registration | Carbon `RegisterEventHotKey`, behind a `HotKeyBackend` protocol | The only mechanism needing no TCC permission, and matching happens inside WindowServer so we get **zero wakeups** while the user types elsewhere. See [ADR 0002](../docs/adr/0002-carbon-registereventhotkey-for-chords.md). |
| Hotkey library | **None** - hand-roll ~100 lines | `KeyboardShortcuts` exists mainly for its recorder UI. Our config is four checkboxes over fixed number keys. |
| Activate | `NSRunningApplication.activate(options: .activateAllWindows)` | Sub-millisecond Mach message. `.activateAllWindows` is required - the default only raises the key window, which is wrong for "show me that app". Only used when the app is already visible. |
| Hide | `NSRunningApplication.hide()` | Plain AppKit, **no permission**. The plan originally dropped hide-on-second-press believing it needed Accessibility. It does not. |
| Open | `NSRunningApplication.activate` **and then** `NSWorkspace.openApplication(at:configuration:)`, `addsToRecentItems = false` | Takes both, and they are not interchangeable: activate raises windows that already exist and follows them across Spaces, LaunchServices creates one when there are none. Finder with a window on another Space ignores the LaunchServices reopen entirely and just takes the menu bar. `addsToRecentItems` defaults to `true` and would pollute Recent Items on every press. |
| Visible-window check | `CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID)`, filtered on owner PID and `kCGWindowLayer == 0` | Answers only "is this app showing me a window right now", which is the sole window question we need. `layer == 0` alone does **not** mean "a real window": with nothing open, Finder and Safari each still own several off-screen layer-0 windows (1470x33 menu-bar strips, a 64x64) that are identical to real ones in alpha, sharing state, store type and memory usage. On-screen-ness is the only usable discriminator - see ADR 0006. Permission-free (only window *titles* need Screen Recording, and we read none). |
| App resolution | Resolve the Dock's `tile-data.book` **Bookmark**, exactly as the Dock does | Path-based resolution breaks when an app moves. Resolving as the Dock resolves makes "Slot N is the Nth Dock icon" true by construction. See [ADR 0004](../docs/adr/0004-resolve-apps-via-the-docks-bookmark-blob.md). |
| Dock source | `CFPreferencesCopyAppValue` on `com.apple.dock`, **never the plist file** | The file lags `cfprefsd` by a measured **6.5 seconds**, because the daemon flushes to disk lazily. It is also ~9x slower to parse. Must call `CFPreferencesAppSynchronize` first or we read our own stale in-process cache forever. See [ADR 0007](../docs/adr/0007-read-the-dock-through-cfprefsd-not-the-plist-file.md). |
| Dock change detection | **None.** Read the Dock's `mod-count` on press (0.7us); rebuild the Slot Map only if it changed | No watcher, no observers, no timers, nothing running at idle. See [ADR 0005](../docs/adr/0005-nothing-happens-until-a-key-is-pressed.md). |
| Build | SPM executable + `Makefile` that assembles the `.app` | Xcode is not installed; the CLT SDK ships AppKit, which is all we now need. |
| Signing | Self-signed `voice-assistant-dev` | Dropping `SMAppService` means ad-hoc would do, but a stable identity is free and avoids surprises. |
| Sandbox | **Not sandboxed** | A sandboxed app cannot read `~/Library/Preferences/com.apple.dock.plist`. |
| Persistence | One `Codable` blob in `UserDefaults` - just the Modifier Set | Never call `synchronize()`. On decode failure, fall back to Option. |

## Hot path

A press costs one preference read, a dictionary lookup, an array scan, and one Mach message.

1. Ask `cfprefsd` for the Dock's `mod-count` (0.7us). Unchanged since last time (the overwhelmingly common case) → use the cached Slot Map. Changed → rebuild it (3.4us).
2. `slots[n]` → bundle identifier.
3. Scan `NSWorkspace.shared.runningApplications` for that identifier. ~100 objects, microseconds.
4. Decide via the pure press rule, then act.

A Bookmark is resolved only when we actually need to Open an app, never to Activate or Hide one.

## Files

```
Package.swift
Makefile                              # build + bundle + sign + install
Resources/Info.plist
Sources/BetterSnap/
  main.swift                          # NSApplication bootstrap, AppDelegate
  Config.swift                        # Modifier Set in UserDefaults
  DockModel.swift                     # PURE: Dock prefs -> Slot Map; Bookmark resolution
  PressRule.swift                     # PURE: decide(AppState) -> Action
  HotKeyManager.swift                 # HotKeyBackend protocol + CarbonHotKeyBackend
  DockSource.swift                    # cfprefsd-backed Slot Map, rebuilt lazily on mod-count
  AppSwitcher.swift                   # queries runningApplications; executes an Action
  StatusItemController.swift          # NSStatusItem + NSMenu
Tests/BetterSnapTests/
  DockModelTests.swift                # fixture plists, incl. the nasty real ones
  PressRuleTests.swift                # all six branches + precedence
  KeyCodeTests.swift                  # the ten virtual keycodes
```

Deleted relative to the first draft: `DockWatcher.swift`, `LoginItem.swift`, `SettingsWindowController.swift`, `SettingsView.swift`, and SwiftUI entirely.

## Implementation notes that will otherwise cost hours

**Virtual keycodes are not sequential.** From `Events.h`: `kVK_ANSI_1 = 0x12`, `2 = 0x13`, `3 = 0x14`, `4 = 0x15`, `5 = 0x17`, `6 = 0x16`, `7 = 0x1A`, `8 = 0x1C`, `9 = 0x19`, `0 = 0x1D`. **5 and 6 are transposed and 7/8/9/0 are scattered.** `0x12 + n` silently breaks half the Slots. Use an explicit ten-entry table, and unit-test it.

**Carbon modifier constants**: `cmdKey` (0x0100), `shiftKey` (0x0200), `optionKey` (0x0800), `controlKey` (0x1000). Use the named constants. No left/right distinction is available.

**Registration can fail.** macOS 15.0/15.1 briefly rejected Option-only registrations with `-9868` before Apple reverted it in 15.2. Option-only is our default, so check the `OSStatus` of every `RegisterEventHotKey` call. A failed Slot is marked in the menu; no modal alert.

**Suppress auto-repeat.** Handle `kEventHotKeyReleased` as well as `kEventHotKeyPressed`, and refuse to act on a Slot again until its key is released. Safe whether or not Carbon auto-repeats - if it does not, the release handler simply never gates anything.

**Carbon is main-thread only.** Mark `HotKeyManager` `@MainActor`. Register in `applicationDidFinishLaunching`. Route events by `EventHotKeyID.id` via `GetEventParameter`.

**Dock plist parsing.** Read `persistent-apps` only. `tile-data.bundle-identifier` is usually present but not guaranteed - fall back to the resolved Bookmark's `Bundle(url:)?.bundleIdentifier`. Never string-munge `_CFURLString`: WhatsApp's path contains a literal U+200E, and Safari lives under `/System/Volumes/Preboot/Cryptexes/App/`, not `/Applications`.

**Bookmark resolution** uses `URL(resolvingBookmarkData:options:relativeTo:bookmarkDataIsStale:)` with `.withoutUI` and `.withoutMounting`, so it can never block on a missing volume or throw up a dialog. If it reports stale, use the result anyway and never write back - the Dock plist is the Dock's.

**The menu bar icon must not be removable.** It is the only UI, so leave `NSStatusItem.behavior` at its default and do **not** set `.removalAllowed` - a command-drag out of the menu bar would strand the app with no way back. It must be an SF Symbol with `isTemplate = true`; the Tahoe menu bar is transparent and a non-template image renders badly over arbitrary wallpapers.

**Info.plist**: `LSUIElement = <true/>`, `LSMinimumSystemVersion = 26.0`, `CFBundleExecutable` exactly matching the SPM product name, and a permanently stable `CFBundleIdentifier` of `com.edward.bettersnap` (the `UserDefaults` domain is keyed on it).

**Always launch via `open BetterSnap.app`**, never by exec'ing the binary, or LaunchServices does not register the app and both activation and the `UserDefaults` domain misbehave.

**Quit Snap.app before testing** - it registers the same Chords, and two processes contending for one hotkey is a maddening way to lose an evening.

## Verification

Unit tests (`swift test`, no Xcode needed) cover the pure core: the Slot Map parse against fixture plists including the U+200E and cryptex paths and one with a missing `bundle-identifier`; all six branches of the press rule and their precedence; the ten keycodes.

End to end, as a real user:

1. `make install && open /Applications/BetterSnap.app`.
2. `⌥3` from another app - Safari comes forward. `⌥3` again - Safari hides. `⌥5` - iTerm2. Quit an app, press its key - it cold-launches.
3. **`⌥1` with no Finder window open - a Finder window appears.** This is the case Snap gets wrong, and the one the first build of BetterSnap got wrong too. See ADR 0006.
4. Hide Safari by hand, then `⌥3` - it comes back with its existing window, not a fresh blank one.
5. Hold `⌥3` down - Safari comes forward once and does not strobe.
6. `⌥9` (unbound) - nothing happens, and no `ª` is typed.
7. Drag a Dock icon to reorder, then press the affected keys - the new order is live **immediately**, with no restart and no multi-second lag. Pin an eighth app, press `⌥8` - it works, with nothing having watched the Dock.
8. Menu bar icon - the menu lists the current Slots. Switch to Control+Option, confirm the old `⌥N` stop working and the new ones work.

Performance and battery, which are the whole point:

9. **Latency**: `os_signpost` from key event to `activate` returning. Well under 1 ms of our own work. Compare side by side against `Snap.app`.
10. **Idle**: leave it running for several minutes, then
    `sudo powermetrics --samplers tasks --show-process-energy -i 1000`
    and confirm **0.0% CPU and 0 idle wakeups/sec**. Then type continuously in another app and confirm the wakeup count stays **flat** - the property `CGEventTap` designs cannot achieve. Then drag Dock icons around and confirm it stays flat too - the property the *watcher* design could not achieve.
11. Confirm there is not a single `Timer`, `DispatchSourceTimer`, `DispatchSource` or notification observer anywhere in the codebase.
