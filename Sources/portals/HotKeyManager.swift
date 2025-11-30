import Carbon
import Foundation

struct KeyCombo: Codable {
    let keyCode: UInt32
    let modifiers: UInt32
}

final class HotKeyManager {
    private var hotKeyRefs: [UInt32: EventHotKeyRef?] = [:]
    private var handlers: [UInt32: () -> Void] = [:]
    private var eventHandler: EventHandlerRef?
    private let signature: UInt32 = OSType("PTLS".fourCharCodeValue)

    init() {
        installHandler()
    }

    func register(id: UInt32, combo: KeyCombo, handler: @escaping () -> Void) {
        unregister(id: id)
        handlers[id] = handler

        let hotKeyID = EventHotKeyID(signature: signature, id: id)
        var ref: EventHotKeyRef?
        RegisterEventHotKey(combo.keyCode, combo.modifiers, hotKeyID, GetEventDispatcherTarget(), 0, &ref)
        hotKeyRefs[id] = ref
    }

    func unregister(id: UInt32) {
        if let ref = hotKeyRefs[id] {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs[id] = nil
        handlers[id] = nil
    }

    private func installHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        InstallEventHandler(GetEventDispatcherTarget(), { (_, event, userData) -> OSStatus in
            guard let userData else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            return manager.handle(event: event)
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &eventHandler)
    }

    private func handle(event: EventRef?) -> OSStatus {
        guard let event else { return OSStatus(eventNotHandledErr) }
        var hotKeyID = EventHotKeyID()
        let result = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
        guard result == noErr, hotKeyID.signature == signature else {
            return OSStatus(eventNotHandledErr)
        }
        if let handler = handlers[hotKeyID.id] {
            handler()
            return noErr
        }
        return OSStatus(eventNotHandledErr)
    }
}

private extension String {
    var fourCharCodeValue: UInt32 {
        var result: UInt32 = 0
        for scalar in utf16 {
            result = (result << 8) + UInt32(scalar)
        }
        return result
    }
}
