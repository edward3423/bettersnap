import Foundation

/// The modifiers shared by every Chord. Not per-Slot: one set for all ten.
public struct ModifierSet: OptionSet, Codable, Hashable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let control = ModifierSet(rawValue: 1 << 0)
    public static let option  = ModifierSet(rawValue: 1 << 1)
    public static let shift   = ModifierSet(rawValue: 1 << 2)
    public static let command = ModifierSet(rawValue: 1 << 3)

    // Carbon HIToolbox modifier masks, from `Events.h`.
    private static let cmdKey     = 0x0100
    private static let shiftKey   = 0x0200
    private static let optionKey  = 0x0800
    private static let controlKey = 0x1000

    /// The mask `RegisterEventHotKey` wants.
    public var carbonFlags: UInt32 {
        var flags = 0
        if contains(.command) { flags |= Self.cmdKey }
        if contains(.shift)   { flags |= Self.shiftKey }
        if contains(.option)  { flags |= Self.optionKey }
        if contains(.control) { flags |= Self.controlKey }
        return UInt32(flags)
    }

    /// The modifiers a new-instance Chord uses: the same set, plus Shift.
    public var addingShift: ModifierSet { union(.shift) }

    /// Shift is how a Chord asks for a new instance, so it cannot also be one of the
    /// modifiers every Chord already shares - the two would be the same keystroke, and
    /// the plain Chord would win. Picking Shift as a modifier costs you new instances.
    public var supportsNewInstance: Bool { !contains(.shift) }

    /// Rendered in the conventional macOS order.
    public var symbols: String {
        var s = ""
        if contains(.control) { s += "\u{2303}" } // Control
        if contains(.option)  { s += "\u{2325}" } // Option
        if contains(.shift)   { s += "\u{21E7}" } // Shift
        if contains(.command) { s += "\u{2318}" } // Command
        return s
    }
}
