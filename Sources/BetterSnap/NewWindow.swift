import AppKit
import ApplicationServices
import Carbon.HIToolbox

/// Asks a running app for one more window by pressing its own plain Cmd+N menu item
/// through the Accessibility API. See ADR 0008.
///
/// The menu item is found by its shortcut, not its title: titles are localized and
/// vary per app ("New Window", "New Finder Window", "New Document"), but the
/// shortcut character survives localization. Plain Cmd+N - no extra modifiers - is
/// what every windowed macOS app means by "one more of whatever your window is".
///
/// This is the one thing in BetterSnap that needs a TCC grant. Everything else runs
/// at zero permissions, and the Show path never comes near this file - see ADR 0001.
@MainActor
enum NewWindow {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Shows the system's Accessibility prompt. macOS shows it once; after that the
    /// grant has to be flipped in System Settings, which `openSystemSettings` opens.
    static func promptForTrust() {
        // The literal is `kAXTrustedCheckOptionPrompt`'s value. The constant itself
        // is a mutable CF global, which Swift 6 rejects from a @MainActor context.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    static func openSystemSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    /// Ask the app for one more window: its plain Cmd+N menu item if the menu bar
    /// exposes one, and otherwise the Cmd+N keystroke itself, delivered to the app.
    ///
    /// The keystroke is a fallback, not the first choice, because the menu item is
    /// exact: it says whether the app has a plain Cmd+N at all. But not every app's
    /// menu bar can be trusted to say so at rest. Safari's "New Window" item has no
    /// key equivalent until the File menu is validated - Safari assigns it while the
    /// menu opens, depending on its private-browsing settings - so an Accessibility
    /// walk of the closed menu sees "New Private Window" as Shift+Cmd+N and "New
    /// Window" as nothing. The keystroke goes through the app's own key-equivalent
    /// dispatch, which does run that validation, so it reaches the same item the
    /// walk could not see. An app with no Cmd+N anywhere beeps at the keystroke
    /// itself, which is the same audible "no" the missing item used to earn.
    static func open(pid: pid_t) {
        if pressMenuItem(pid: pid) { return }
        postCommandN(pid: pid)
    }

    /// Press the app's plain Cmd+N item. False when the menu bar shows no such item,
    /// which means either that the app has none or that it has not assigned it yet.
    private static func pressMenuItem(pid: pid_t) -> Bool {
        let app = AXUIElementCreateApplication(pid)
        guard let menuBar = elementAttribute(of: app, kAXMenuBarAttribute) else {
            return false
        }

        // The first menu bar item is the Apple menu - the system's, not the app's.
        // Only top-level items of each menu are searched: "New Window" lives at the
        // top level of the File menu in every app observed, and recursing into
        // submenus would make a miss slower without making a hit more likely.
        for barItem in children(of: menuBar).dropFirst() {
            for menu in children(of: barItem) {
                for item in children(of: menu) where isPlainCommandN(item) {
                    return AXUIElementPerformAction(item, kAXPressAction as CFString) == .success
                }
            }
        }
        return false
    }

    /// Cmd+N as a key-down/key-up pair, delivered to the app's process alone rather
    /// than to whatever is frontmost. Posting to a pid needs the same Accessibility
    /// grant the menu press does, so this adds no permission. The flags are set on
    /// the events explicitly: the user is still holding the Chord's modifiers when
    /// this runs, and the app must see Cmd+N, not Cmd+Ctrl+Shift+N.
    private static func postCommandN(pid: pid_t) {
        let source = CGEventSource(stateID: .hidSystemState)
        for keyDown in [true, false] {
            guard let event = CGEvent(
                keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_N), keyDown: keyDown
            ) else { continue }
            event.flags = .maskCommand
            event.postToPid(pid)
        }
    }

    private static func isPlainCommandN(_ item: AXUIElement) -> Bool {
        guard let char = attribute(of: item, kAXMenuItemCmdCharAttribute) as String?,
              char == "N",
              // 0 is "just Command". Anything else is Shift/Option/Control on top,
              // or the no-Command-key marker - a different shortcut entirely.
              (attribute(of: item, kAXMenuItemCmdModifiersAttribute) as Int? ?? 0) == 0
        else { return false }
        return true
    }

    private static func attribute<T>(of element: AXUIElement, _ name: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success
        else { return nil }
        return value as? T
    }

    /// CF types have no checked `as?` - a wrong-typed attribute would cast "successfully"
    /// - so an element-valued attribute is verified by type ID instead.
    private static func elementAttribute(of element: AXUIElement, _ name: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID()
        else { return nil }
        return (value as! AXUIElement)
    }

    private static func children(of element: AXUIElement) -> [AXUIElement] {
        attribute(of: element, kAXChildrenAttribute) ?? []
    }
}
