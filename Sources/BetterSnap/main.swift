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

        // Carbon is main-thread only, and registration belongs here.
        hotKeys.apply(modifiers: config.modifiers)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// Also set via LSUIElement in Info.plist; belt and braces for a direct exec.
app.setActivationPolicy(.accessory)
app.run()
