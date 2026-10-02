import AppKit

#if !TESTING
@MainActor
@main
struct CodexProfilesMenuApp {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private let store = WorkspaceStore(client: CLIClient())
    private var menuController: WorkspaceMenuViewController?
    private var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = WorkspaceMenuViewController(store: store)
        controller.onPreferredContentSizeChange = { [weak self] size in
            self?.popover.contentSize = size
        }
        controller.onRequestClose = { [weak self] in self?.popover.performClose(nil) }
        menuController = controller

        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = controller.preferredContentSize
        popover.contentViewController = controller

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem = item

        if let button = item.button {
            let image = NSImage(
                systemSymbolName: "square.stack.3d.up.fill",
                accessibilityDescription: "Codex Profiles"
            )
            image?.isTemplate = true
            button.image = image
            button.target = self
            button.action = #selector(togglePopover)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.popover.isShown, NSApp.modalWindow == nil,
                event.window == self.menuController?.view.window else { return event }
            return self.menuController?.handleShortcut(event) == true ? nil : event
        }
        togglePopover()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
            menuController?.focusSearch()
            Task { await store.refresh() }
        }
    }
}
#endif
