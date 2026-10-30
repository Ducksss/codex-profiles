import AppKit
import Carbon.HIToolbox
import Foundation

@MainActor
@main
struct MenuInteractionTests {
    static func main() async throws {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        let suite = WorkspaceStore.testSuiteName("menu-interaction")
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
        let usageText = descendants(usageView).compactMap { $0 as? NSTextField }
        expect(usageText.map(\.stringValue) == ["9%", "7d left"],
            "profile rows must show the tightest window's remaining percentage and actual duration")
        expect(usageText[0].attributedStringValue.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor == QuotaPalette.critical,
            "a critical window's figure must carry the critical colour")
        expect(descendants(usageView).contains { $0 is QuotaRing }, "the figure must sit beside a ring")
        expect(profileRow.accessibilityLabel()!.contains("77% remaining") && profileRow.accessibilityLabel()!.contains("Resets"),
            "every window's quota and reset time must be available to accessibility clients")
        expect(usageView.toolTip!.contains("ChatGPT may use a different account") && usageView.toolTip!.contains("Checked"),
            "quota tooltips must explain sign-in scope and freshness")
        let profileArguments = try await launchArguments(recordedIn: marker, until: { profileClosed },
            "a profile launch must dismiss the menu and record its arguments") { profileRow.performClick(nil) }
        expect(profileArguments == "app\nwork\n", "clicking a profile must open it without supplying a workspace path")
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
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 480), styleMask: .borderless, backing: .buffered, defer: false)
        window.contentViewController = controller
        window.setContentSize(controller.preferredContentSize)
        controller.view.layoutSubtreeIfNeeded()
        controller.focusSearch()
        expect(controller.preferredContentSize.width == WorkspaceMenuViewController.width, "popover must retain its compact width")
        let allViews = descendants(controller.view)
        expect(!(controller.view is NSVisualEffectView) && !allViews.contains { $0 is NSVisualEffectView },
            "NSPopover must own its background material without a duplicate effect layer")
        let searchFields = allViews.compactMap { $0 as? NSSearchField }
        expect(searchFields.count == 1, "workspace search must use native NSSearchField")
        let search = searchFields[0]
        let options = allViews.compactMap { $0 as? NSButton }.first { $0.toolTip == "Options" }!
        let searchCenter = controller.view.convert(NSPoint(x: search.bounds.midX, y: search.bounds.midY), from: search)
        let optionsCenter = controller.view.convert(NSPoint(x: options.bounds.midX, y: options.bounds.midY), from: options)
        expect(abs(searchCenter.y - optionsCenter.y) < 1, "search and options must share one compact header line")
        expect(allViews.compactMap { $0 as? NSTextField }.first { $0.stringValue == "Codex Profiles" }!.isHidden,
            "search must take the title's place once there is something to search")
        expect(!allViews.contains { $0 is NSPopUpButton || $0 is NSSegmentedControl },
            "nesting and Command-Return replace the profile filter and destination control")
        let initialRows = descendants(controller.view).compactMap { $0 as? LaunchRowButton }
        let list = descendants(controller.view).compactMap { $0 as? NSScrollView }.first!
        let listWidth = list.contentView.bounds.width
        expect(initialRows.map(\.item) == [.profile("work"), .workspace(first), .workspace(missing), .workspace(last)],
            "workspaces must follow their profile, pinned first")
        expect(list.documentView!.bounds.height <= list.contentView.bounds.height + 1,
            "a short list must fit without clipping the last row or needing to scroll")
        expect(initialRows.allSatisfy { abs($0.frame.width - listWidth) < 1 }, "rows must fill the list width")
        expect(!descendants(list).contains { $0 is GroupDivider }, "one profile group needs no divider")
        let titleColumn = descendants(initialRows[0]).compactMap { $0 as? NSTextField }.first { $0.stringValue == "work" }!
        // Labels pad their frames; the alignment rect is where the text starts.
        let titleX = list.documentView!.convert(titleColumn.alignmentRect(forFrame: titleColumn.frame), from: titleColumn.superview).minX
        let profileUsage = descendants(initialRows[0]).compactMap { $0 as? ProfileUsageView }.first!
        let profileActions = actionsButton(in: initialRows[0])
        let nameFrame = initialRows[0].convert(titleColumn.bounds, from: titleColumn)
        let usageFrame = initialRows[0].convert(profileUsage.bounds, from: profileUsage)
        let actionsFrame = initialRows[0].convert(profileActions.bounds, from: profileActions)
        expect(nameFrame.maxX <= usageFrame.minX && usageFrame.maxX <= actionsFrame.minX && actionsFrame.maxX <= initialRows[0].bounds.maxX,
            "quota must fit beside the profile without obscuring its name or actions")
        expect(abs(initialRows[0].frame.height - 46) < 1, "profile rows must stay compact")
        for row in initialRows where row.item.workspace != nil {
            expect(!descendants(row).contains { $0 is ProfileUsageView }, "workspace rows must not duplicate account quota")
            let workspace = row.item.workspace!
            let labels = descendants(row).compactMap { $0 as? NSTextField }
            let name = labels.first { $0.stringValue == workspace.name }!
            let detail = labels.first { $0.stringValue == (workspace.availabilityReason.map { "\($0) · " } ?? "") + workspace.displayPath() }!
            expect(!labels.contains { $0.stringValue == workspace.profile }, "a nested workspace must not repeat its profile")
            let icon = descendants(row).compactMap { $0 as? NSImageView }.first!
            expect(abs(list.documentView!.convert(icon.frame, from: icon.superview).minX - titleX) < 1,
                "a nested workspace must start at its profile's title column")
            expect(isMonochrome(icon.contentTintColor), "folder and pin symbols must use native monochrome tint")
            if workspace.isAvailable {
                expect(abs(baseline(of: name) - baseline(of: detail)) < 1, "a workspace's name and path must share one line")
                expect(actionsButton(in: row).alphaValue == 0, "resting rows must keep their actions out of sight")
            } else {
                expect(baseline(of: name) > baseline(of: detail) + 8, "a missing folder must explain itself on a second line")
                expect(actionsButton(in: row).alphaValue == 1, "rows that need repair must always show their actions")
                expect(descendants(row).compactMap { $0 as? NSButton }.contains { $0.title == "Locate…" }, "a missing folder must offer to locate it")
            }
            expect(row.isEnabled == workspace.isAvailable, "launching must match workspace availability")
            expect(abs(row.frame.height - (workspace.isAvailable ? 30 : 44)) < 1,
                "workspace rows must stay to one line unless they explain a missing folder")
        }
        expect(initialRows.allSatisfy { !$0.isSelectedRow }, "opening must not paint an unsolicited selection")
        expect(controller.handleShortcut(key(125)), "down arrow must be handled")
        expect(initialRows.first?.item == .profile("work") && initialRows.first?.isSelectedRow == true,
            "first down arrow must select the profile before its workspaces")
        expect(controller.handleShortcut(key(125)), "next down arrow must be handled")
        let firstRow = initialRows.first { $0.item.workspace == first }!
        expect(firstRow.isSelectedRow && actionsButton(in: firstRow).alphaValue == 1,
            "next down arrow must select the first available workspace and reveal its actions")
        expect(controller.handleShortcut(key(125)), "second down arrow must be handled")
        expect(initialRows.first(where: { $0.item.workspace == last })?.isSelectedRow == true, "arrow must skip unavailable workspace")
        expect(actionsButton(in: firstRow).alphaValue == 0, "actions must hide again once the selection moves on")
        let footer = allViews.compactMap { $0 as? NSTextField }.first { $0.stringValue.hasPrefix("↩ ") }!
        expect(footer.stringValue == "↩ Open last in ChatGPT  ·  ⌘↩ Terminal", "the footer must name what Return and Command-Return open")
        expect(controller.handleShortcut(key(126)), "up arrow must be handled")
        expect(firstRow.isSelectedRow, "up arrow must restore prior selection")
        window.makeFirstResponder(actionsButton(in: firstRow))
        expect(!controller.handleShortcut(key(36)), "Return on an actions button must retain its native action")
        expect(!controller.handleShortcut(key(36, modifiers: .command)), "Command-Return on a native control must retain native behaviour")
        expect(!controller.handleShortcut(key(125)), "arrows on a native control must retain native behaviour")
        controller.focusSearch()
        expect(initialRows.allSatisfy { !$0.isSelectedRow }, "focusing search on reopening must clear old selection")
        expect(footer.stringValue == "↩ Open in ChatGPT  ·  ⌘↩ Terminal", "without a selection the footer must describe both keys")
        expect(controller.handleShortcut(key(126)), "up arrow must be handled from an unselected list")
        expect(initialRows.first(where: { $0.item.workspace == last })?.isSelectedRow == true,
            "first up arrow must select the last available workspace")
        controller.focusSearch()
        search.stringValue = "last"
        expect(search.sendAction(search.action, to: search.target), "native search action must have a receiver")
        let searchRows = descendants(controller.view).compactMap { $0 as? LaunchRowButton }
        expect(searchRows.count == 1, "search must replace list with matching workspace")
        expect(searchRows[0].isSelectedRow, "typing a search must select its first match so Return's target is visible")
        expect(descendants(searchRows[0]).compactMap { $0 as? NSTextField }.contains { $0.stringValue == "work" },
            "a match listed without its profile must name the profile")
        search.stringValue = ""
        _ = search.sendAction(search.action, to: search.target)
        expect(store.query.isEmpty && descendants(controller.view).compactMap { $0 as? LaunchRowButton }.count == 4,
            "native search cancel action must restore all workspaces")
        expect(descendants(controller.view).compactMap { $0 as? LaunchRowButton }.allSatisfy { !$0.isSelectedRow },
            "clearing the search must leave the list unselected")
        search.stringValue = "does-not-exist"
        _ = search.sendAction(search.action, to: search.target)
        window.setContentSize(controller.preferredContentSize)
        controller.view.layoutSubtreeIfNeeded()
        let clear = descendants(controller.view).compactMap { $0 as? NSButton }.first { $0.title == "Clear search" }!
        expect(controller.view.convert(clear.bounds, from: clear).minY >= 50,
            "the no-match button must fit above the footer with padding")
        clear.performClick(nil)
        expect(store.query.isEmpty && descendants(controller.view).compactMap { $0 as? LaunchRowButton }.count == 4,
            "clearing the search must restore the profile and workspace rows")
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
        let args = try await launchArguments(recordedIn: marker, until: { closed },
            "successful Return launch must dismiss popover and record its arguments") { _ = controller.handleShortcut(key(36)) }
        expect(args.contains(last.path), "Return must launch selected available workspace")
        expect(!args.contains(missing.path), "keyboard launch must skip missing workspace")
        closed = false
        search.stringValue = "first"
        _ = search.sendAction(search.action, to: search.target)
        let firstMatch = descendants(controller.view).compactMap { $0 as? LaunchRowButton }.first!
        let clickArgs = try await launchArguments(recordedIn: marker, until: { closed },
            "a successful click must dismiss popover and record its arguments") { firstMatch.performClick(nil) }
        expect(clickArgs.contains(first.path), "clicking must launch its own workspace")
        expect(!clickArgs.contains(last.path), "clicking must replace the prior launch arguments")
        closed = false
        search.stringValue = "last"
        _ = search.sendAction(search.action, to: search.target)
        let returnArgs = try await launchArguments(recordedIn: marker, until: { closed },
            "Return without arrow navigation must dismiss popover and record its arguments") { _ = controller.handleShortcut(key(36)) }
        expect(returnArgs.contains(last.path), "Return without arrow navigation must open the first available search result")
        store.query = ""
        controller.focusSearch()
        closed = false
        let shortcutArguments = try await launchArguments(recordedIn: marker, until: { closed },
            "Command-1 must dismiss popover and record its arguments") {
            _ = controller.handleShortcut(key(18, characters: "1", modifiers: .command))
        }
        expect(shortcutArguments == "app\nwork\n", "Command-1 must open the first visible profile without a folder")
        let selectedRow = descendants(controller.view).compactMap { $0 as? LaunchRowButton }.first!
        expect(controller.view.appearance == nil && selectedRow.appearance == nil,
            "menu views must inherit the system appearance")
        selectedRow.isSelectedRow = true
        expect(selectedRow.isAccessibilitySelected(), "keyboard selection must be exposed to accessibility clients")
        selectedRow.displayIfNeeded()
        let expectedBorder = selectedRow.highlight.layer!.borderColor!
        selectedRow.highlight.layer!.borderColor = NSColor.clear.cgColor
        NotificationCenter.default.post(name: NSColor.systemColorsDidChangeNotification, object: nil)
        expect(selectedRow.highlight.layer!.borderColor == expectedBorder,
            "changing the system accent colours must update custom row decoration")
        selectedRow.highlight.layer!.borderColor = NSColor.clear.cgColor
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: NSWorkspace.shared)
        expect(selectedRow.highlight.layer!.borderColor == expectedBorder,
            "changing accessibility display options must update custom row decoration")
        var borders: [CGFloat] = []
        for appearance in [NSAppearance.Name.aqua, .darkAqua, .aqua] {
            window.appearance = NSAppearance(named: appearance)
            expect(selectedRow.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == appearance,
                "an open menu must inherit light and dark appearance changes")
            selectedRow.displayIfNeeded()
            selectedRow.updateLayer()
            let border = NSColor(cgColor: selectedRow.highlight.layer!.borderColor!)!.usingColorSpace(.sRGB)!
            borders.append(border.redComponent)
            expect(selectedRow.highlight.layer!.borderWidth > 0, "keyboard selection must include a shape cue rather than relying on colour")
            for preferences in [(true, false), (false, true), (true, true)] {
                selectedRow.updateSystemColours(reduceTransparency: preferences.0, increaseContrast: preferences.1)
                expect(selectedRow.highlight.layer!.backgroundColor!.alpha > 0.99,
                    "reduced transparency and increased contrast must use opaque system selection colours")
            }
        }
        expect(borders[0] < 0.5 && borders[1] > 0.5 && borders[2] < 0.5,
            "custom row decoration must resolve semantic colours again when appearance changes")
        // Emphasis colours resolve per appearance: darker in light mode for contrast, lighter in dark mode.
        var criticalRed: [CGFloat] = []
        for appearance in [NSAppearance.Name.aqua, .darkAqua] {
            NSAppearance(named: appearance)!.performAsCurrentDrawingAppearance {
                criticalRed.append(QuotaPalette.critical.usingColorSpace(.sRGB)!.greenComponent)
            }
        }
        expect(criticalRed[0] < 0.1 && criticalRed[1] > 0.3, "quota emphasis must adapt to light and dark appearance")
        let expired = ProfileUsage.available(CodexRateLimits(windows: [RateLimitWindow(usedPercent: 80, windowDurationMins: nil, resetsAt: 1)]), checkedAt: checkedAt)
        store.loadPreview([], profiles: ["very-long-profile-name-for-a-client", "work"], usage: [
            "work": expired, "very-long-profile-name-for-a-client": .unavailable(checkedAt: checkedAt),
        ])
        window.setContentSize(controller.preferredContentSize)
        controller.view.layoutSubtreeIfNeeded()
        let quotaRows = descendants(controller.view).compactMap { $0 as? LaunchRowButton }
        expect(descendants(quotaRows[0]).compactMap { $0 as? NSTextField }.contains { $0.stringValue == "Unavailable" },
            "missing quota must say Unavailable rather than zero")
        expect(quotaRows[0].isEnabled, "unavailable quota must not prevent launching")
        expect(descendants(quotaRows[1]).compactMap { $0 as? NSTextField }.map(\.stringValue).contains("—"),
            "a passed reset must not show stale percentages")
        expect(descendants(controller.view).filter { $0 is GroupDivider }.count == 1, "separate profiles must be divided into groups")
        let longName = descendants(quotaRows[0]).compactMap { $0 as? NSTextField }.first { $0.stringValue == "very-long-profile-name-for-a-client" }!
        expect(longName.lineBreakMode == .byTruncatingTail && longName.toolTip == longName.stringValue,
            "long profile names must truncate while retaining the full name on hover")
        store.loadPreview((0..<16).map { workspace("/projects/project-\($0)") })
        window.setContentSize(controller.preferredContentSize)
        controller.view.layoutSubtreeIfNeeded()
        let longList = descendants(controller.view).compactMap { $0 as? NSScrollView }.first!
        expect(controller.preferredContentSize.height == 500, "long lists must retain the compact height limit")
        expect(longList.documentView!.bounds.height > longList.contentView.bounds.height,
            "projects beyond the height limit must remain in the scrollable document")

        // A workspace whose profile is missing follows the groups and names its profile.
        let orphan = WorkspaceBinding(path: "/projects/orphan", profile: "gone", pathExists: true, profileExists: false)
        store.loadPreview([first, orphan], profiles: ["work"])
        let orphanRows = descendants(controller.view).compactMap { $0 as? LaunchRowButton }
        expect(orphanRows.map(\.item) == [.profile("work"), .workspace(first), .workspace(orphan)]
            && descendants(controller.view).filter { $0 is GroupDivider }.count == 1,
            "a workspace without a listed profile must follow the profile groups after a divider")
        expect(descendants(orphanRows[2]).compactMap { $0 as? NSTextField }.contains { $0.stringValue == "gone" } && !orphanRows[2].isEnabled,
            "a workspace without its profile must name it and refuse to launch")

        // Usage readings stream in after opening; they must not rebuild the list.
        store.loadPreview([first], profiles: ["work", "personal"], usage: ["work": quota])
        let stableRow = descendants(controller.view).compactMap { $0 as? LaunchRowButton }.first { $0.item == .profile("work") }!
        let lowQuota = ProfileUsage.available(CodexRateLimits(windows: [
            RateLimitWindow(usedPercent: 95, windowDurationMins: 300, resetsAt: checkedAt.addingTimeInterval(4320).timeIntervalSince1970),
        ]), checkedAt: checkedAt)
        store.loadPreview([first], profiles: ["work", "personal"], usage: ["work": lowQuota], readingUsage: ["work"])
        let updatedRow = descendants(controller.view).compactMap { $0 as? LaunchRowButton }.first { $0.item == .profile("work") }!
        expect(updatedRow === stableRow, "a usage reading must update rows in place without rebuilding the list")
        let updatedText = descendants(updatedRow).compactMap { $0 as? NSTextField }.map(\.stringValue)
        expect(updatedText.contains("5%") && updatedText.contains("5h left") && updatedText.contains { $0.hasPrefix("5h limit low · resets in ") },
            "the row must show the newer reading and when the low window resets")
        let refreshingUsage = descendants(updatedRow).compactMap { $0 as? ProfileUsageView }.first!
        expect(refreshingUsage.arrangedSubviews.allSatisfy { $0.alphaValue < 1 } && refreshingUsage.toolTip!.contains("Refreshing"),
            "a refresh must dim the previous reading rather than hide it")
        // A low row names a fresh, healthier profile; it never switches to it.
        let healthy = ProfileUsage.available(CodexRateLimits(windows: [
            RateLimitWindow(usedPercent: 20, windowDurationMins: 300, resetsAt: checkedAt.addingTimeInterval(7200).timeIntervalSince1970),
        ]), checkedAt: Date())
        store.loadPreview([first], profiles: ["work", "personal"], usage: ["work": lowQuota, "personal": healthy])
        let suggestingRow = descendants(controller.view).compactMap { $0 as? LaunchRowButton }.first { $0.item == .profile("work") }!
        expect(descendants(suggestingRow).compactMap { $0 as? NSTextField }.contains { $0.stringValue == "5h limit low · personal has 80%" }
            && suggestingRow.accessibilityLabel()!.contains("personal has 80% of the same window left")
            && suggestingRow.toolTip!.contains("Resets in"),
            "a low row must name a healthier profile while its tooltip keeps the reset time")
        expect(store.profiles == ["personal", "work"] && store.launchingID == nil, "a suggestion must never switch or launch a profile")

        // A row whose binding is changing shows progress and refuses launches.
        store.loadPreview([first, last], profiles: ["work"], usage: ["work": quota], changingPaths: [last.path])
        let changingRow = descendants(controller.view).compactMap { $0 as? LaunchRowButton }.first { $0.item.workspace == last }!
        expect(!changingRow.isEnabled && descendants(changingRow).compactMap { $0 as? NSTextField }.contains { $0.stringValue == "Updating…" },
            "a row being changed must show progress and refuse launches")
        expect(!actionsButton(in: changingRow).isEnabled, "a row being changed must not accept another change")
        controller.focusSearch()
        _ = controller.handleShortcut(key(125))
        _ = controller.handleShortcut(key(125))
        _ = controller.handleShortcut(key(125))
        expect(changingRow.isSelectedRow == false, "keyboard selection must skip a row being changed")

        // The profile's actions list every window, which the row's single figure leaves out.
        let usageMenu = controller.actionsMenu(for: .profile("work"))
        let usageLines = usageMenu.items.prefix { !$0.isSeparatorItem }
        expect(usageLines.map(\.title).first == "Codex CLI usage" && usageLines.allSatisfy { !$0.isEnabled }
            && usageLines.contains { $0.title.hasPrefix("5h: 77% left · resets ") } && usageLines.contains { $0.title.hasPrefix("7d: 9% left · resets ") }
            && usageLines.contains { $0.title.hasPrefix("Checked ") },
            "profile actions must list each window's remaining quota, reset time and freshness as information")
        let passed = ProfileUsage.available(CodexRateLimits(windows: [
            RateLimitWindow(usedPercent: 60, windowDurationMins: 300, resetsAt: checkedAt.addingTimeInterval(-60).timeIntervalSince1970),
        ]), checkedAt: checkedAt)
        store.loadPreview([first, last], profiles: ["work"], usage: ["work": passed])
        expect(controller.actionsMenu(for: .profile("work")).items.contains { $0.title.hasPrefix("5h: reset at ") && $0.title.hasSuffix(" · awaiting a fresh reading") },
            "a window whose reset has passed must keep its reset time and say it awaits a fresh reading")

        // Disabled actions stay disabled through AppKit's menu validation.
        store.loadPreview([first, missing], profiles: ["work", "personal"])
        let missingMenu = controller.actionsMenu(for: .workspace(missing))
        missingMenu.update()
        expect(!item("Show in Finder", in: missingMenu).isEnabled && !item("Open in ChatGPT", in: missingMenu).isEnabled
            && !item("Open in Terminal", in: missingMenu).isEnabled,
            "a missing folder must not be revealed or opened from its actions")
        expect(item("Change profile", in: missingMenu).submenu!.items.allSatisfy { !$0.isEnabled }, "a missing folder cannot be reassigned")
        expect(item("Locate moved folder…", in: missingMenu).isEnabled, "a missing folder must remain repairable")
        let firstMenu = controller.actionsMenu(for: .workspace(first))
        let choices = item("Change profile", in: firstMenu).submenu!
        choices.update()
        expect(choices.items.first { $0.title == "work" }?.isEnabled == false && choices.items.first { $0.title == "personal" }?.isEnabled == true,
            "only another profile may be chosen")
        let profileMenu = controller.actionsMenu(for: .profile("work"))
        expect(["Open in ChatGPT", "Open in Terminal", "Add workspace…", "Sign in to Codex CLI…"].allSatisfy { item($0, in: profileMenu).isEnabled },
            "profile actions must offer both destinations, a workspace shortcut and CLI sign-in")
        expect(item("Remove profile…", in: profileMenu).isEnabled
            && !controller.actionsMenu(for: .profile("default")).items.contains { $0.title == "Remove profile…" },
            "a named profile must offer removal, while default, the stock ~/.codex, must not")
        let confirm = NSButton(title: "Remove profile", target: nil, action: nil)
        let confirmation = TypedConfirmation(expected: "work", button: confirm)
        let typed = NSTextField(string: "Work")
        let startedDisabled = !confirm.isEnabled
        confirmation.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: typed))
        let mismatchDisabled = !confirm.isEnabled
        typed.stringValue = "work"
        confirmation.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: typed))
        expect(startedDisabled && mismatchDisabled && confirm.isEnabled,
            "removal must stay disabled until the exact profile name is typed")
        let rowWithMenu = descendants(controller.view).compactMap { $0 as? LaunchRowButton }.first { $0.item.workspace == first }!
        expect(rowWithMenu.menu(for: NSEvent.mouseEvent(with: .rightMouseDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0,
            context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!)?.items.contains { $0.title == "Copy path" } == true,
            "right-clicking a row must offer the same actions as its actions button")

        // Each profile has a colour and symbol, chosen in an editor that replaces the list.
        let automatic = ProfileAppearance.automatic(for: "work")
        let personalTile = descendants(controller.view).compactMap { $0 as? RowAvatar }.first!
        expect(automatic == ProfileAppearance.automatic(for: "work") && automatic.symbol == .monogram && automatic.colour != .graphite
            && ProfileAppearance.automatic(for: "default").colour == .graphite && personalTile.profileAppearance == store.appearance(for: "personal"),
            "profiles must start with a stable automatic colour and their initial, graphite for default")
        let appearanceMenu = controller.actionsMenu(for: .profile("work"))
        appearanceMenu.performActionForItem(at: appearanceMenu.indexOfItem(withTitle: "Appearance…"))
        let editor = descendants(controller.view).compactMap { $0 as? AppearanceEditorView }.first!
        expect(descendants(controller.view).compactMap { $0 as? LaunchRowButton }.isEmpty && search.isHidden,
            "the appearance editor must replace the list and search")
        let swatches = descendants(editor).compactMap { $0 as? SwatchButton }
        let symbolChoices = descendants(editor).compactMap { $0 as? SymbolChoiceButton }
        expect(swatches.count == 8 && symbolChoices.count == 12
            && !swatches.contains { ["red", "orange", "yellow"].contains($0.colour.rawValue) },
            "the editor must offer eight colours, leaving out the quota colours, and twelve symbols")
        expect(swatches.filter { $0.state == .on }.map(\.colour) == [automatic.colour]
            && symbolChoices.filter { $0.state == .on }.map(\.symbol) == [.monogram],
            "the current colour and symbol must be marked as chosen")
        try? FileManager.default.removeItem(at: marker)
        swatches.first { $0.colour == .teal }!.performClick(nil)
        symbolChoices.first { $0.symbol == .flask }!.performClick(nil)
        let chosen = ProfileAppearance(colour: .teal, symbol: .flask)
        expect(store.appearance(for: "work") == chosen, "choices must show at once")
        // The CLI holds appearances for every tool; the shim records the last write.
        let savedChoice = "appearance\nwork\n--color\nteal\n--symbol\nflask\n"
        try await waitUntil { (try? String(contentsOf: marker, encoding: .utf8)) == savedChoice }
        expect((try? String(contentsOf: marker, encoding: .utf8)) == savedChoice, "choices must be saved through the CLI, in the order made")
        expect(descendants(controller.view).compactMap { $0 as? AppearanceEditorView }.first === editor
            && swatches.filter { $0.state == .on }.map(\.colour) == [.teal],
            "a choice must update the editor in place, so focus stays put")
        expect(controller.handleShortcut(key(53)) && !search.isHidden, "Escape must return from the editor to the list")
        let chosenTile = descendants(controller.view).compactMap { $0 as? LaunchRowButton }.first { $0.item == .profile("work") }
            .flatMap { descendants($0).compactMap { $0 as? RowAvatar }.first }!
        expect(chosenTile.profileAppearance == chosen, "the list must show the chosen colour and symbol")
        controller.editAppearance(of: "work")
        descendants(controller.view).compactMap { $0 as? NSButton }.first { $0.title == "Reset" }!.performClick(nil)
        expect(store.appearance(for: "work") == automatic, "Reset must restore the automatic appearance")
        try await waitUntil { (try? String(contentsOf: marker, encoding: .utf8)) == "appearance\nwork\n--reset\n" }
        expect((try? String(contentsOf: marker, encoding: .utf8)) == "appearance\nwork\n--reset\n", "Reset must be saved through the CLI")
        descendants(controller.view).compactMap { $0 as? NSButton }.first { $0.title == "Done" }!.performClick(nil)
        expect(descendants(controller.view).contains { $0 is LaunchRowButton } && !descendants(controller.view).contains { $0 is AppearanceEditorView },
            "Done must return to the list")
        store.query = "first"
        let taggedRow = descendants(controller.view).compactMap { $0 as? LaunchRowButton }.first!
        expect(descendants(taggedRow).contains { $0 is ColourDot }, "a search result without its profile row must mark the profile's colour")
        store.query = ""

        // A row action opens the other destination without changing the default.
        defaults.set(OpenDestination.terminal.rawValue, forKey: "openDestination")
        let login = FakeLoginItem()
        let terminalController = WorkspaceMenuViewController(store: store, defaults: defaults, loginItem: login)
        let terminalWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 480), styleMask: .borderless, backing: .buffered, defer: false)
        terminalWindow.contentViewController = terminalController
        var terminalClosed = false
        terminalController.onRequestClose = { terminalClosed = true }
        let alternate = terminalController.actionsMenu(for: .profile("work"))
        let alternateArguments = try await launchArguments(recordedIn: marker, until: { terminalClosed },
            "Open in ChatGPT must dismiss the menu and record its arguments") {
            alternate.performActionForItem(at: alternate.indexOfItem(withTitle: "Open in ChatGPT"))
        }
        expect(alternateArguments == "app\nwork\n", "Open in ChatGPT must launch ChatGPT while Terminal stays the default")
        expect(defaults.string(forKey: "openDestination") == OpenDestination.terminal.rawValue, "a row action must not change the default destination")
        terminalController.focusSearch()
        terminalClosed = false
        let commandReturnArguments = try await launchArguments(recordedIn: marker, until: { terminalClosed },
            "Command-Return must dismiss the menu and record its arguments") {
            expect(terminalController.handleShortcut(key(36, modifiers: .command)), "Command-Return must be handled from search")
        }
        expect(commandReturnArguments == "app\npersonal\n", "Command-Return must open the first row in ChatGPT while Terminal is the default")
        var returnOpens = item("Return opens in", in: terminalController.settingsMenu()).submenu!
        expect(item("Terminal", in: returnOpens).state == .on && item("ChatGPT", in: returnOpens).state == .off,
            "the options menu must show which destination Return opens")
        returnOpens.performActionForItem(at: returnOpens.indexOfItem(withTitle: "ChatGPT"))
        returnOpens = item("Return opens in", in: terminalController.settingsMenu()).submenu!
        expect(defaults.string(forKey: "openDestination") == OpenDestination.chatGPT.rawValue && item("ChatGPT", in: returnOpens).state == .on,
            "choosing a destination must persist it")
        // A launch reports its outcome in the footer until the next reload.
        store.loadPreview([first, missing], profiles: ["work", "personal"])
        expect(descendants(terminalController.view).compactMap { $0 as? NSTextField }.contains { $0.stringValue == "↩ Open in ChatGPT  ·  ⌘↩ Terminal" },
            "the footer must follow the chosen destination")

        // The global shortcut is opt-in and reports keys another app holds.
        let shortcutItem = "Keyboard shortcut \(GlobalShortcut.label)"
        var settings = terminalController.settingsMenu()
        expect(item(shortcutItem, in: settings).state == .off, "the global shortcut must start off")
        terminalController.onGlobalShortcutChange = { _ in false }
        settings.performActionForItem(at: settings.indexOfItem(withTitle: shortcutItem))
        expect(!defaults.bool(forKey: GlobalShortcut.preferenceKey) && store.statusMessage.hasSuffix("is already used by another app"),
            "a refused shortcut must stay off and say why")
        var requested: [Bool] = []
        terminalController.onGlobalShortcutChange = { requested.append($0); return true }
        settings = terminalController.settingsMenu()
        settings.performActionForItem(at: settings.indexOfItem(withTitle: shortcutItem))
        expect(defaults.bool(forKey: GlobalShortcut.preferenceKey) && item(shortcutItem, in: terminalController.settingsMenu()).state == .on,
            "choosing the shortcut must turn it on and persist it")
        settings = terminalController.settingsMenu()
        settings.performActionForItem(at: settings.indexOfItem(withTitle: shortcutItem))
        expect(requested == [true, false] && !defaults.bool(forKey: GlobalShortcut.preferenceKey), "choosing it again must release it")
        // A real registration holds the keys until released, so a second one is refused.
        var held = GlobalShortcut(action: {})
        if held != nil {
            expect(GlobalShortcut(action: {}) == nil, "keys already held must be refused")
            held = nil
            expect(GlobalShortcut(action: {}) != nil, "released keys must be available again")
        } else {
            print("Skipping global shortcut registration: \(GlobalShortcut.label) is held by another app.")
        }
        // The shortcut uses the key that types P with Command held.
        for (layout, key, reason) in [
            ("com.apple.keylayout.US", kVK_ANSI_P, "US must use the P key"),
            ("com.apple.keylayout.Dvorak", kVK_ANSI_R, "Dvorak must use its own P, on QWERTY's R key"),
            ("com.apple.keylayout.DVORAK-QWERTYCMD", kVK_ANSI_P, "Dvorak – QWERTY ⌘ must keep QWERTY's P under Command"),
        ] {
            let filter = [kTISPropertyInputSourceID as String: layout] as CFDictionary
            guard let source = (TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource])?.first else {
                print("Skipping \(layout): the layout is not installed.")
                continue
            }
            expect(GlobalShortcut.keyCode(in: source) == UInt32(key), reason)
        }

        // Open at Login reflects and changes the login item.
        settings = terminalController.settingsMenu()
        expect(item("Open at Login", in: settings).state == .off, "Open at Login must start off")
        settings.performActionForItem(at: settings.indexOfItem(withTitle: "Open at Login"))
        expect(login.status == .enabled && item("Open at Login", in: terminalController.settingsMenu()).state == .on,
            "choosing Open at Login must register the app")
        settings = terminalController.settingsMenu()
        settings.performActionForItem(at: settings.indexOfItem(withTitle: "Open at Login"))
        expect(login.status == .disabled && !login.openedSettings, "choosing it again must unregister the app")
        login.statusAfterRegister = .requiresApproval
        settings = terminalController.settingsMenu()
        settings.performActionForItem(at: settings.indexOfItem(withTitle: "Open at Login"))
        expect(login.openedSettings && item("Open at Login", in: terminalController.settingsMenu()).state == .mixed,
            "a login item awaiting approval must open Login Items settings and show a mixed state")

        // Low-quota alerts start off and ask for permission only when chosen.
        // Fresh readings keep the background pass from starting a reader.
        store.loadPreview([], profiles: ["work"], usage: ["work": quota])
        let notifier = FakeNotifier()
        let alerts = QuotaAlertController(store: store, notifier: notifier, defaults: defaults, refreshInterval: 3600)
        let alertsController = WorkspaceMenuViewController(store: store, defaults: defaults, loginItem: login, alerts: alerts)
        _ = alertsController.view
        alerts.start()
        settings = alertsController.settingsMenu()
        settings.update()
        expect(item("Low-quota alerts", in: settings).state == .off && item("Low-quota alerts", in: settings).isEnabled
            && notifier.requests == 0 && notifier.permissionChecks == 0,
            "Low-quota alerts must start off without touching notification permission")
        expect(!terminalController.settingsMenu().items.contains { $0.title == "Low-quota alerts" },
            "the toggle needs an alerts controller")
        settings.performActionForItem(at: settings.indexOfItem(withTitle: "Low-quota alerts"))
        try await waitUntil { store.statusMessage.hasPrefix("Low-quota alerts") }
        expect(alerts.isEnabled && notifier.requests == 1 && item("Low-quota alerts", in: alertsController.settingsMenu()).state == .on
            && store.statusMessage == "Low-quota alerts on · usage checked every 5 minutes",
            "choosing Low-quota alerts must ask once, turn alerts on and say how often usage is checked")
        expect(defaults.bool(forKey: "lowQuotaAlerts"), "the choice must persist")
        notifier.current = .notDetermined
        await alerts.refreshPermission()
        expect(item("Low-quota alerts", in: alertsController.settingsMenu()).state == .mixed,
            "alerts on without a permission answer must show the same mixed state as a denial")
        notifier.current = .denied
        await alerts.refreshPermission()
        let revoked = item("Low-quota alerts", in: alertsController.settingsMenu())
        expect(revoked.state == .mixed && revoked.toolTip?.contains("System Settings › Notifications") == true,
            "revoked notification permission must show a mixed state that explains where to allow it")
        settings = alertsController.settingsMenu()
        settings.performActionForItem(at: settings.indexOfItem(withTitle: "Low-quota alerts"))
        try await waitUntil { !alerts.isEnabled }
        expect(!alerts.isEnabled && !store.isRefreshingUsageInBackground && item("Low-quota alerts", in: alertsController.settingsMenu()).state == .off,
            "choosing it again must turn alerts and background reads off")
        settings = alertsController.settingsMenu()
        expect(item("Quota in menu bar", in: settings).state == .off, "the menu-bar figure must start off")
        settings.performActionForItem(at: settings.indexOfItem(withTitle: "Quota in menu bar"))
        expect(alerts.showsFigure && item("Quota in menu bar", in: alertsController.settingsMenu()).state == .on
            && store.isRefreshingUsageInBackground && notifier.requests == 1,
            "choosing Quota in menu bar must show the figure and keep readings fresh without asking for permission again")
        settings = alertsController.settingsMenu()
        settings.performActionForItem(at: settings.indexOfItem(withTitle: "Quota in menu bar"))
        expect(!alerts.showsFigure && !store.isRefreshingUsageInBackground, "choosing it again must hide the figure and stop background reads")

        // The status icon stays a labelled template image; low quota changes
        // its shape, never only its colour.
        let icons = [QuotaLevel.normal, .low, .critical].map { StatusItemIcon.image(for: $0, accessibilityDescription: "Codex Profiles. Low Codex quota: work") }
        expect(icons.allSatisfy { $0.isTemplate && $0.accessibilityDescription == "Codex Profiles. Low Codex quota: work" },
            "every icon state must be a template image carrying the accessibility label")
        // The badge fills the bottom-right 9-point square. Points name pixel
        // centres in its middle column: the bar, the gap, the dot, and a point
        // of solid badge beside the column.
        expect(icons[1].size.width > icons[0].size.width && StatusItemIcon.badgeDiameter == 9, "a badge must widen the icon")
        let column = icons[1].size.width - 4.5
        let bar = NSPoint(x: column, y: 5.5)
        let gap = NSPoint(x: column, y: 2.5)
        let dot = NSPoint(x: column, y: 1.5)
        let beside = NSPoint(x: column - 2, y: 4.5)
        for scale in [1, 2] {
            expect([bar, gap, dot, beside].allSatisfy { alpha(icons[1], at: $0, scale: scale) > 0.9 },
                "a low quota must add a solid badge at \(scale)x")
            expect(alpha(icons[2], at: bar, scale: scale) < 0.1 && alpha(icons[2], at: dot, scale: scale) < 0.1
                && alpha(icons[2], at: gap, scale: scale) > 0.9 && alpha(icons[2], at: beside, scale: scale) > 0.9,
                "a critical quota must cut a bar and a separate dot into the badge at \(scale)x")
        }
        print("Native menu interaction tests passed.")
    }

    @MainActor
    private final class FakeNotifier: QuotaNotifying {
        var current = NotificationPermission.notDetermined
        var permissionChecks = 0
        var requests = 0
        func permission() async -> NotificationPermission { permissionChecks += 1; return current }
        func requestPermission() async -> Bool { requests += 1; current = .allowed; return true }
        func post(_ notification: QuotaNotification) {}
    }

    /// Alpha of an image at a point, rendered at 1x like a standard display or
    /// 2x like a Retina menu bar.
    private static func alpha(_ image: NSImage, at point: NSPoint, scale: Int) -> CGFloat {
        let factor = CGFloat(scale)
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(image.size.width * factor), pixelsHigh: Int(image.size.height * factor),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        bitmap.size = image.size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        image.draw(in: NSRect(origin: .zero, size: image.size))
        NSGraphicsContext.restoreGraphicsState()
        return bitmap.colorAt(x: Int(point.x * factor), y: Int((image.size.height - point.y) * factor))?.alphaComponent ?? 0
    }

    @MainActor
    private final class FakeLoginItem: LoginItemControlling {
        var status = LoginItemStatus.disabled
        var statusAfterRegister = LoginItemStatus.enabled
        var openedSettings = false
        func register() throws { status = statusAfterRegister }
        func unregister() throws { status = .disabled }
        func openSystemSettings() { openedSettings = true }
    }

    private static func item(_ title: String, in menu: NSMenu) -> NSMenuItem {
        guard let item = menu.items.first(where: { $0.title == title }) else { fatalError("missing menu item: \(title)") }
        return item
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
    private static func actionsButton(in row: LaunchRowButton) -> NSButton {
        descendants(row).compactMap { $0 as? NSButton }.first { $0.toolTip?.hasPrefix("Open elsewhere") == true }!
    }
    /// A label's first baseline in window coordinates, which run upwards.
    private static func baseline(of label: NSTextField) -> CGFloat {
        label.convert(label.bounds, to: nil).maxY - label.firstBaselineOffsetFromTop
    }
    /// Polls until a condition holds or 10 seconds pass. Work usually settles
    /// within milliseconds; the bound only absorbs a loaded machine, and the
    /// caller's next expectation reports a condition that never held.
    private static func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(10)
        while !condition(), Date() < deadline { try await Task.sleep(nanoseconds: 10_000_000) }
    }
    /// Clears the shim's marker, runs a launch and returns the arguments the
    /// shim recorded. The menu closes only after the launch process exits, so
    /// a closed menu and a non-empty marker mean the arguments are complete.
    private static func launchArguments(recordedIn marker: URL, until closed: () -> Bool, _ message: String,
                                        launch: () -> Void) async throws -> String {
        try? FileManager.default.removeItem(at: marker)
        launch()
        var arguments = ""
        try await waitUntil {
            arguments = (try? String(contentsOf: marker, encoding: .utf8)) ?? ""
            return closed() && !arguments.isEmpty
        }
        expect(closed() && !arguments.isEmpty, message + " within 10 seconds")
        return arguments
    }
    private static func isMonochrome(_ color: NSColor?) -> Bool {
        color == .labelColor || color == .secondaryLabelColor
    }
    private static func expect(_ value: @autoclosure () -> Bool, _ message: String) {
        guard value() else { fatalError(message) }
    }
}
