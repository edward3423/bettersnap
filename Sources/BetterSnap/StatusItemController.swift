import AppKit
import BetterSnapCore

/// The menu bar icon and its menu - the entire UI. There is no settings window.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    /// Called with the new set when the user toggles a modifier.
    var onModifiersChanged: ((ModifierSet) -> Void)?
    var currentModifiers: () -> ModifierSet = { .option }
    var currentSlots: () -> [Int: DockSlot] = { [:] }
    var currentFailures: () -> [Chord: OSStatus] = { [:] }

    override init() {
        super.init()

        // Must be a template image: the Tahoe menu bar is transparent, and a
        // non-template image renders badly over arbitrary wallpapers.
        let image = NSImage(
            systemSymbolName: "square.grid.3x3.fill", accessibilityDescription: "BetterSnap"
        )
        image?.isTemplate = true
        item.button?.image = image

        // `behavior` is deliberately left at its default. Setting `.removalAllowed`
        // would let a command-drag out of the menu bar strand the app with no UI and
        // no way back, now that there is no settings window.

        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
    }

    /// Rebuilt every time the menu opens, so it is always live without anything
    /// having to watch the Dock.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let modifiers = currentModifiers()
        let slots = currentSlots()
        let failures = currentFailures()

        for slot in KeyCodes.allSlots {
            let keys = modifiers.symbols + KeyCodes.keyLabel(for: slot)
            let name = slots[slot]?.label

            let title: String
            if failures[Chord(slot: slot, intent: .show)] != nil {
                title = "\(keys)   \(name ?? "-")   (unavailable)"
            } else {
                title = "\(keys)   \(name ?? "-")"
            }

            let entry = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            entry.isEnabled = false
            menu.addItem(entry)
        }

        // One line rather than a second block of ten: the rule is uniform across every
        // Slot, so stating it once says everything a repeated list would.
        menu.addItem(newWindowLine(modifiers: modifiers, failures: failures))

        menu.addItem(.separator())

        let header = NSMenuItem(title: "Modifiers", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        for (name, modifier) in Self.modifierChoices {
            let entry = NSMenuItem(
                title: name, action: #selector(toggleModifier(_:)), keyEquivalent: ""
            )
            entry.target = self
            entry.state = modifiers.contains(modifier) ? .on : .off
            entry.tag = modifier.rawValue
            menu.addItem(entry)
        }

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "Quit BetterSnap", action: #selector(quit), keyEquivalent: "q"
        )
        quit.target = self
        menu.addItem(quit)
    }

    /// Adding Shift to any Chord opens a new window - unless Shift is already one of
    /// the modifiers, in which case there is no keystroke left to say it with.
    ///
    /// The one live state here is the missing Accessibility grant: that line is
    /// clickable and goes straight to the right System Settings pane, because the
    /// system prompt only appears once and this is the way back afterwards.
    private func newWindowLine(
        modifiers: ModifierSet, failures: [Chord: OSStatus]
    ) -> NSMenuItem {
        let title: String
        var clickable = false

        if !modifiers.supportsNewWindow {
            title = "Add \u{21E7}   New window   (unavailable: \u{21E7} is a modifier)"
        } else if KeyCodes.allSlots.contains(where: {
            failures[Chord(slot: $0, intent: .newWindow)] != nil
        }) {
            title = "Add \u{21E7}   New window   (unavailable)"
        } else if !NewWindow.isTrusted {
            title = "Add \u{21E7}   New window   (grant Accessibility\u{2026})"
            clickable = true
        } else {
            title = "Add \u{21E7}   New window"
        }

        let item = NSMenuItem(
            title: title,
            action: clickable ? #selector(openAccessibilitySettings) : nil,
            keyEquivalent: ""
        )
        item.target = clickable ? self : nil
        item.isEnabled = clickable
        return item
    }

    @objc private func openAccessibilitySettings() {
        NewWindow.openSystemSettings()
    }

    private static let modifierChoices: [(String, ModifierSet)] = [
        ("Control", .control),
        ("Option", .option),
        ("Shift", .shift),
        ("Command", .command),
    ]

    @objc private func toggleModifier(_ sender: NSMenuItem) {
        let modifier = ModifierSet(rawValue: sender.tag)
        var modifiers = currentModifiers()
        modifiers.formSymmetricDifference(modifier)

        // An empty Modifier Set would bind the bare number keys system-wide, which
        // would make the machine unusable. Refuse.
        guard !modifiers.isEmpty else {
            NSSound.beep()
            return
        }
        onModifiersChanged?(modifiers)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
