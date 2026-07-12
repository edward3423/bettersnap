import Carbon.HIToolbox
import Foundation

/// `'BSNP'`. Scopes our hotkey IDs so we ignore anyone else's.
private let hotKeySignature: OSType = 0x4253_4E50

/// Carbon delivers these on the main run loop, which is why `HotKeyManager` is
/// `@MainActor` - the HIToolbox header is explicit that it is not thread safe.
private func hotKeyEventHandler(
    _ callRef: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr, hotKeyID.signature == hotKeySignature else {
        return OSStatus(eventNotHandledErr)
    }

    let backend = Unmanaged<CarbonHotKeyBackend>.fromOpaque(userData).takeUnretainedValue()
    let slot = Int(hotKeyID.id)
    let kind = GetEventKind(event)

    MainActor.assumeIsolated {
        switch Int(kind) {
        case kEventHotKeyPressed: backend.onPress?(slot)
        case kEventHotKeyReleased: backend.onRelease?(slot)
        default: break
        }
    }
    return noErr
}

/// The only mechanism for a system-wide hotkey that needs no TCC permission.
/// Matching happens inside WindowServer, so this process gets zero wakeups while
/// the user types in other apps. See ADR 0002.
@MainActor
final class CarbonHotKeyBackend: HotKeyBackend {
    var onPress: ((Int) -> Void)?
    var onRelease: ((Int) -> Void)?

    private var handler: EventHandlerRef?
    private var registered: [EventHotKeyRef] = []

    init() {
        var specs = [
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            ),
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyReleased)
            ),
        ]
        InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyEventHandler,
            specs.count,
            &specs,
            Unmanaged.passUnretained(self).toOpaque(),
            &handler
        )
    }

    func register(slot: Int, keyCode: UInt32, modifiers: UInt32) throws {
        var ref: EventHotKeyRef?
        let id = EventHotKeyID(signature: hotKeySignature, id: UInt32(slot))

        let status = RegisterEventHotKey(
            keyCode, modifiers, id, GetApplicationEventTarget(), 0, &ref
        )
        guard status == noErr, let ref else {
            throw HotKeyError(status: status)
        }
        registered.append(ref)
    }

    func unregisterAll() {
        for ref in registered { UnregisterEventHotKey(ref) }
        registered.removeAll()
    }
}
