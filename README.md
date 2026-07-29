# BetterSnap

Instant Dock app switching with Option+Number, Windows-taskbar style.

`⌥1` is Finder, `⌥2` is the first app pinned to your Dock, `⌥3` the second, and so on
through `⌥0` for the tenth. **Slot N is the Nth icon in your Dock.** Press a chord to
bring that app to you; press it again to send it away. Hold Shift as well - `⌥⇧3` - and
you get a second copy of the app instead.

A background agent with **no menu bar clutter beyond one icon, no permission prompts, and
nothing running at all when idle** - no timers, no polling, no file watchers, no
notification observers. Between keypresses the process is not merely quiet, it is inert.

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

### A new instance

Add Shift to any chord - `⌥⇧3` - and BetterSnap opens a *second copy* of that app: a
separate process, the same thing `open -n` does. Not a new window.

Most apps refuse. Finder, Safari, Mail and anything else declaring
`LSMultipleInstancesProhibited` just come to the front instead, which is LaunchServices'
call and not something BetterSnap can override. Terminals, editors and simulators
generally do oblige. See
[ADR 0008](./docs/adr/0008-shift-opens-a-new-instance.md).

If you pick Shift as one of your modifiers, this feature turns off - `⌥⇧3` is then your
*ordinary* chord, and there is no keystroke left to mean "new instance". The menu says so
when that happens.

### Start on login

Not built in, deliberately - it would have meant depending on `SMAppService`, which needs
the app to be signed in ways a personal build cannot rely on. Add it by hand instead:

**System Settings → General → Login Items → `+`** and choose `/Applications/BetterSnap.app`.

### Permissions

None. BetterSnap never asks for Accessibility or Input Monitoring, and this is a hard
constraint rather than a preference - see
[ADR 0001](./docs/adr/0001-zero-tcc-permissions-is-a-hard-constraint.md). The cost is that
repeat presses cannot cycle between windows *within* an app, which is not possible without
an Accessibility grant.

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
