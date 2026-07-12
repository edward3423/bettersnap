# A Chord toggles: second press Hides

Pressing a Chord whose app is already Frontmost Hides that app, rather than doing nothing. This gives real Windows taskbar parity - Win+3 twice minimizes - and turns every Chord into a peek/dismiss toggle: Option+4 to glance at WhatsApp, Option+4 to send it away.

The plan originally specified "do nothing", on the grounds that hiding would require an Accessibility permission and so would violate [0001](./0001-zero-tcc-permissions-is-a-hard-constraint.md). That was simply wrong. `NSRunningApplication.hide()` is plain AppKit and costs no permission; what actually costs Accessibility is cycling *between* windows of one app, which we are not doing. The behaviour was nearly dropped for a price we were never going to pay.

## The resulting rule

A press resolves in this precedence order, and the order is load-bearing:

1. **Slot is unbound** - the Chord was never registered, so the keystroke passes through to whatever app the user is in.
2. **App is not running** - Launch it.
3. **App owns no windows at all** - Reopen it, so a window actually appears. Finder is the everyday case.
4. **App is Hidden** - unhide, then Activate.
5. **App is Frontmost** - Hide it.
6. **Otherwise** - Activate it.

Stated in one line: *a Chord always ends with its app in front of you, unless it already was, in which case it gets out of the way.*

Rule 3 must precede rules 4 and 5. A Windowless App that is also Frontmost - Finder with nothing open, which is the single most common state of the single most used Slot - would otherwise Hide, which is invisible, and the user would read the app as broken.

## Consequences

The Windowless check must ask "does this app own any normal window at all", using `CGWindowListCopyWindowInfo` with `kCGWindowListOptionAll` filtered on owner PID and `kCGWindowLayer == 0`. It must **not** use `.optionOnScreenOnly`, because a Hidden app has no on-screen windows and would be misread as Windowless. Since a Chord now Hides on second press, "hidden" is no longer a rare state - it is the state the previous keypress just created, so getting this wrong would break the toggle in normal use.

An accidental double-tap Hides the app. The same Chord brings it straight back, so the cost is low and no state is lost.
