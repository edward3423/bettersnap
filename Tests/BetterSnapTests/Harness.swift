import Foundation

/// A test harness in forty lines, because there is no test framework available here.
///
/// The Command Line Tools toolchain ships neither XCTest nor swift-testing (only the
/// swift-testing *macro plugin*, without the library), and Xcode is not installed on
/// this machine. The standalone swift-testing package compiles but cannot link -
/// SwiftPM's generated runner wants `_TestingInterop` from the toolchain's bundled
/// copy, which is absent. So `swift test` cannot work at all here.
///
/// This runs the same assertions as an ordinary executable and exits non-zero on
/// failure, which is what CI and `make test` actually need from a test framework.
@MainActor
final class Harness {
    private var passed = 0
    private var failures: [String] = []
    private var section = ""

    func section(_ name: String) {
        section = name
        print("\n\(name)")
    }

    func check(
        _ description: String,
        _ condition: @autoclosure () -> Bool,
        file: StaticString = #fileID,
        line: UInt = #line
    ) {
        if condition() {
            passed += 1
            print("  ok    \(description)")
        } else {
            failures.append("\(section): \(description)  (\(file):\(line))")
            print("  FAIL  \(description)")
        }
    }

    func finish() -> Never {
        print("\n" + String(repeating: "-", count: 60))
        if failures.isEmpty {
            print("\(passed) checks passed")
            exit(0)
        }
        print("\(failures.count) FAILED, \(passed) passed\n")
        for failure in failures { print("  \(failure)") }
        exit(1)
    }
}
