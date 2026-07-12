# Read the Dock through cfprefsd, not the plist file

BetterSnap reads the Dock's Pinned Apps with `CFPreferencesCopyAppValue` against the
`com.apple.dock` domain, and never opens `~/Library/Preferences/com.apple.dock.plist`.

The plan originally did the opposite, on the stated grounds of avoiding "`cfprefsd`
cross-process cache staleness". That reasoning is exactly backwards. The Dock hands its
changes to `cfprefsd`, which batches writes and flushes to disk lazily - so the daemon
is the fresh source and **the file is the stale one**.

Measured on this machine, reordering a Dock icon:

```
20.78s  CFPREFSD changed  mod-count=307
27.30s  FILE     changed  mod-count=307
```

**6.5 seconds** of lag, which is precisely the delay the user reported between dragging
a Dock icon and BetterSnap noticing. Note this was never a cost of the lazy design in
[0005](./0005-nothing-happens-until-a-key-is-pressed.md): a `DispatchSource` watcher would have watched that same file and could not have
fired any earlier either. The lag was in the source, not the detection.

There is no trade-off to weigh here, because `cfprefsd` also turns out to be *faster*:

| per press | |
| --- | --- |
| `stat()` the file (the freshness check we had) | 0.7 us |
| `CFPreferencesAppSynchronize` + read `mod-count` | 0.7 us |
| Rebuild the Slot Map via `cfprefsd` | 3.4 us |
| Rebuild the Slot Map by parsing the file | 29.8 us |

Same cost to check, roughly nine times cheaper to rebuild, and six seconds fresher. The
Bookmark blobs survive the read intact, which is the one thing this depended on.

## Consequences

`CFPreferencesAppSynchronize` must be called before each read. Without it `cfprefsd`
serves a snapshot cached inside our own process, and we would never see a Dock change at
all - the reads would be fast, consistent, and permanently wrong.

Freshness is now checked by comparing the Dock's `mod-count`, which it bumps on every
change to its contents, rather than by `stat`ing a file. `DockModel.parse` therefore
takes an already-read preference dictionary rather than plist bytes, which also makes it
trivially testable without fixture files on disk.

[0005](./0005-nothing-happens-until-a-key-is-pressed.md) is unaffected: this is still one cheap read on the press, and still nothing
whatsoever between presses.
