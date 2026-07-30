# BetterSnap

Instant Dock app switching with Option+Number, Windows-taskbar style.

`⌥1` is Finder, `⌥2` is the first app pinned to your Dock, `⌥3` the second, and so on
through `⌥0` for the tenth. **Slot N is the Nth icon in your Dock.** Press a chord to
bring that app to you; press it again to send it away. Hold Shift as well - `⌥⇧3` - and
you get a new window of the app instead.

A background agent with **no menu bar clutter beyond one icon and nothing running at all
when idle** - no timers, no polling, no file watchers, no notification observers. Between
keypresses the process is not merely quiet, it is inert. The only permission it can ask
for is Accessibility, and only if you use the Shift chords.

See [CONTEXT.md](./CONTEXT.md) for terminology and [docs/adr/](./docs/adr/) for why it is
built the way it is.

## Requirements

- Apple Silicon Mac running macOS 26 (Tahoe) or later.
- Command Line Tools for Xcode. **Full Xcode is not required** - the CLT SDK ships
  AppKit, which is all this needs.
- A code signing identity. The `Makefile` defaults to `voice-assistant-dev`; check what
  you have with:

  ```sh
  security find-identity -v -p codesigning
  ```

  Any identity works, including a self-signed one, because BetterSnap does not use
  `SMAppService`. Override it per-invocation if yours is named differently:

  ```sh
  make install IDENTITY="Your Identity Name"
  ```

## Build and install

```sh
make install
```

That compiles a release arm64 binary, assembles the `.app` bundle by hand, signs it, and
copies it to `/Applications/BetterSnap.app`, replacing any previous copy and quitting the
running instance first.

Then launch it:

```sh
open /Applications/BetterSnap.app
```

**Always launch with `open`**, never by running the binary inside the bundle directly. A
direct exec does not register the app with LaunchServices, and both app activation and the
`UserDefaults` domain then misbehave.

`make run` does both steps in one go.

## Everything else

| | |
| --- | --- |
| `make` | Build and bundle, without installing. Output lands in `build/`. |
| `make test` | Run the test suite. |
| `make install` | Build, sign, and install to `/Applications`. |
| `make run` | `make install`, then launch it. |
| `make clean` | Remove `.build/` and `build/`. |

### About the tests

Run them with `make test`, not `swift test`. `swift test` cannot work on a machine without
Xcode: the Command Line Tools toolchain ships neither XCTest nor the swift-testing library
(only swift-testing's *macro plugin*, without the library behind it), and the standalone
swift-testing package compiles but fails to link, because SwiftPM's generated test runner
expects `_TestingInterop` from the toolchain's bundled copy.

So the tests are an ordinary executable with a small harness. They print each check and
exit non-zero on failure, which is what a test framework is actually needed for. See
[Tests/BetterSnapTests/Harness.swift](./Tests/BetterSnapTests/Harness.swift).

## Using it

Click the menu bar icon to see what every slot is currently bound to, change which
modifiers the chords use (any combination of Control, Option, Command and Shift), or quit.

Reorder your Dock, or pin and unpin apps, and the change takes effect on the very next
keypress. There is nothing to restart and nothing watching.

### A new window

Add Shift to any chord - `⌥⇧3` - and BetterSnap asks that app for *one more window*, on
the same running instance: same Dock tile, one `⌘Q`. It does this by pressing the app's
own plain `⌘N` menu item, found by its shortcut rather than its name so localization does
not matter. Apps where `⌘N` means a new *document* give you exactly that; an app with no
plain `⌘N` at all gets you a beep. If the app is not running, the chord simply launches
it. See [ADR 0008](./docs/adr/0008-shift-opens-a-new-window.md).

This is the one feature that needs a permission - see
[Permissions](#permissions) below.

If you pick Shift as one of your modifiers, this feature turns off - `⌥⇧3` is then your
*ordinary* chord, and there is no keystroke left to mean "new window". The menu says so
when that happens.

### Start on login

Not built in, deliberately - it would have meant depending on `SMAppService`, which needs
the app to be signed in ways a personal build cannot rely on. Add it by hand instead:

**System Settings → General → Login Items → `+`** and choose `/Applications/BetterSnap.app`.

### Permissions

One, optional: Accessibility, used only to press an app's `⌘N` menu item for the Shift
chords. The prompt appears the first time you press a Shift chord at a running app -
never at launch, and never if you don't use the feature. macOS shows it once; if you
missed it, the menu bar's `New window (grant Accessibility…)` line takes you to the right
System Settings pane. Deny it and every plain chord still works.

Everything else runs at zero TCC permissions, and Input Monitoring is never requested -
see [ADR 0001](./docs/adr/0001-zero-tcc-permissions-for-the-core.md). Repeat presses
still cannot cycle between windows *within* an app; that remains deliberately unbuilt.

### Two things that will surprise you

**An unbound chord does nothing, and swallows the keystroke.** If your Dock has six pinned
apps, `⌥8` is dead - and it no longer types `•` either. That is the deliberate price of
having nothing watch the Dock: all ten chords are always registered, so pinning an eighth
app makes `⌥8` live on the next press with no watcher involved. See
[ADR 0005](./docs/adr/0005-nothing-happens-until-a-key-is-pressed.md). The same is true
of the Shift variants: `⌥⇧8` is swallowed too.

**Command is a poor choice of modifier.** Nothing stops you selecting it, but `⌘1` through
`⌘9` are tab-switching shortcuts in most browsers and editors, and BetterSnap would take
them system-wide.
