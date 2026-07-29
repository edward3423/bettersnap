# Shift on a Chord opens a new instance

Adding Shift to a Chord - `⌥⇧3` where `⌥3` is the plain Chord - opens a **second copy** of that Slot's app instead of showing the running one. A new window is not what this means: it is a separate process with its own pid, the same thing `open -n` does.

The press rule from [0003](./0003-second-press-hides.md) is not consulted at all. "Give me another one" is unambiguous whatever state the app is in, including not running, so there is nothing to decide and no state to read - the shifted Chord skips straight to LaunchServices.

## Shift, and not a modifier the user picks

Every Slot's key is registered twice: once with the Modifier Set, once with the Modifier Set plus Shift. Shift is hardcoded as the discriminator rather than being a second configurable set, because a second set would have to be checked against the first for collisions on every change, would double the surface area of the settings menu, and Shift is what every other macOS affordance already means by "same thing, but more of it".

Ten Chords became twenty, so a Chord is no longer identified by its Slot alone. `Chord` is a Slot plus a `PressIntent`, packed into the single `UInt32` Carbon allows for a hotkey ID - Slot in the low byte, intent above it. A `Chord` that decodes to an intent this build does not know is dropped rather than misread as Slot 3.

## When Shift is one of the modifiers, there is no new instance

Shift is a legal choice in the Modifier Set. Choosing it makes `⌥⇧3` the *plain* Chord, and there is then no keystroke left that means "new instance" - the two would be the same registration, and only the first would win.

That case is not worked around. The shifted Chords are simply not registered, and the menu says so: `Add ⇧   New instance   (unavailable: ⇧ is a modifier)`. The alternative - silently dropping Shift from the plain Chord, or picking some other discriminator when Shift is taken - changes the user's chosen Chords out from under them to preserve a secondary feature. Picking Shift as a modifier costs you new instances, visibly.

## Consequences

**Most apps refuse.** Finder, Safari, Mail and every app declaring `LSMultipleInstancesProhibited` are handed the request anyway and activate the existing copy instead. We do not try to predict this: knowing would mean reading each app's `Info.plist` on the hot path, and LaunchServices would still be the one enforcing it. A shifted Chord on such an app behaves as an Open - which is a reasonable thing for it to have done.

**Ten more Chords are swallowed.** [0005](./0005-nothing-happens-until-a-key-is-pressed.md) already accepted that all ten plain Chords are registered whether or not a Slot is bound, so an unbound Chord eats the keystroke. That now applies to the shifted set too: `⌥⇧8` no longer types `⁃`, bound or not. Same trade, twice the surface.

**Auto-repeat suppression stops being cosmetic.** A held plain Chord that strobed would look silly. A held shifted Chord that strobed would launch copies of an app until the machine gave up. The release gate in `HotKeyManager` is per-`Chord` and unchanged in mechanism, but it is now load-bearing.

**Still no permissions.** `RegisterEventHotKey` and `NSWorkspace.OpenConfiguration.createsNewApplicationInstance` are both permission-free, so [0001](./0001-zero-tcc-permissions-is-a-hard-constraint.md) holds.
