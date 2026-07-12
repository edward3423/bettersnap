import Foundation

/// Everything about a Slot's app that the press rule is allowed to care about.
public struct AppState: Equatable, Sendable {
    public var isRunning: Bool
    public var isFrontmost: Bool

    /// Is this app showing a normal window on screen, right now?
    ///
    /// Deliberately *not* "does this app own any window", which is a question that
    /// cannot be answered from outside the app - see ADR 0006. This is only ever
    /// consulted to decide whether the app is actually showing you something.
    public var hasVisibleWindow: Bool

    public init(isRunning: Bool, isFrontmost: Bool, hasVisibleWindow: Bool) {
        self.isRunning = isRunning
        self.isFrontmost = isFrontmost
        self.hasVisibleWindow = hasVisibleWindow
    }
}

public enum Action: Equatable, Sendable {
    /// Send the app away. It is in front of you and showing a window.
    case hide
    /// Bring a visible app forward. One Mach message, sub-millisecond.
    case activate
    /// Hand the app to LaunchServices and let it work out what "show me this" means.
    /// Covers launching, unhiding, switching Space, and reopening a window.
    case open
}

public enum PressRule {
    /// A Chord always ends with its app in front of you, unless it already was,
    /// in which case it gets out of the way.
    ///
    /// See ADR 0003 for the toggle, and ADR 0006 for why almost everything that is
    /// not a Hide funnels into a single `.open`.
    public static func decide(_ state: AppState) -> Action {
        // Only Hide if the app is genuinely showing you something. Hiding an app that
        // has nothing on screen - Finder with no windows, the most common state of the
        // most-used Slot - is invisible, and reads as the app being broken.
        if state.isFrontmost, state.hasVisibleWindow {
            return .hide
        }
        if state.isRunning, state.hasVisibleWindow {
            return .activate
        }
        // Not running, or hidden, or on another Space, or running with no windows.
        // We cannot tell these apart from outside the app, and we do not need to: the
        // app knows, so let it decide.
        return .open
    }
}
