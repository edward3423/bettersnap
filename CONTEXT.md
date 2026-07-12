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
Bring a visible app to the front. A fast path, and a narrow one: it will not unhide an app, will not switch Space, and will not open a window for an app that has none.
_Avoid_: focus, raise, switch to, front

**Hide**:
Send a running app's windows away without quitting it. What a Chord does when its app is already Frontmost *and* showing a Visible Window.
_Avoid_: minimize, close, dismiss

**Open**:
Hand an app to LaunchServices and let it decide what showing it means - launching it, unhiding it, switching to its Space, or opening a window for it. What clicking a Dock icon does. Everything that is not a Hide or an Activate is an Open.
_Avoid_: launch, reopen, restore, show (these name the individual cases Open deliberately does not distinguish between)

**Visible Window**:
A normal window an app is showing on screen right now. The only window question that can be answered honestly from outside an app: every app also owns off-screen windows that are indistinguishable from real ones, so "does this app have any windows" has no reliable answer at zero permissions.
_Avoid_: window count, open windows
