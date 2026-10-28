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
    private static let keyCode = UInt32(kVK_ANSI_P)
    private static let modifiers = UInt32(controlKey | optionKey | cmdKey)

    private let action: () -> Void
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?

    /// Returns nil when macOS refuses the shortcut, as when another app holds it.
    init?(action: @escaping () -> Void) {
        self.action = action
        var pressed = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        let installed = InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            let shortcut = Unmanaged<GlobalShortcut>.fromOpaque(context).takeUnretainedValue()
            // Carbon delivers hot keys on the main thread's event loop.
            MainActor.assumeIsolated { shortcut.action() }
            return noErr
        }, 1, &pressed, context, &handler)
        let identifier = EventHotKeyID(signature: OSType(0x4350_5046), id: 1)
        guard installed == noErr,
              RegisterEventHotKey(Self.keyCode, Self.modifiers, identifier, GetApplicationEventTarget(), 0, &hotKey) == noErr
        else { return nil }
    }

    deinit {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
    }
}
