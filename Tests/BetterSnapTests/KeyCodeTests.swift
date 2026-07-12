import BetterSnapCore

@MainActor
func keyCodeTests(_ h: Harness) {
    h.section("Key codes")

    h.check("all ten Slots exist", KeyCodes.allSlots == Array(1...10))
    h.check(
        "every Slot has a keycode",
        KeyCodes.allSlots.allSatisfy { KeyCodes.bySlot[$0] != nil }
    )

    // Written out longhand on purpose. This is the table that `0x12 + n` silently
    // gets wrong for half the Slots, and a typo here is invisible until you press
    // the key.
    let expected: [Int: UInt32] = [
        1: 0x12, 2: 0x13, 3: 0x14, 4: 0x15, 5: 0x17,
        6: 0x16, 7: 0x1A, 8: 0x1C, 9: 0x19, 10: 0x1D,
    ]
    h.check("keycodes are the Events.h values", KeyCodes.bySlot == expected)
    h.check("5 and 6 are transposed, which is the trap", KeyCodes.bySlot[5]! > KeyCodes.bySlot[6]!)
    h.check("no two Slots share a keycode", Set(KeyCodes.bySlot.values).count == 10)
    h.check("Slot 10 is the 0 key", KeyCodes.keyLabel(for: 10) == "0")
    h.check("Slot 3 is the 3 key", KeyCodes.keyLabel(for: 3) == "3")
}

@MainActor
func modifierSetTests(_ h: Harness) {
    h.section("Modifier set")

    h.check("command is the Events.h mask", ModifierSet.command.carbonFlags == 0x0100)
    h.check("shift is the Events.h mask", ModifierSet.shift.carbonFlags == 0x0200)
    h.check("option is the Events.h mask", ModifierSet.option.carbonFlags == 0x0800)
    h.check("control is the Events.h mask", ModifierSet.control.carbonFlags == 0x1000)
    h.check(
        "masks are OR'd together",
        ModifierSet([.control, .option]).carbonFlags == 0x1800
    )
    h.check("an empty set has no flags", ModifierSet([]).carbonFlags == 0)

    h.check("option renders as its symbol", ModifierSet.option.symbols == "\u{2325}")
    h.check(
        "symbols render in the conventional macOS order",
        ModifierSet([.command, .option, .shift, .control]).symbols
            == "\u{2303}\u{2325}\u{21E7}\u{2318}"
    )
}
