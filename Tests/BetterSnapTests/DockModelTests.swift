import Foundation
import BetterSnapCore

/// Builds the Dock's preferences in the same shape the real ones have.
private func dockPlist(apps: [[String: Any]]) -> [String: Any] {
    [
        "persistent-apps": apps,
        "persistent-others": [["tile-data": ["file-label": "Downloads"]]],
        "recent-apps": [["tile-data": ["file-label": "Recently Used"]]],
        "mod-count": 293,
    ]
}

private func app(
    label: String, bundleID: String?, url: String, bookmark: Data? = nil
) -> [String: Any] {
    var tile: [String: Any] = [
        "file-label": label,
        "file-data": ["_CFURLString": url, "_CFURLStringType": 15],
    ]
    if let bundleID { tile["bundle-identifier"] = bundleID }
    if let bookmark { tile["book"] = bookmark }
    return ["tile-data": tile]
}

@MainActor
func dockModelTests(_ h: Harness) {
    h.section("Dock model")

    let empty = DockModel.parse(dockPlist(apps: []))
    h.check("Slot 1 is Finder even when the Dock is empty", empty[1]?.bundleID == "com.apple.finder")
    h.check("an empty Dock yields only Finder", empty.count == 1)

    let missing = DockModel.parse(nil)
    h.check("unreadable prefs do not throw; you still get Finder", missing[1]?.bundleID == "com.apple.finder")
    h.check("unreadable prefs yield nothing else", missing.count == 1)

    let ordered = DockModel.parse(
        dockPlist(apps: [
            app(
                label: "System Settings", bundleID: "com.apple.systempreferences",
                url: "file:///System/Applications/System%20Settings.app/"
            ),
            app(label: "Safari", bundleID: "com.apple.Safari", url: "file:///Applications/Safari.app/"),
        ])
    )
    h.check("the first pinned app is Slot 2", ordered[2]?.bundleID == "com.apple.systempreferences")
    h.check("pinned apps keep Dock order", ordered[3]?.bundleID == "com.apple.Safari")

    let many = DockModel.parse(
        dockPlist(
            apps: (1...15).map {
                app(
                    label: "App \($0)", bundleID: "com.test.app\($0)",
                    url: "file:///Applications/A\($0).app/"
                )
            }
        )
    )
    h.check("only ten Slots exist", many.count == 10)
    h.check("the ninth pinned app is Slot 10", many[10]?.bundleID == "com.test.app9")
    h.check("a tenth pinned app is unreachable", many[11] == nil)

    let onlyApps = DockModel.parse(
        dockPlist(apps: [
            app(label: "iTerm", bundleID: "com.googlecode.iterm2", url: "file:///Applications/iTerm.app/")
        ])
    )
    h.check(
        "persistent-others is ignored",
        onlyApps.values.contains { $0.label == "Downloads" } == false
    )
    h.check(
        "recent-apps is ignored",
        onlyApps.values.contains { $0.label == "Recently Used" } == false
    )

    h.section("Dock model, against the paths that are actually on this machine")

    // These are the two that string-munging a percent-encoded file:// URL breaks.
    let whatsApp = DockModel.parse(
        dockPlist(apps: [
            app(
                label: "\u{200E}WhatsApp", bundleID: "net.whatsapp.WhatsApp",
                url: "file:///Applications/%E2%80%8EWhatsApp.app/"
            )
        ])
    )
    h.check(
        "a path containing a literal U+200E survives",
        whatsApp[2]?.urlHint?.path == "/Applications/\u{200E}WhatsApp.app"
    )

    let safari = DockModel.parse(
        dockPlist(apps: [
            app(
                label: "Safari", bundleID: "com.apple.Safari",
                url: "file:///System/Volumes/Preboot/Cryptexes/App/System/Applications/Safari.app/"
            )
        ])
    )
    h.check(
        "Safari's cryptex path survives",
        safari[2]?.urlHint?.path
            == "/System/Volumes/Preboot/Cryptexes/App/System/Applications/Safari.app"
    )

    h.section("Dock model resolution")

    // Usually present, but not guaranteed. The Slot Map builder fills it in from the
    // resolved bundle; the parser must not guess.
    let mystery = DockModel.parse(
        dockPlist(apps: [app(label: "Mystery", bundleID: nil, url: "file:///Applications/Mystery.app/")])
    )
    h.check("a missing bundle-identifier parses to nil, not an invention", mystery[2]?.bundleID == nil)
    h.check("the Slot still exists without a bundle identifier", mystery[2]?.label == "Mystery")

    let blob = Data("book\u{0}fake".utf8)
    let bookmarked = DockModel.parse(
        dockPlist(apps: [
            app(
                label: "iTerm", bundleID: "com.googlecode.iterm2",
                url: "file:///Applications/iTerm.app/", bookmark: blob
            )
        ])
    )
    h.check("the bookmark blob is carried through", bookmarked[2]?.bookmark == blob)

    let gone = DockSlot(
        label: "Gone",
        bundleID: "com.test.gone",
        bookmark: Data("not a real bookmark".utf8),
        urlHint: URL(string: "file:///Applications/DefinitelyNotInstalled.app/")
    )
    h.check("an unresolvable Slot yields no URL rather than a bogus one", gone.resolveURL() == nil)

    let finder = DockSlot(
        label: "Finder",
        bundleID: "com.apple.finder",
        urlHint: URL(string: "file:///System/Library/CoreServices/Finder.app/")
    )
    h.check(
        "a real app on disk resolves through the path hint",
        finder.resolveURL()?.path == "/System/Library/CoreServices/Finder.app"
    )

    h.section("Dock model, against the real Dock on this machine, read via cfprefsd")

    let domain = "com.apple.dock" as CFString
    CFPreferencesAppSynchronize(domain)
    let realApps =
        CFPreferencesCopyAppValue("persistent-apps" as CFString, domain) as? [[String: Any]]
    h.check("cfprefsd serves the Dock's persistent-apps", realApps != nil)

    let slots = DockModel.parse(["persistent-apps": realApps ?? []])
    h.check("Slot 1 is Finder", slots[1]?.bundleID == "com.apple.finder")
    h.check("the real Dock has at least one pinned app", slots.count > 1)
    h.check(
        "every pinned Slot carries a bookmark, even through cfprefsd",
        slots.filter { $0.key != 1 }.allSatisfy { $0.value.bookmark != nil }
    )
    h.check(
        "every pinned Slot resolves to an app that exists on disk",
        slots.filter { $0.key != 1 }.allSatisfy { $0.value.resolveURL() != nil }
    )
    h.check(
        "every pinned Slot has a bundle identifier",
        slots.filter { $0.key != 1 }.allSatisfy { $0.value.bundleID != nil }
    )
}
