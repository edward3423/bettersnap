import BetterSnapCore

private func state(
    running: Bool = true,
    frontmost: Bool = false,
    visible: Bool = true
) -> AppState {
    AppState(isRunning: running, isFrontmost: frontmost, hasVisibleWindow: visible)
}

@MainActor
func pressRuleTests(_ h: Harness) {
    h.section("Press rule")

    h.check(
        "a frontmost app showing a window is hidden, so a Chord toggles",
        PressRule.decide(state(frontmost: true)) == .hide
    )
    h.check(
        "a visible background app is activated, on the fast path",
        PressRule.decide(state()) == .activate
    )
    h.check(
        "an app that is not running is opened",
        PressRule.decide(state(running: false, visible: false)) == .open
    )

    h.section("Press rule: everything ambiguous funnels into .open")

    // We cannot tell these states apart from outside the app, and we do not need to.
    // See ADR 0006.
    h.check(
        "a hidden app is opened, not activated - activate would not unhide it",
        PressRule.decide(state(visible: false)) == .open
    )
    h.check(
        "a windowless app is opened, so a window actually appears",
        PressRule.decide(state(visible: false)) == .open
    )
    h.check(
        "an app whose windows are on another Space is opened, so the Space switches",
        PressRule.decide(state(visible: false)) == .open
    )

    h.section("Press rule precedence, which is the part that is easy to get wrong")

    // The bug that shipped: Finder frontmost with nothing open. Hiding it would be
    // invisible and read as the app being broken, so it must Open instead.
    h.check(
        "a FRONTMOST app with nothing on screen is opened, not hidden",
        PressRule.decide(state(frontmost: true, visible: false)) == .open
    )
    h.check(
        "hide requires BOTH frontmost and a visible window",
        PressRule.decide(state(frontmost: false, visible: true)) == .activate
    )
    h.check(
        "not running beats frontmost",
        PressRule.decide(state(running: false, frontmost: true, visible: false)) == .open
    )
    h.check(
        "a running app is never hidden unless it is in front of you",
        PressRule.decide(state(running: true, frontmost: false, visible: false)) == .open
    )
}
