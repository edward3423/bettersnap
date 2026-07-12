# Let LaunchServices decide how to show an app

Anything that is not a Hide or a plain Activate is handled by handing the app to
`NSWorkspace.openApplication`. One call covers launching an app that is not running,
unhiding a Hidden one, switching to the Space its windows are on, and making a
Windowless App produce a window. We do not branch between those cases, because we
cannot reliably tell them apart - and we do not need to, because the app itself can.

This is exactly what the Dock does when you click an icon.

## Why: you cannot count an app's windows from outside it

The original design asked `CGWindowListCopyWindowInfo` whether an app owned any
normal window, filtering on `kCGWindowLayer == 0`. That filter does not work. Measured
on this machine with **no** Finder and **no** Safari windows open, both apps still own
several layer-0 windows: four strips of 1470x33 (the screen width by the menu bar
height, at the origin) and, for Safari, a 64x64. So `ownsAnyWindow` returned `true` for
every app, always, the press rule never reached its Reopen branch, and pressing
Option+1 with no Finder window open switched to Finder and showed nothing - which is
precisely the bug the Reopen branch had been added to fix.

There is no attribute that separates these phantoms from a real window. Dumping every
key of every layer-0 window, a real Safari window and a phantom agree exactly on
`kCGWindowAlpha` (1), `kCGWindowSharingState` (1), `kCGWindowStoreType` (1) and
`kCGWindowMemoryUsage` (2368). Only two things differ:

- `kCGWindowName` - unusable. Window titles are redacted without a Screen Recording
  permission, which we will not take (see [0001](./0001-zero-tcc-permissions-is-a-hard-constraint.md)). The probe that found this ran under the terminal's TCC
  identity, which has that grant; BetterSnap does not and would read empty strings.
- `kCGWindowIsOnscreen` - present on real windows, absent on phantoms.

So the only usable signal is "is it on screen", and that cannot answer "does this app
have windows", because a Hidden app's windows are not on screen, and neither are the
windows of an app on another Space.

## What we ask instead

We narrowed the question until the signal we have actually answers it. The window check
now asks only: **is this app showing a normal window on screen right now?** It is used
solely to decide whether a frontmost app is worth hiding, and for a frontmost app
"on screen" is the right definition by construction - so `.optionOnScreenOnly` is
correct, the phantoms are excluded because they are off-screen, and the Spaces and
Hidden problems never arise because we no longer ask about those apps at all.

The full rule is then three lines:

1. Frontmost **and** showing a window - Hide it.
2. Showing a window, not frontmost - Activate it. Sub-millisecond, one Mach message.
3. Anything else - Open it, and let the app decide what that means.

## Consequences

The fast path survives for the common case, which is switching to an app you can see.

Every other press costs a LaunchServices round-trip rather than a Mach message. That is
slower, and the original plan avoided it for exactly that reason - but it buys
correctness in four situations we were otherwise getting wrong, and it is what happens
when you click a Dock icon, which nobody experiences as slow.

An app that is frontmost with all its windows minimized will Open, producing a new
window rather than un-minimizing the old one. Un-minimizing requires Accessibility,
so this is a deliberate consequence of [0001](./0001-zero-tcc-permissions-is-a-hard-constraint.md).

**Do not reintroduce a window count.** If a future change seems to need "how many
windows does this app have", it is asking a question the operating system will not
answer honestly at zero permissions. Narrow the question instead.
