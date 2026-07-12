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

    func press(slot index: Int) {
        let interval = signposter.beginInterval("press")
        defer { signposter.endInterval("press", interval) }

        // An unbound Slot is swallowed rather than passed through. That is the price
        // of having no Dock watcher - see ADR 0005.
        guard let slot = dock.slots()[index], let bundleID = slot.bundleID else { return }

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
            open(slot)
        }
    }

    /// Hand the app to LaunchServices. This is what the Dock does when you click an
    /// icon, and it is why one call covers launching, unhiding, switching Space, and
    /// making a windowless app produce a window. See ADR 0006.
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
