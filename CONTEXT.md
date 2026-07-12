# BetterSnap

A background agent that binds modifier+number chords to Dock apps, Windows-taskbar style, and switches to them instantly.

## Language

### Slots

**Slot**:
A number, 1 to 10, that a chord can be bound to. Slot 1 is Finder; slots 2 upward are the Pinned Apps in Dock order.
_Avoid_: index, position, shortcut

**Bound Slot**:
A Slot that has an app behind it. Slots past the end of the Dock are unbound, and their chords are never registered at all, so the keystroke reaches whatever app the user is typing in.
_Avoid_: empty slot, active slot

**Slot Map**:
The resolved Slot-to-app table. Rebuilt whenever the Dock changes, never computed while handling a keypress.

### The Dock

**Pinned App**:
An app the user has kept in the Dock (`persistent-apps` in the Dock's own storage). Running-but-unpinned apps and Recent Apps are not Pinned Apps and never get a Slot, because their order is unstable.
_Avoid_: docked app, dock item, dock icon

**Bookmark**:
The blob the Dock stores alongside each Pinned App that says where the app is. It tracks the app across moves and renames, which a plain path does not. It, and not the path, is how the Dock finds an app - and so it is how BetterSnap finds one.
_Avoid_: alias, path, URL

### Input

**Chord**:
The modifier combination plus a number key that triggers a Slot, e.g. Option+3.
_Avoid_: hotkey, shortcut, keybinding, accelerator

**Modifier Set**:
The modifiers shared by every Chord - any combination of Control, Option, Command, Shift. Not per-Slot; one set for all ten.
_Avoid_: modifier mask, flags

### Actions

**Activate**:
Bring a running app to the front. Does not unhide it or open windows for it.
_Avoid_: focus, raise, switch to, front

**Hide**:
Send a running app's windows away without quitting it. What a Chord does when its app is already Frontmost.
_Avoid_: minimize, close, dismiss

**Launch**:
Cold-start an app that is not running.
_Avoid_: open, start, run

**Reopen**:
Ask an already-running app to put a window on screen. Distinct from Activate, which will happily front a Windowless App and show the user nothing.
_Avoid_: restore, show

**Windowless App**:
A running app with no on-screen windows. Finder is the everyday case: it is always running and often has nothing open. Activating one shows only its menu bar, so a Windowless App must be Reopened instead.
_Avoid_: hidden app (Hidden is a different, distinct state)
