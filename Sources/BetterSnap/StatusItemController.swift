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
    var currentFailures: () -> [Int: OSStatus] = { [:] }

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
            let chord = modifiers.symbols + KeyCodes.keyLabel(for: slot)
            let name = slots[slot]?.label

            let title: String
            if failures[slot] != nil {
                title = "\(chord)   \(name ?? "-")   (unavailable)"
            } else {
                title = "\(chord)   \(name ?? "-")"
            }

            let entry = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            entry.isEnabled = false
            menu.addItem(entry)
        }

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
