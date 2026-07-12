import AppKit
import BetterSnapCore

/// The Slot Map, rebuilt lazily.
///
/// There is no file watcher here, and that is deliberate - see ADR 0005. A Dock change
/// is noticed by asking `cfprefsd` for the Dock's `mod-count` when a Chord is pressed,
/// which costs under a microsecond and means this process is completely inert between
/// keypresses.
///
/// The Dock is read through `cfprefsd` rather than from `com.apple.dock.plist`, because
/// the file lags the daemon by several seconds - see ADR 0007.
@MainActor
final class DockSource {
    private let domain = "com.apple.dock" as CFString

    /// The Dock bumps this on every change to its contents.
    private var modCount: Int?
    private var cached: [Int: DockSlot] = [:]

    /// The current Slot Map. On the overwhelmingly common path this is one preference
    /// read, measured at 0.7us.
    func slots() -> [Int: DockSlot] {
        // Without this, cfprefsd serves us a snapshot cached in our own process and we
        // would never see a Dock change at all.
        CFPreferencesAppSynchronize(domain)
        let current = CFPreferencesCopyAppValue("mod-count" as CFString, domain) as? Int

        if !cached.isEmpty, let modCount, current == modCount {
            return cached
        }

        modCount = current
        reload()
        return cached
    }

    /// Where a Slot's app lives right now.
    ///
    /// Bookmark first (as the Dock does), then the plist's path hint, and only then
    /// LaunchServices. LaunchServices is last because when two copies of an app exist
    /// it picks the winner, which may not be the one you pinned.
    func appURL(for slot: DockSlot) -> URL? {
        if let url = slot.resolveURL() { return url }
        if let bundleID = slot.bundleID {
            return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        }
        return nil
    }

    private func reload() {
        let apps =
            CFPreferencesCopyAppValue("persistent-apps" as CFString, domain) as? [[String: Any]]
        var map = DockModel.parse(["persistent-apps": apps ?? []])

        // `tile-data.bundle-identifier` is usually present but is not guaranteed. When
        // it is missing, the resolved bundle is the only place left to get it, and we
        // need it: it is what running apps are matched on.
        for (index, slot) in map where slot.bundleID == nil {
            guard
                let url = appURL(for: slot),
                let bundleID = Bundle(url: url)?.bundleIdentifier
            else { continue }
            map[index]?.bundleID = bundleID
        }

        cached = map
    }
}
