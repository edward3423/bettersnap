import Foundation

@MainActor
func main() {
    let harness = Harness()

    pressRuleTests(harness)
    keyCodeTests(harness)
    modifierSetTests(harness)
    dockModelTests(harness)

    harness.finish()
}

main()
