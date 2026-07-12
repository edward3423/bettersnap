# Nothing happens until a key is pressed

BetterSnap has no timers, no polling, no file watchers, and no notification observers. Between keypresses the process is not merely quiet, it is completely inert - it receives no events and is never scheduled. All work is done lazily, on the press.

On a press: `stat` the Dock plist (~10µs); if it has not changed, use the cached Slot Map; if it has, re-parse and rebuild. Then scan `NSWorkspace.runningApplications` for the Slot's bundle identifier, decide an action, and act. The whole path is sub-millisecond, and a Bookmark is only resolved when we actually need to Launch or Reopen.

## Why not the obvious design

The original plan cached the Slot Map and kept it fresh with a `DispatchSource` vnode watcher on the Dock plist, plus a running-app index maintained from `NSWorkspace` launch/terminate notifications. Both are event-driven and neither polls, so both look free. They are not:

- A vnode watcher **wakes this process on every Dock write** - and the Dock writes several times during a single icon drag.
- The running-app index **wakes this process on every app launch and quit, system-wide**.

They are wakeups spent to save latency no human can perceive, in an app whose entire reason to exist is that the incumbent burns battery. The lazy design has strictly fewer wakeups than the watcher design: zero.

It is also much less code. The watcher was the most bug-prone component in the plan - `cfprefsd` writes atomically via rename, so the watched file descriptor is invalidated on every write and the source must be cancelled, reopened and re-armed, with a debounce on top, plus a `mod-count` comparison to skip no-op reloads, plus an observer on `com.apple.dock` relaunching so that `killall Dock` re-arms it. All of that is now deleted.

The premise it rested on was wrong anyway. The plan justified the cache by claiming the incumbent `Snap.app` is slow because it re-parses the Dock plist on every press. `Snap.app` is slow because it is a 2014 x86_64 binary running under Rosetta 2. Parsing 9 KB of plist costs microseconds.

## Consequences

**All ten Chords are always registered, even for unbound Slots.** This is what makes the design work: pin an eighth app and Option+8 is live on the very next press, with nothing watching the Dock. The price is that an unbound Chord is swallowed rather than passed through - with the default Option modifier, Option+8 no longer types `•`. That is the entire cost of deleting the watcher, and it is worth it.

**A Dock change is observed at the next press, not at the moment it happens.** Nothing observes the Slot Map except a keypress, so there is no one for an eager update to inform.

**Do not add a watcher back.** If a future change makes something *other* than a keypress depend on the Slot Map - a menu that must be live while open, say - reach for a refresh at the moment that thing needs the data, not for a watcher. The inert-at-idle property is the product.
