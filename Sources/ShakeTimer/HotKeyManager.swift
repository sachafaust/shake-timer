import Carbon
import Foundation

@MainActor
final class HotKeyManager: @unchecked Sendable {
    enum ActionID: UInt32 {
        case stop = 1
        case snooze = 2
    }

    var onStop: (() -> Void)?
    var onSnooze: (() -> Void)?

    private var eventHandler: EventHandlerRef?
    private var registeredHotKeys: [EventHotKeyRef] = []
    private let signature = OSType(0x5348_544D)

    init() {
        installEventHandler()
        registerHotKey(keyCode: UInt32(kVK_ANSI_S), modifiers: standardModifiers, id: .stop)
        registerHotKey(keyCode: UInt32(kVK_ANSI_Z), modifiers: standardModifiers, id: .snooze)
    }

    private var standardModifiers: UInt32 {
        UInt32(cmdKey) | UInt32(optionKey) | UInt32(controlKey)
    }

    private func installEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }
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
                guard status == noErr else { return status }
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                Task { @MainActor in
                    manager.handle(actionID: hotKeyID.id)
                }
                return noErr
            },
            1,
            &eventType,
            selfPointer,
            &eventHandler
        )
    }

    private func registerHotKey(keyCode: UInt32, modifiers: UInt32, id: ActionID) {
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: signature, id: id.rawValue)
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if status == noErr, let hotKeyRef {
            registeredHotKeys.append(hotKeyRef)
        }
    }

    private func handle(actionID: UInt32) {
        switch ActionID(rawValue: actionID) {
        case .stop:
            onStop?()
        case .snooze:
            onSnooze?()
        case nil:
            break
        }
    }
}
