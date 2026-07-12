// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BetterSnap",
    platforms: [.macOS(.v15)],
    targets: [
        // Pure logic: no AppKit, no Carbon. This is the part that can be wrong,
        // so it is the part that is tested.
        .target(name: "BetterSnapCore"),

        // The AppKit/Carbon shell around it.
        .executableTarget(name: "BetterSnap", dependencies: ["BetterSnapCore"]),

        // Not a .testTarget, because `swift test` cannot work on this machine: the
        // Command Line Tools toolchain ships neither XCTest nor the swift-testing
        // library, and Xcode is not installed. See Tests/BetterSnapTests/Harness.swift.
        // Run with `make test`.
        .executableTarget(
            name: "BetterSnapTests",
            dependencies: ["BetterSnapCore"],
            path: "Tests/BetterSnapTests"
        ),
    ]
)
