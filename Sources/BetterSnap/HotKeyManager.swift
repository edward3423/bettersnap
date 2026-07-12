import Carbon.HIToolbox
import Foundation
import BetterSnapCore

struct HotKeyError: Error {
    var status: OSStatus
}

/// The seam. Carbon is legacy, and if Apple ever removes it a `CGEventTapBackend`
/// drops in here - though note that would break ADR 0001, so it is a last resort
/// and not a neutral swap. See ADR 0002.
@MainActor
protocol HotKeyBackend: AnyObject {
    var onPress: ((Int) -> Void)? { get set }
    var onRelease: ((Int) -> Void)? { get set }
    func register(slot: Int, keyCode: UInt32, modifiers: UInt32) throws
    func unregisterAll()
}

/// Registers all ten Chords and suppresses auto-repeat.
@MainActor
final class HotKeyManager {
    private let backend: HotKeyBackend

    /// Slots whose key is currently down, and when it went down.
    private var held: [Int: Date] = [:]

    /// Slots whose Chord could not be registered, and why. Surfaced in the menu.
    private(set) var failures: [Int: OSStatus] = [:]

    var onSlot: ((Int) -> Void)?

    init(backend: HotKeyBackend) {
        self.backend = backend
        self.backend.onPress = { [weak self] slot in self?.handlePress(slot) }
        self.backend.onRelease = { [weak self] slot in self?.held[slot] = nil }
    }

    /// All ten Chords are registered, including Slots with no app behind them.
    /// That is what lets us have no Dock watcher: pin an eighth app and Option+8 is
    /// live on the very next press, with nothing having observed the change.
    func apply(modifiers: ModifierSet) {
        backend.unregisterAll()
        held.removeAll()
        failures.removeAll()

        for slot in KeyCodes.allSlots {
            guard let keyCode = KeyCodes.bySlot[slot] else { continue }
            do {
                try backend.register(
                    slot: slot, keyCode: keyCode, modifiers: modifiers.carbonFlags
                )
            } catch let error as HotKeyError {
                // macOS 15.0/15.1 briefly rejected Option-only registrations with -9868
                // before Apple reverted it in 15.2. Option-only is our default, so a
                // failure here is never assumed away.
                failures[slot] = error.status
            } catch {
                failures[slot] = OSStatus(-1)
            }
        }
    }

    /// A held key must act once, not strobe. Suppressing auto-repeat by requiring a
    /// release is safe whether or not Carbon actually repeats a held hotkey - if it
    /// does not, this simply never gates anything.
    private func handlePress(_ slot: Int) {
        if let pressedAt = held[slot] {
            // The release is the real gate. The elapsed check is only a safety net so
            // that a dropped release event cannot wedge a Slot dead forever.
            guard Date().timeIntervalSince(pressedAt) > 2 else { return }
        }
        held[slot] = Date()
        onSlot?(slot)
    }
}
