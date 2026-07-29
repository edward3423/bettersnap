import Foundation

/// What a press of a Slot's key is asking for.
///
/// Shift is the discriminator, and it is not a modifier the user picks: every Slot
/// registers its key twice, once with the Modifier Set and once with the Modifier Set
/// plus Shift. See ADR 0008.
public enum PressIntent: Int, Sendable, CaseIterable {
    /// Show the Slot's app, or send it away if it is already in front of you.
    case show = 0
    /// Open a second copy of the Slot's app, leaving the running one where it is.
    case newInstance = 1
}

/// A registered Chord: which Slot, and what pressing it means.
public struct Chord: Hashable, Sendable {
    public var slot: Int
    public var intent: PressIntent

    public init(slot: Int, intent: PressIntent) {
        self.slot = slot
        self.intent = intent
    }

    /// Packed into the single `UInt32` that Carbon gives us to identify a hotkey with:
    /// Slot in the low byte, intent above it. Ten Slots and two intents are nowhere
    /// near the edges of either field.
    public var rawID: UInt32 {
        UInt32(slot) | UInt32(intent.rawValue) << 8
    }

    /// Nil for an ID we did not write - a foreign hotkey, or a future intent from a
    /// build that is not this one.
    public init?(rawID: UInt32) {
        guard let intent = PressIntent(rawValue: Int(rawID >> 8)) else { return nil }
        self.init(slot: Int(rawID & 0xFF), intent: intent)
    }
}
