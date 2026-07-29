import BetterSnapCore

private let allChords = KeyCodes.allSlots.flatMap { slot in
    PressIntent.allCases.map { Chord(slot: slot, intent: $0) }
}

@MainActor
func chordTests(_ h: Harness) {
    h.section("Chord identity")

    h.check(
        "every Chord survives the round trip through Carbon's UInt32",
        allChords.allSatisfy { Chord(rawID: $0.rawID) == $0 }
    )
    h.check(
        "no two Chords share a raw ID, so a new instance is never mistaken for a Show",
        Set(allChords.map(\.rawID)).count == allChords.count
    )
    h.check(
        "a Show Chord's raw ID is still just its Slot, as it was before intents existed",
        KeyCodes.allSlots.allSatisfy {
            Chord(slot: $0, intent: .show).rawID == UInt32($0)
        }
    )
    h.check(
        "an ID from an intent this build does not know is rejected, not misread",
        Chord(rawID: 99 << 8 | 3) == nil
    )

    h.section("New instance chords")

    h.check(
        "the new-instance Chord is the Modifier Set plus Shift",
        ModifierSet.option.addingShift == ModifierSet([.option, .shift])
    )
    h.check(
        "which in Carbon's masks means the plain flags OR shiftKey",
        ModifierSet.option.addingShift.carbonFlags == 0x0800 | 0x0200
    )
    h.check(
        "adding Shift to a set that already has it changes nothing",
        ModifierSet([.control, .shift]).addingShift == ModifierSet([.control, .shift])
    )

    // The whole point of `supportsNewInstance`: if Shift is one of the shared
    // modifiers then both Chords are the same keystroke, and registering the second
    // would be registering a duplicate.
    h.check(
        "a Modifier Set without Shift supports new instances",
        ModifierSet([.control, .option]).supportsNewInstance
    )
    h.check(
        "a Modifier Set containing Shift does not",
        !ModifierSet([.option, .shift]).supportsNewInstance
    )
    h.check(
        "Option, the default Modifier Set, supports new instances",
        ModifierSet.option.supportsNewInstance
    )
}
