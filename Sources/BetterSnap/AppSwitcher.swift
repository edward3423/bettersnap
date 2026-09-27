import AppKit
import BetterSnapCore
import os

@MainActor
final class AppSwitcher {
    private let dock = DockSource()
    private let signposter = OSSignposter(
        subsystem: "com.edward.bettersnap", category: "hotpath"
    )

    func slots() -> [Int: DockSlot] { dock.slots() }

    func press(_ chord: Chord) {
        let interval = signposter.beginInterval("press")
        defer { signposter.endInterval("press", interval) }

        // An unbound Slot is swallowed rather than passed through. That is the price
        // of having no Dock watcher - see ADR 0005.
        guard let slot = dock.slots()[chord.slot] else { return }

        switch chord.intent {
        case .show:
            show(slot)
        case .newWindow:
            // No press rule and no state to read. "Give me another window" is
            // unambiguous whatever the app is doing, including not running at all.
            newWindow(slot)
        }
    }

    /// One more window on the running instance, via the app's own Cmd+N menu item.
    /// The only path in the app that needs a permission - see ADR 0008.
    private func newWindow(_ slot: DockSlot) {
        guard let bundleID = slot.bundleID,
              let running = NSWorkspace.shared.runningApplications.first(where: {
                  $0.bundleIdentifier == bundleID
              })
        else {
            // Not running: launching *is* the new window, and costs no permission.
            open(slot)
            return
        }

        guard NewWindow.isTrusted else {
            // The chord is swallowed either way; the prompt says why. macOS only
            // shows it once - after that the menu bar item is the way back in.
            NewWindow.promptForTrust()
            return
        }

        // Ask for the window *before* activating, and activate only once it exists.
        // Activation raises the app's key window and follows it to its Space; done
        // first, that drags your old window forward (and you to its Space) before
        // the new one is even built. Done after, the key window is the new one, so
        // that is all that moves. Neither the AX press nor a posted keystroke needs
        // the app frontmost. The caveats are in ADR 0008.
        let pid = running.processIdentifier
        let before = windowIDs(pid: pid)
        NewWindow.open(pid: pid)

        // A hidden app cannot be helped: unhiding is all-or-nothing in macOS, and
        // the new window stays hidden with the rest until the app is activated, so
        // there is nothing to wait for.
        if running.isHidden {
            running.activate(options: [])
            return
        }

        // The app builds the window on its own schedule - the press has returned long
        // before it exists - so its arrival is watched for rather than assumed. The
        // deadline covers apps that create no window at all; activation is then the
        // same as before, just late.
        waitForWindow(pid: pid, besides: before, deadline: Date().addingTimeInterval(1.5)) {
            running.activate(options: [])
        }
    }

    private func waitForWindow(
        pid: pid_t, besides known: Set<CGWindowID>, deadline: Date,
        then activate: @escaping () -> Void
    ) {
        if !windowIDs(pid: pid).isSubset(of: known) || Date() >= deadline {
            activate()
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(16)) { [weak self] in
            self?.waitForWindow(pid: pid, besides: known, deadline: deadline, then: activate)
        }
    }

    /// Every layer-0 window the app owns, on any Space. A new window may land on the
    /// app's Space rather than yours - see ADR 0008 - so on-screen-only would miss it.
    /// The set includes the off-screen helper windows ADR 0006 warns about, which is
    /// fine here: the question is not "is there a window" but "is there a *new* one",
    /// and apps create those helpers alongside the real window, not in its place.
    private func windowIDs(pid: pid_t) -> Set<CGWindowID> {
        guard
            let windows = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID)
                as? [[String: Any]]
        else { return [] }

        var ids = Set<CGWindowID>()
        for window in windows {
            guard (window[kCGWindowOwnerPID as String] as? pid_t) == pid,
                  (window[kCGWindowLayer as String] as? Int) == 0,
                  let id = window[kCGWindowNumber as String] as? CGWindowID
            else { continue }
            ids.insert(id)
        }
        return ids
    }

    private func show(_ slot: DockSlot) {
        guard let bundleID = slot.bundleID else { return }

        let running = NSWorkspace.shared.runningApplications.first {
            $0.bundleIdentifier == bundleID
        }

        let state = AppState(
            isRunning: running != nil,
            isFrontmost: running?.isActive ?? false,
            hasVisibleWindow: running.map { hasVisibleWindow(pid: $0.processIdentifier) } ?? false
        )

        switch PressRule.decide(state) {
        case .hide:
            running?.hide()
        case .activate:
            // .activateAllWindows is required: the default only raises the key window,
            // which is not what "show me that app" means.
            running?.activate(options: [.activateAllWindows])
        case .open:
            // Both, and in this order. They are complementary, and each is a no-op when
            // the other is the one that was needed.
            //
            // Activate raises windows that already exist, following them to whatever
            // Space they are on. LaunchServices creates a window when there are none.
            // Neither is sufficient alone: Finder with a window on another Space ignores
            // the LaunchServices reopen entirely - it decides it already has a window and
            // does nothing, leaving you with its menu bar and no way to reach it.
            running?.activate(options: [.activateAllWindows])
            open(slot)
        }
    }

    /// Hand the app to LaunchServices, which is what the Dock does when you click an
    /// icon: it launches the app if it is not running, unhides it if it is hidden, and
    /// asks it to produce a window if it has none. See ADR 0006.
    private func open(_ slot: DockSlot) {
        guard let url = dock.appURL(for: slot) else {
            NSSound.beep()
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        // Defaults to true, and would otherwise pollute Recent Items on every press.
        configuration.addsToRecentItems = false
        NSWorkspace.shared.openApplication(at: url, configuration: configuration)
    }

    /// Is this app showing a normal window on screen right now?
    ///
    /// `.optionOnScreenOnly` is correct *because this is only ever asked about an app
    /// that is already frontmost or visible*. Every app owns off-screen layer-0
    /// windows that are indistinguishable from real ones by any attribute we can read
    /// - see ADR 0006 - and being on screen is the only thing that separates them.
    ///
    /// Layer 0 excludes the menu bar, the Dock, and the desktop. Permission-free: only
    /// window *titles* are redacted without Screen Recording, and we read none.
    private func hasVisibleWindow(pid: pid_t) -> Bool {
        guard
            let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID)
                as? [[String: Any]]
        else { return false }

        return windows.contains { window in
            let owner = window[kCGWindowOwnerPID as String] as? pid_t
            let layer = window[kCGWindowLayer as String] as? Int
            return owner == pid && layer == 0
        }
    }
}
