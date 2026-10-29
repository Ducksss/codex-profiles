import AppKit
import Carbon.HIToolbox

/// The opt-in, system-wide shortcut that opens the menu. It uses the Carbon
/// hot-key API, which needs no Accessibility or Input Monitoring permission.
/// A global shortcut takes precedence over every app's own, so it stays off
/// until the person turns it on, and registration fails when another app
/// already holds the same keys.
@MainActor
final class GlobalShortcut {
    static let label = "⌃⌥⌘P"
    static let preferenceKey = "globalShortcut"
    private static let modifiers = UInt32(controlKey | optionKey | cmdKey)
    private static let identifier = EventHotKeyID(signature: OSType(0x4350_5046), id: 1)

    private let action: () -> Void
    private var hotKey: EventHotKeyRef?
    private var keyCode: UInt32?
    private var handler: EventHandlerRef?
    private var layoutObserver: NSObjectProtocol?

    /// Returns nil when macOS refuses the shortcut, as when another app holds it.
    init?(action: @escaping () -> Void) {
        self.action = action
        var pressed = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        let installed = InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            let shortcut = Unmanaged<GlobalShortcut>.fromOpaque(context).takeUnretainedValue()
            // Carbon delivers hot keys on the main thread's event loop. A task
            // reaches the main actor on macOS 13 with every supported Swift,
            // where Swift 5.9's MainActor.assumeIsolated needs macOS 14.
            Task { @MainActor in shortcut.action() }
            return noErr
        }, 1, &pressed, context, &handler)
        guard installed == noErr, register(Self.currentKeyCode()) else { return nil }
        layoutObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String), object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.followLayout() }
        }
    }

    deinit {
        if let layoutObserver { DistributedNotificationCenter.default().removeObserver(layoutObserver) }
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
    }

    /// The key that types P with Command held in a layout, so Dvorak and
    /// Colemak use their own P while "Dvorak – QWERTY ⌘" keeps QWERTY's.
    static func keyCode(in source: TISInputSource) -> UInt32? {
        guard let property = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(property).takeUnretainedValue() as Data
        return data.withUnsafeBytes { bytes -> UInt32? in
            guard let layout = bytes.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return nil }
            let command = UInt32(cmdKey >> 8) & 0xFF
            for key in UInt16(0)..<128 {
                var deadKeys: UInt32 = 0
                var length = 0
                var typed = [UniChar](repeating: 0, count: 4)
                let status = UCKeyTranslate(layout, key, UInt16(kUCKeyActionDisplay), command, UInt32(LMGetKbdType()),
                                            OptionBits(kUCKeyTranslateNoDeadKeysMask), &deadKeys, typed.count, &length, &typed)
                if status == noErr, String(utf16CodeUnits: typed, count: length) == "p" { return UInt32(key) }
            }
            return nil
        }
    }

    /// Layouts without a P, such as some input methods, fall back to the
    /// ASCII-capable layout and then to the QWERTY position.
    private static func currentKeyCode() -> UInt32 {
        let copies: [() -> Unmanaged<TISInputSource>?] = [
            TISCopyCurrentKeyboardLayoutInputSource, TISCopyCurrentASCIICapableKeyboardLayoutInputSource,
        ]
        for copy in copies {
            if let source = copy()?.takeRetainedValue(), let code = keyCode(in: source) { return code }
        }
        return UInt32(kVK_ANSI_P)
    }

    private func register(_ code: UInt32) -> Bool {
        var registered: EventHotKeyRef?
        guard RegisterEventHotKey(code, Self.modifiers, Self.identifier, GetApplicationEventTarget(), 0, &registered) == noErr
        else { return false }
        hotKey = registered
        keyCode = code
        return true
    }

    /// Moves the shortcut to P's key after a layout switch, keeping the old
    /// key when macOS refuses the new one.
    private func followLayout() {
        let code = Self.currentKeyCode()
        guard code != keyCode, let previous = hotKey, register(code) else { return }
        UnregisterEventHotKey(previous)
    }
}
