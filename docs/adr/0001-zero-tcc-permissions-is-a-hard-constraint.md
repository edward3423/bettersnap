# Zero TCC permissions is a hard constraint

BetterSnap will never request an Accessibility or Input Monitoring permission, and this is treated as a design constraint rather than a preference: any feature that requires one is cut, not escalated to. The reason is that the two obvious permission-requiring paths are exactly the ones that defeat the app's purpose. `CGEventTap` (Input Monitoring) wakes our process for every keystroke in every application, which is the battery cost we exist to eliminate, and it can be silently disabled by the system on timeout. `AXUIElement` (Accessibility) would only buy us within-app window cycling.

Everything the app actually does - Activate, Hide, Launch, Reopen, reading the Dock, and detecting a Windowless App via `CGWindowListCopyWindowInfo` - is reachable from a process with no TCC grants at all.

This is not an assumption. The incumbent `Snap.app` is a background agent that registers Carbon hotkeys and calls `activateWithOptions:`, and `nm -u` shows it imports **no `_AX*` symbols whatsoever** - it holds no Accessibility grant and never asks for one. It activates arbitrary apps successfully on this machine, on macOS 26.5, today. An earlier draft of the plan treated "is activation from a background agent still reliable on Tahoe?" as its second-biggest unknown, with an optional Accessibility escalation held in reserve as the fallback. The unknown was already disproven by the app we are replacing, and that fallback - which would have contradicted this ADR outright - is dropped.

## Consequences

The user is never shown a permission prompt, and the app works the instant it is launched.

The cost is a permanently closed door: cycling between windows of the same app on repeat presses is impossible and will stay impossible. This is worth writing down because it is the obvious "missing" feature and someone will propose adding it. Adding it means giving up the zero-prompt property and taking on the Accessibility permission, which is a change to the product, not an enhancement.

Note that this constraint is narrower than it first appears. `Hide` is plain AppKit (`NSRunningApplication.hide()`) and costs no permission, so hide-on-second-press is available to us - see [0003](./0003-second-press-hides.md). An early draft of the plan wrongly assumed Hide required Accessibility and dropped the behaviour for nothing.
