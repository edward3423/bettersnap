# Shift on a Chord opens a new window

Adding Shift to a Chord - `⌥⇧3` where `⌥3` is the plain Chord - asks that Slot's app for **one more window on the running instance**, by pressing the app's own plain Cmd+N menu item through the Accessibility API. If the app is not running, the shifted Chord is a plain Open: launching *is* the new window, and costs no permission.

The press rule from [0003](./0003-second-press-hides.md) is not consulted at all. "Give me another window" is unambiguous whatever state the app is in, so there is nothing to decide and no state to read.

This rewrites the original 0008, which opened a new *instance* - a second process, as `open -n` does - via `createsNewApplicationInstance`. That shipped and was wrong in practice: macOS gives every process its own Dock tile and its own menu bar, so each shifted press piled up unpinned tiles on the right of the Dock, and Cmd+Q quit one copy while the others stayed. A second process is what the API offers; a second window is what the keystroke means. The instance semantics were traded away together with the zero-TCC rule that forced them - see the amended [0001](./0001-zero-tcc-permissions-for-the-core.md).

## Found by shortcut, not by name

The menu item is located by walking the app's menu bar for an item whose command character is `N` with no extra modifiers, and pressing it with `AXPress`. Titles would be the obvious key and are the wrong one: they are localized and vary per app - "New Window", "New Finder Window", "New Document" - while the shortcut character survives localization. Plain Cmd+N is what every windowed macOS app means by "one more of whatever your window is", and apps where Cmd+N means a new *document* window are giving exactly what was asked for.

The Apple menu is skipped - it is the system's, not the app's - and only the top level of each menu is searched: that is where the item lives in every app observed, and recursing into submenus makes a miss slower without making a hit likelier.

An app with no plain Cmd+N anywhere - one with no notion of "new window" - gets a beep. There is nothing sensible to fall back to, and a silent swallow would read as the Chord being broken.

## Shift, and not a modifier the user picks

Every Slot's key is registered twice: once with the Modifier Set, once with the Modifier Set plus Shift. Shift is hardcoded as the discriminator rather than being a second configurable set, because a second set would have to be checked against the first for collisions on every change, would double the surface area of the settings menu, and Shift is what every other macOS affordance already means by "same thing, but more of it".

Ten Chords became twenty, so a Chord is no longer identified by its Slot alone. `Chord` is a Slot plus a `PressIntent`, packed into the single `UInt32` Carbon allows for a hotkey ID - Slot in the low byte, intent above it. A `Chord` that decodes to an intent this build does not know is dropped rather than misread as Slot 3.

## When Shift is one of the modifiers, there is no new window

Shift is a legal choice in the Modifier Set. Choosing it makes `⌥⇧3` the *plain* Chord, and there is then no keystroke left that means "new window" - the two would be the same registration, and only the first would win.

That case is not worked around. The shifted Chords are simply not registered, and the menu says so: `Add ⇧   New window   (unavailable: ⇧ is a modifier)`. The alternative - silently dropping Shift from the plain Chord, or picking some other discriminator when Shift is taken - changes the user's chosen Chords out from under them to preserve a secondary feature. Picking Shift as a modifier costs you new windows, visibly.

## Consequences

**This is the app's only permission.** Accessibility is requested lazily, on the first shifted press at a running app, and gates nothing but this feature - the full trade is recorded in [0001](./0001-zero-tcc-permissions-for-the-core.md). Until granted, a shifted Chord shows the system prompt (once) and is otherwise swallowed; the menu bar line `New window (grant Accessibility…)` opens the right System Settings pane afterwards.

**Ten more Chords are swallowed.** [0005](./0005-nothing-happens-until-a-key-is-pressed.md) already accepted that all ten plain Chords are registered whether or not a Slot is bound, so an unbound Chord eats the keystroke. That applies to the shifted set too: `⌥⇧8` no longer types `⁃`, bound or not. Same trade, twice the surface.

**Auto-repeat suppression stays load-bearing.** A held plain Chord that strobed would look silly. A held shifted Chord that strobed would pile up windows until the machine gave up. The release gate in `HotKeyManager` is per-`Chord` and unchanged.

**The new window follows the app's focus rules, not ours.** The target is activated first so the window lands in front; the AX press itself does not need the app frontmost. Apps that put their new window on another Space or inherit an old size are being themselves, and are not corrected.
