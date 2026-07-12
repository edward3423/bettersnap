import Foundation

/// One entry in the Slot Map.
public struct DockSlot: Equatable, Sendable {
    public var label: String
    /// May be absent from the plist; the Slot Map builder fills it in from the
    /// resolved app bundle when it is.
    public var bundleID: String?
    /// The Dock's `tile-data.book` blob. This, not the path, is how the Dock finds
    /// an app - it survives the app being moved or renamed. See ADR 0004.
    public var bookmark: Data?
    /// `file-data._CFURLString`. Only a cached hint; the Dock does not trust it either.
    public var urlHint: URL?

    public init(label: String, bundleID: String?, bookmark: Data? = nil, urlHint: URL? = nil) {
        self.label = label
        self.bundleID = bundleID
        self.bookmark = bookmark
        self.urlHint = urlHint
    }

    /// Where this app lives right now, using the Dock's own resolution order.
    ///
    /// `.withoutUI` and `.withoutMounting` guarantee this can never block on a
    /// missing volume or throw up a dialog. A stale bookmark that still resolves is
    /// used as-is; we never write a refreshed one back, because the Dock plist is
    /// the Dock's, and BetterSnap only ever reads it.
    ///
    /// Returns nil if the app cannot be found on disk at all. The caller may then
    /// fall back to LaunchServices, which needs AppKit and so does not belong here.
    public func resolveURL() -> URL? {
        if let bookmark {
            var isStale = false
            if let url = try? URL(
                resolvingBookmarkData: bookmark,
                options: [.withoutUI, .withoutMounting],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ), FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        if let urlHint, FileManager.default.fileExists(atPath: urlHint.path) {
            return urlHint
        }
        return nil
    }
}

public enum DockModel {
    public static let maxSlots = 10

    /// Slot 1 is always Finder, which is never in `persistent-apps` and cannot be
    /// removed from the Dock.
    public static let finder = DockSlot(
        label: "Finder",
        bundleID: "com.apple.finder",
        urlHint: URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")
    )

    /// The Dock's preferences to a Slot Map. Pure: no IO, no AppKit.
    ///
    /// Takes the already-read preference dictionary rather than plist bytes, because
    /// BetterSnap reads the Dock through `cfprefsd` and not from the file on disk -
    /// see ADR 0007.
    ///
    /// Reads `persistent-apps` only. `persistent-others` (Downloads, Trash) and
    /// `recent-apps` are ignored - recents have an unstable order, and neither
    /// affects the position of the pinned icons on screen.
    public static func parse(_ root: [String: Any]?) -> [Int: DockSlot] {
        var slots: [Int: DockSlot] = [1: finder]

        guard let apps = root?["persistent-apps"] as? [[String: Any]] else {
            return slots
        }

        // Slots 2...10, so at most nine pinned apps are reachable.
        for (index, app) in apps.prefix(maxSlots - 1).enumerated() {
            guard let tile = app["tile-data"] as? [String: Any] else { continue }

            let fileData = tile["file-data"] as? [String: Any]
            let urlString = fileData?["_CFURLString"] as? String

            slots[index + 2] = DockSlot(
                label: (tile["file-label"] as? String) ?? "Unknown",
                bundleID: tile["bundle-identifier"] as? String,
                bookmark: tile["book"] as? Data,
                // Never string-munge this. It is a percent-encoded file:// URL, and on
                // a real Dock it contains things like a literal U+200E (WhatsApp) and
                // /System/Volumes/Preboot/Cryptexes/App (Safari).
                urlHint: urlString.flatMap { URL(string: $0) }
            )
        }

        return slots
    }
}
