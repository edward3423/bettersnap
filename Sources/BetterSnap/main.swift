import AppKit
import BetterSnapCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let switcher = AppSwitcher()
    private let statusItem = StatusItemController()
    private lazy var hotKeys = HotKeyManager(backend: CarbonHotKeyBackend())
    private var config = ConfigStore.load()

    func applicationDidFinishLaunching(_ notification: Notification) {
        hotKeys.onChord = { [weak self] chord in
            self?.switcher.press(chord)
        }

        statusItem.currentModifiers = { [weak self] in self?.config.modifiers ?? .option }
        statusItem.currentSlots = { [weak self] in self?.switcher.slots() ?? [:] }
        statusItem.currentFailures = { [weak self] in self?.hotKeys.failures ?? [:] }
        statusItem.onModifiersChanged = { [weak self] modifiers in
            guard let self else { return }
            config.modifiers = modifiers
            ConfigStore.save(config)
            hotKeys.apply(modifiers: modifiers)
        }
        statusItem.onHideIconConfirmed = { [weak self] in
            self?.setIconVisible(false)
        }
        statusItem.setIconVisible(config.showsMenuBarIcon)

        // Carbon is main-thread only, and registration belongs here.
        hotKeys.apply(modifiers: config.modifiers)
    }

    /// Opening the app while it is already running - from Spotlight, Finder, or
    /// `open` - is the way back from a hidden icon, since the icon was the only UI.
    func applicationShouldHandleReopen(
        _ sender: NSApplication, hasVisibleWindows flag: Bool
    ) -> Bool {
        setIconVisible(true)
        return false
    }

    private func setIconVisible(_ visible: Bool) {
        config.showsMenuBarIcon = visible
        ConfigStore.save(config)
        statusItem.setIconVisible(visible)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// Also set via LSUIElement in Info.plist; belt and braces for a direct exec.
app.setActivationPolicy(.accessory)
app.run()
