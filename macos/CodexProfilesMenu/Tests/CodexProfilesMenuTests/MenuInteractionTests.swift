import AppKit
import Foundation

@MainActor
@main
struct MenuInteractionTests {
    static func main() async throws {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        let suite = "menu-interaction-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let marker = root.appendingPathComponent("launch")
        let executable = root.appendingPathComponent("cli")
        // The shim receives launch arguments without opening a real app or account.
        try Data("#!/bin/sh\nprintf '%s\\n' \"$@\" > '\(marker.path)'\n".utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        let store = WorkspaceStore(client: CLIClient(executableURL: executable), defaults: defaults)
        let checkedAt = Date()
        let quota = ProfileUsage.available(CodexRateLimits(windows: [
            RateLimitWindow(usedPercent: 23, windowDurationMins: 300, resetsAt: checkedAt.addingTimeInterval(3600).timeIntervalSince1970),
            RateLimitWindow(usedPercent: 91, windowDurationMins: 10080, resetsAt: checkedAt.addingTimeInterval(86400).timeIntervalSince1970),
        ]), checkedAt: checkedAt)
        store.loadPreview([], profiles: ["work"], usage: ["work": quota])
        let firstRunController = WorkspaceMenuViewController(store: store, defaults: defaults)
        expect(descendants(firstRunController.view).compactMap { $0 as? NSTextField }.contains { $0.stringValue == "work" },
            "an initialized profile must be usable without any workspace binding")
        var profileClosed = false
        firstRunController.onRequestClose = { profileClosed = true }
        let profileRow = descendants(firstRunController.view).compactMap { $0 as? LaunchRowButton }.first!
        let usageView = descendants(profileRow).compactMap { $0 as? ProfileUsageView }.first!
        expect(descendants(usageView).compactMap { $0 as? NSTextField }.map(\.stringValue) == ["5h", "77%", "7d", "9%"],
            "profile rows must show remaining percentages and actual window durations")
        expect(profileRow.accessibilityLabel()!.contains("77% remaining") && profileRow.accessibilityLabel()!.contains("Resets"),
            "quota and reset times must be available to accessibility clients")
        expect(usageView.toolTip!.contains("ChatGPT may use a different account") && usageView.toolTip!.contains("Checked"),
            "quota tooltips must explain sign-in scope and freshness")
        openButton(in: profileRow).performClick(nil)
        for _ in 0..<100 where !profileClosed { try await Task.sleep(nanoseconds: 10_000_000) }
        let profileArguments = try String(contentsOf: marker, encoding: .utf8)
        expect(profileClosed && profileArguments == "app\nwork\n",
            "a profile must open without supplying a workspace path")
        expect(store.workspaces.isEmpty, "opening a profile must not create a workspace binding")
        store.loadPreview([], profiles: [])
        expect(descendants(firstRunController.view).compactMap { $0 as? NSButton }.contains { $0.title == "Create profile…" },
            "first-run setup must ask for a profile rather than a project folder")

        let missing = workspace("/projects/missing", exists: false)
        let first = workspace("/projects/first")
        let last = workspace("/projects/last")
        store.loadPreview([first, missing, last], usage: ["work": quota])
        store.togglePin(first)
        let controller = WorkspaceMenuViewController(store: store, defaults: defaults)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 480), styleMask: .borderless, backing: .buffered, defer: false)
        window.contentViewController = controller
        window.setContentSize(controller.preferredContentSize)
        controller.view.layoutSubtreeIfNeeded()
        controller.focusSearch()
        expect(controller.preferredContentSize.width == 400, "popover must retain compact reference width")
        let allViews = descendants(controller.view)
        expect(!(controller.view is NSVisualEffectView) && !allViews.contains { $0 is NSVisualEffectView },
            "NSPopover must own its background material without a duplicate effect layer")
        let title = allViews.compactMap { $0 as? NSTextField }.first { $0.stringValue == "Codex Profiles" }!
        let options = allViews.compactMap { $0 as? NSButton }.first { $0.toolTip == "Options" }!
        let titleCenter = controller.view.convert(NSPoint(x: title.bounds.midX, y: title.bounds.midY), from: title)
        let optionsCenter = controller.view.convert(NSPoint(x: options.bounds.midX, y: options.bounds.midY), from: options)
        expect(abs(titleCenter.y - optionsCenter.y) < 1, "title and options must share one compact header line")
        let headerIcon = title.superview!.subviews.compactMap { $0 as? NSImageView }.first!
        expect(isMonochrome(headerIcon.contentTintColor), "header symbol must use native monochrome tint")
        let searchFields = allViews.compactMap { $0 as? NSSearchField }
        expect(searchFields.count == 1, "workspace search must use native NSSearchField")
        let search = searchFields[0]
        expect(allViews.contains { $0 is NSPopUpButton }, "profile filter must remain available")
        expect(allViews.contains { $0 is NSSegmentedControl }, "launch destination must remain available")
        let initialRows = descendants(controller.view).compactMap { $0 as? LaunchRowButton }
        let list = descendants(controller.view).compactMap { $0 as? NSScrollView }.first!
        let listWidth = list.contentView.bounds.width
        expect(initialRows.count == 4, "initialized profiles and all bindings must be rendered")
        expect(list.documentView!.bounds.height <= list.contentView.bounds.height + 1,
            "a short list must fit without clipping the last row or needing to scroll")
        expect(initialRows.allSatisfy { abs($0.frame.width - listWidth) < 1 }, "workspace rows must fill the list width")
        let separators = descendants(list).compactMap { $0 as? NSBox }.filter { $0.boxType == .separator }
        expect(separators.count >= initialRows.count - 1, "workspace rows must have native separators")
        expect(separators.allSatisfy { abs($0.frame.width - listWidth) < 1 }, "row separators must fill the list width")
        let profileUsage = descendants(initialRows[0]).compactMap { $0 as? ProfileUsageView }.first!
        let profileName = descendants(initialRows[0]).compactMap { $0 as? NSTextField }.first { $0.stringValue == "work" }!
        let profileOpen = openButton(in: initialRows[0])
        let nameFrame = initialRows[0].convert(profileName.bounds, from: profileName)
        let usageFrame = initialRows[0].convert(profileUsage.bounds, from: profileUsage)
        let openFrame = initialRows[0].convert(profileOpen.bounds, from: profileOpen)
        expect(usageFrame.width == ProfileUsageView.columnWidth && nameFrame.maxX <= usageFrame.minX && usageFrame.maxX < openFrame.minX,
            "quota must fit beside the profile without obscuring its name or Open button")
        for row in initialRows where row.item.workspace != nil {
            expect(!descendants(row).contains { $0 is ProfileUsageView }, "workspace rows must not duplicate account quota")
            let workspace = row.item.workspace!
            let labels = descendants(row).compactMap { $0 as? NSTextField }
            let name = labels.first { $0.stringValue == workspace.name }!
            let path = labels.first { $0.stringValue == "\(workspace.profile) · \(workspace.displayPath())" }!
            expect(abs(row.convert(name.bounds.origin, from: name).x - row.convert(path.bounds.origin, from: path).x) < 1,
                "workspace profile and path must align with project title")
            let icon = descendants(row).compactMap { $0 as? NSImageView }.first!
            expect(isMonochrome(icon.contentTintColor), "folder and pin symbols must use native monochrome tint")
            let open = openButton(in: row)
            expect(open.controlSize == .small, "explicit Open action must use a compact native button")
            expect(open.isEnabled == workspace.isAvailable, "Open availability must match workspace availability")
            expect(abs(row.frame.height - (workspace.isAvailable ? 56 : 72)) < 1,
                "rows must remain compact while leaving space for missing-folder guidance")
        }
        expect(initialRows.allSatisfy { !$0.isSelectedRow }, "opening must not paint an unsolicited grey selection")
        expect(initialRows.first(where: { $0.item.workspace == missing })?.isEnabled == false, "missing workspace must not launch")
        expect(descendants(initialRows.first(where: { $0.item.workspace == missing })!).contains { ($0 as? NSButton)?.toolTip?.contains("remove binding") == true }, "missing rows must retain an actions button")
        expect(controller.handleShortcut(key(125)), "down arrow must be handled")
        expect(initialRows.first?.item == .profile("work") && initialRows.first?.isSelectedRow == true,
            "first down arrow must select the profile before optional workspaces")
        expect(controller.handleShortcut(key(125)), "next down arrow must be handled")
        expect(initialRows.first(where: { $0.item.workspace == first })?.isSelectedRow == true,
            "next down arrow must select the first available workspace")
        expect(controller.handleShortcut(key(125)), "second down arrow must be handled")
        expect(initialRows.first(where: { $0.item.workspace == last })?.isSelectedRow == true, "arrow must skip unavailable workspace")
        expect(controller.handleShortcut(key(126)), "up arrow must be handled")
        expect(initialRows.first(where: { $0.item.workspace == first })?.isSelectedRow == true, "up arrow must restore prior selection")
        let actions = descendants(initialRows.first { $0.item.workspace == first }!).compactMap { $0 as? NSButton }.first { $0.toolTip?.contains("remove binding") == true }!
        window.makeFirstResponder(actions)
        expect(!controller.handleShortcut(key(36)), "Return on an actions button must retain its native action")
        expect(!controller.handleShortcut(key(125)), "arrows on a native control must retain native behaviour")
        controller.focusSearch()
        expect(initialRows.allSatisfy { !$0.isSelectedRow }, "focusing search on reopening must clear old selection")
        expect(controller.handleShortcut(key(126)), "up arrow must be handled from an unselected list")
        expect(initialRows.first(where: { $0.item.workspace == last })?.isSelectedRow == true,
            "first up arrow must select the last available workspace")
        controller.focusSearch()
        search.stringValue = "last"
        expect(search.sendAction(search.action, to: search.target), "native search action must have a receiver")
        expect(descendants(controller.view).compactMap { $0 as? LaunchRowButton }.count == 1, "search must replace list with matching workspace")
        expect(descendants(controller.view).compactMap { $0 as? LaunchRowButton }.allSatisfy { !$0.isSelectedRow },
            "typing a new search must clear prior keyboard selection")
        search.stringValue = ""
        _ = search.sendAction(search.action, to: search.target)
        expect(store.query.isEmpty && descendants(controller.view).compactMap { $0 as? LaunchRowButton }.count == 4,
            "native search cancel action must restore all workspaces")
        search.stringValue = "does-not-exist"
        _ = search.sendAction(search.action, to: search.target)
        window.setContentSize(controller.preferredContentSize)
        controller.view.layoutSubtreeIfNeeded()
        let reset = descendants(controller.view).compactMap { $0 as? NSButton }.first { $0.title == "Reset filters" }!
        expect(controller.view.convert(reset.bounds, from: reset).minY >= 50,
            "the no-match reset button must fit above the footer with padding")
        reset.performClick(nil)
        expect(store.query.isEmpty && descendants(controller.view).compactMap { $0 as? LaunchRowButton }.count == 4,
            "reset filters must restore the profile and workspace rows")
        search.stringValue = "last"
        _ = search.sendAction(search.action, to: search.target)
        var closed = false
        controller.onRequestClose = { closed = true }
        expect(controller.handleShortcut(key(53)), "escape must be handled")
        expect(store.query.isEmpty && !closed, "first escape must clear search without dismissing")
        expect(controller.handleShortcut(key(53)), "escape must dismiss without query")
        expect(closed, "empty-query escape must request popover close")
        closed = false
        _ = controller.handleShortcut(key(125))
        _ = controller.handleShortcut(key(125))
        _ = controller.handleShortcut(key(125))
        _ = controller.handleShortcut(key(36))
        for _ in 0..<100 where !closed { try await Task.sleep(nanoseconds: 10_000_000) }
        expect(closed, "successful Return launch must dismiss popover")
        let args = try String(contentsOf: marker, encoding: .utf8)
        expect(args.contains(last.path), "Return must launch selected available workspace")
        expect(!args.contains(missing.path), "keyboard launch must skip missing workspace")
        closed = false
        search.stringValue = "first"
        _ = search.sendAction(search.action, to: search.target)
        let firstRow = descendants(controller.view).compactMap { $0 as? LaunchRowButton }.first!
        openButton(in: firstRow).performClick(nil)
        for _ in 0..<100 where !closed { try await Task.sleep(nanoseconds: 10_000_000) }
        expect(closed, "successful explicit Open action must dismiss popover")
        let clickArgs = try String(contentsOf: marker, encoding: .utf8)
        expect(clickArgs.contains(first.path), "Open must launch its own workspace")
        expect(!clickArgs.contains(last.path), "Open must replace the prior launch arguments")
        closed = false
        search.stringValue = "last"
        _ = search.sendAction(search.action, to: search.target)
        _ = controller.handleShortcut(key(36))
        for _ in 0..<100 where !closed { try await Task.sleep(nanoseconds: 10_000_000) }
        let returnArgs = try String(contentsOf: marker, encoding: .utf8)
        expect(closed && returnArgs.contains(last.path),
            "Return without arrow navigation must open the first available search result")
        store.query = ""
        controller.focusSearch()
        closed = false
        _ = controller.handleShortcut(key(18, characters: "1", modifiers: .command))
        for _ in 0..<100 where !closed { try await Task.sleep(nanoseconds: 10_000_000) }
        let shortcutArguments = try String(contentsOf: marker, encoding: .utf8)
        expect(closed && shortcutArguments == "app\nwork\n", "Command-1 must open the first visible profile without a folder")
        let selectedRow = descendants(controller.view).compactMap { $0 as? LaunchRowButton }.first!
        expect(controller.view.appearance == nil && selectedRow.appearance == nil,
            "menu views must inherit the system appearance")
        selectedRow.isSelectedRow = true
        expect(selectedRow.isAccessibilitySelected(), "keyboard selection must be exposed to accessibility clients")
        selectedRow.displayIfNeeded()
        let expectedBorder = selectedRow.layer!.borderColor!
        selectedRow.layer!.borderColor = NSColor.clear.cgColor
        NotificationCenter.default.post(name: NSColor.systemColorsDidChangeNotification, object: nil)
        expect(selectedRow.layer!.borderColor == expectedBorder,
            "changing the system accent colours must update custom row decoration")
        selectedRow.layer!.borderColor = NSColor.clear.cgColor
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: NSWorkspace.shared)
        expect(selectedRow.layer!.borderColor == expectedBorder,
            "changing accessibility display options must update custom row decoration")
        var borders: [CGFloat] = []
        for appearance in [NSAppearance.Name.aqua, .darkAqua, .aqua] {
            window.appearance = NSAppearance(named: appearance)
            expect(selectedRow.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == appearance,
                "an open menu must inherit light and dark appearance changes")
            selectedRow.displayIfNeeded()
            selectedRow.updateLayer()
            let border = NSColor(cgColor: selectedRow.layer!.borderColor!)!.usingColorSpace(.sRGB)!
            borders.append(border.redComponent)
            expect(selectedRow.layer!.borderWidth > 0, "keyboard selection must include a shape cue rather than relying on colour")
            for preferences in [(true, false), (false, true), (true, true)] {
                selectedRow.updateSystemColours(reduceTransparency: preferences.0, increaseContrast: preferences.1)
                expect(selectedRow.layer!.backgroundColor!.alpha > 0.99,
                    "reduced transparency and increased contrast must use opaque system selection colours")
            }
        }
        expect(borders[0] < 0.5 && borders[1] > 0.5 && borders[2] < 0.5,
            "custom row decoration must resolve semantic colours again when appearance changes")
        let expired = ProfileUsage.available(CodexRateLimits(windows: [RateLimitWindow(usedPercent: 80, windowDurationMins: nil, resetsAt: 1)]), checkedAt: checkedAt)
        store.loadPreview([], profiles: ["very-long-profile-name-for-a-client", "work"], usage: [
            "work": expired, "very-long-profile-name-for-a-client": .unavailable(checkedAt: checkedAt),
        ])
        window.setContentSize(controller.preferredContentSize)
        controller.view.layoutSubtreeIfNeeded()
        let quotaRows = descendants(controller.view).compactMap { $0 as? LaunchRowButton }
        expect(descendants(quotaRows[0]).compactMap { $0 as? NSTextField }.contains { $0.stringValue == "Unavailable" },
            "missing quota must say Unavailable rather than zero")
        expect(openButton(in: quotaRows[0]).isEnabled, "unavailable quota must not disable Open")
        expect(descendants(quotaRows[1]).compactMap { $0 as? NSTextField }.contains { $0.stringValue == "—" },
            "a passed reset must not show stale percentages")
        let longName = descendants(quotaRows[0]).compactMap { $0 as? NSTextField }.first { $0.stringValue == "very-long-profile-name-for-a-client" }!
        expect(longName.lineBreakMode == .byTruncatingTail && longName.toolTip == longName.stringValue,
            "long profile names must truncate while retaining the full name on hover")
        store.loadPreview((0..<12).map { workspace("/projects/project-\($0)") })
        window.setContentSize(controller.preferredContentSize)
        controller.view.layoutSubtreeIfNeeded()
        let longList = descendants(controller.view).compactMap { $0 as? NSScrollView }.first!
        expect(controller.preferredContentSize.height == 500, "long lists must retain the compact height limit")
        expect(longList.documentView!.bounds.height > longList.contentView.bounds.height,
            "projects beyond the height limit must remain in the scrollable document")
        print("Native menu interaction tests passed.")
    }

    private static func workspace(_ path: String, exists: Bool = true) -> WorkspaceBinding {
        WorkspaceBinding(path: path, profile: "work", pathExists: exists, profileExists: true)
    }
    private static func key(_ code: UInt16, characters: String = "", modifiers: NSEvent.ModifierFlags = []) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 0, windowNumber: 0, context: nil, characters: characters, charactersIgnoringModifiers: characters, isARepeat: false, keyCode: code)!
    }
    private static func descendants(_ view: NSView) -> [NSView] {
        view.subviews.flatMap { [$0] + descendants($0) }
    }
    private static func openButton(in row: LaunchRowButton) -> NSButton {
        descendants(row).compactMap { $0 as? NSButton }.first { ["Open", "Opening…"].contains($0.title) }!
    }
    private static func isMonochrome(_ color: NSColor?) -> Bool {
        color == .labelColor || color == .secondaryLabelColor
    }
    private static func expect(_ value: @autoclosure () -> Bool, _ message: String) {
        guard value() else { fatalError(message) }
    }
}
