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
    var onPress: ((Chord) -> Void)? { get set }
    var onRelease: ((Chord) -> Void)? { get set }
    func register(chord: Chord, keyCode: UInt32, modifiers: UInt32) throws
    func unregisterAll()
}

/// Registers every Chord - all ten Slots, in both intents - and suppresses auto-repeat.
@MainActor
final class HotKeyManager {
    private let backend: HotKeyBackend

    /// Chords whose key is currently down, and when it went down.
    private var held: [Chord: Date] = [:]

    /// Chords that could not be registered, and why. Surfaced in the menu.
    private(set) var failures: [Chord: OSStatus] = [:]

    var onChord: ((Chord) -> Void)?

    init(backend: HotKeyBackend) {
        self.backend = backend
        self.backend.onPress = { [weak self] chord in self?.handlePress(chord) }
        self.backend.onRelease = { [weak self] chord in self?.held[chord] = nil }
    }

    /// Every Chord is registered, including Slots with no app behind them.
    /// That is what lets us have no Dock watcher: pin an eighth app and Option+8 is
    /// live on the very next press, with nothing having observed the change.
    ///
    /// Each Slot's key is registered twice: once with the Modifier Set, and once with
    /// the Modifier Set plus Shift for a new window. Unless Shift *is* one of the
    /// chosen modifiers, in which case the two would be the same keystroke and only
    /// the plain Chord exists.
    func apply(modifiers: ModifierSet) {
        backend.unregisterAll()
        held.removeAll()
        failures.removeAll()

        for slot in KeyCodes.allSlots {
            guard let keyCode = KeyCodes.bySlot[slot] else { continue }

            register(
                Chord(slot: slot, intent: .show),
                keyCode: keyCode,
                modifiers: modifiers.carbonFlags
            )

            guard modifiers.supportsNewWindow else { continue }
            register(
                Chord(slot: slot, intent: .newWindow),
                keyCode: keyCode,
                modifiers: modifiers.addingShift.carbonFlags
            )
        }
    }

    private func register(_ chord: Chord, keyCode: UInt32, modifiers: UInt32) {
        do {
            try backend.register(chord: chord, keyCode: keyCode, modifiers: modifiers)
        } catch let error as HotKeyError {
            // macOS 15.0/15.1 briefly rejected Option-only registrations with -9868
            // before Apple reverted it in 15.2. Option-only is our default, so a
            // failure here is never assumed away.
            failures[chord] = error.status
        } catch {
            failures[chord] = OSStatus(-1)
        }
    }

    /// A held key must act once, not strobe. Suppressing auto-repeat by requiring a
    /// release is safe whether or not Carbon actually repeats a held hotkey - if it
    /// does not, this simply never gates anything. It matters more for a new window
    /// than for a Show: a strobing Show is merely ugly, a strobing new window piles
    /// up windows until the machine gives up.
    private func handlePress(_ chord: Chord) {
        if let pressedAt = held[chord] {
            // The release is the real gate. The elapsed check is only a safety net so
            // that a dropped release event cannot wedge a Chord dead forever.
            guard Date().timeIntervalSince(pressedAt) > 2 else { return }
        }
        held[chord] = Date()
        onChord?(chord)
    }
}
