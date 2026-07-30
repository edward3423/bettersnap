# Zero TCC permissions for the core; Accessibility only for New Window

The core of BetterSnap - everything a plain Chord does - runs with no TCC grants at all, and Input Monitoring is never requested under any circumstances. Accessibility is requested lazily, and only when a Shift-carrying Chord actually needs it - see [0008](./0008-shift-opens-a-new-window.md).

This ADR originally stated a harder rule: *zero* TCC permissions, ever, with any feature requiring one cut rather than escalated to. That rule fell when the new-instance feature of the original 0008 shipped and turned out to be the wrong feature: a second process gets its own Dock tile and its own Cmd+Q, where what a Shift Chord means is "one more window on the *same* app". A new window cannot be asked for from outside a process without a TCC grant - every route (Apple event, AX menu press, synthesized keystroke) costs Automation or Accessibility. Accessibility was judged worth it, and this ADR was amended rather than the feature cut, reversing the original trade.

What survives of the original rule, and why:

**Input Monitoring is still banned outright.** `CGEventTap` wakes our process for every keystroke in every application, which is the battery cost we exist to eliminate, and it can be silently disabled by the system on timeout. No feature gets to buy it.

**The core still holds at zero.** Everything a plain Chord does - Activate, Hide, Launch, Reopen, reading the Dock, and detecting a Windowless App via `CGWindowListCopyWindowInfo` - is reachable from a process with no TCC grants. This is not an assumption: the incumbent `Snap.app` registers Carbon hotkeys and calls `activateWithOptions:`, and `nm -u` shows it imports **no `_AX*` symbols whatsoever**, yet activates arbitrary apps successfully on macOS 26.5 today.

**Accessibility is scoped, not general.** The grant is used for exactly one thing: pressing a target app's own Cmd+N menu item. Within-app window *cycling*, the other thing Accessibility would buy, is still not built - that remains a deliberate cut, not an accident of the permission being absent.

## Consequences

A user who never holds Shift never sees a permission prompt, and the app works the instant it is launched. The prompt appears on the first Shift Chord pressed at a running app, which is the moment the user is asking for the thing the permission buys. macOS shows that prompt once; afterwards the menu bar shows `New window (grant Accessibility…)` as a clickable line straight to the right System Settings pane.

Denying the grant costs exactly the Shift Chords and nothing else. Every plain Chord keeps working, because the Show path never touches an `AX*` call.

The Accessibility grant is tied to the code signing identity. The `Makefile` signs every build with the same identity, so rebuilds keep the grant; building with a different identity means granting again.
