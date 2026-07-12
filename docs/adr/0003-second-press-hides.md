# A Chord toggles: second press Hides

Pressing a Chord whose app is already Frontmost Hides that app, rather than doing nothing. This gives real Windows taskbar parity - Win+3 twice minimizes - and turns every Chord into a peek/dismiss toggle: Option+4 to glance at WhatsApp, Option+4 to send it away.

The plan originally specified "do nothing", on the grounds that hiding would require an Accessibility permission and so would violate [0001](./0001-zero-tcc-permissions-is-a-hard-constraint.md). That was simply wrong. `NSRunningApplication.hide()` is plain AppKit and costs no permission; what actually costs Accessibility is cycling *between* windows of one app, which we are not doing. The behaviour was nearly dropped for a price we were never going to pay.

## The resulting rule

Stated in one line: *a Chord always ends with its app in front of you, unless it already was, in which case it gets out of the way.*

An unbound Slot is the one exception - its Chord does nothing at all.

A Chord Hides **only** when the app is both Frontmost *and* actually showing you a window. Hiding an app that has nothing on screen - Finder with no windows open, which is the most common state of the most-used Slot - is invisible, and the user reads it as the app being broken. Everything else, including that case, ends in the app being shown.

The mechanics of "show it" are in [0006](./0006-let-launchservices-decide-how-to-show-an-app.md), which also records why "does this app have any windows" turned out to be a question that cannot be answered from outside the app, and what we ask instead.

## Consequences

An accidental double-tap Hides the app. The same Chord brings it straight back, so the cost is low and no state is lost.

Because a Chord now Hides on second press, a Hidden app is no longer a rare state - it is the state the previous keypress just created. Any logic that treats Hidden as an edge case is wrong by construction.
