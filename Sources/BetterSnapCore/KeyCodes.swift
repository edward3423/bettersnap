import Foundation

/// Virtual keycodes for the number row.
public enum KeyCodes {
    /// Slot 1...10 to virtual keycode, where Slot 10 is the `0` key.
    ///
    /// These are not sequential. From `Events.h`: 5 and 6 are transposed, and
    /// 7/8/9/0 are scattered. Computing `0x12 + n` silently breaks half the Slots,
    /// which is why this is an explicit table and why `KeyCodeTests` exists.
    public static let bySlot: [Int: UInt32] = [
        1: 0x12,  // kVK_ANSI_1
        2: 0x13,  // kVK_ANSI_2
        3: 0x14,  // kVK_ANSI_3
        4: 0x15,  // kVK_ANSI_4
        5: 0x17,  // kVK_ANSI_5
        6: 0x16,  // kVK_ANSI_6
        7: 0x1A,  // kVK_ANSI_7
        8: 0x1C,  // kVK_ANSI_8
        9: 0x19,  // kVK_ANSI_9
        10: 0x1D, // kVK_ANSI_0
    ]

    public static let allSlots = Array(1...10)

    /// The character printed on the key for a Slot. Slot 10 is the `0` key.
    public static func keyLabel(for slot: Int) -> String {
        slot == 10 ? "0" : String(slot)
    }
}
