import AppKit

@MainActor
final class WorkspaceMenuViewController: NSViewController {
    /// Everything that shapes the list except live usage. Usage updates rows in
    /// place, so streaming readings keep hover, focus and the VoiceOver cursor.
    private struct ListModel: Equatable {
        struct Row: Equatable {
            let item: LaunchTarget
            let pinned: Bool
            let launching: Bool
            let changing: Bool
            let enabled: Bool
        }

        let destination: OpenDestination
        let rows: [Row]
    }

    private struct LaunchRequest {
        let item: LaunchTarget
        let destination: OpenDestination
    }

    private let store: WorkspaceStore
    private let defaults: UserDefaults
    private let loginItem: LoginItemControlling
    private let searchField = NSSearchField()
    private let profilePicker = NSPopUpButton()
    private let destinationPicker = NSSegmentedControl(labels: ["ChatGPT", "Terminal"], trackingMode: .selectOne, target: nil, action: nil)
    private let toolbar = NSStackView()
    private let contentContainer = NSView()
    private let footerLabel = NSTextField(labelWithString: "")
    private let refreshButton = NSButton()
    private let addButton = NSButton()
    private var rows: [LaunchRowButton] = []
    private var scrollView: NSScrollView?
    private var selectedID: LaunchTarget.ID?
    private var heightConstraint: NSLayoutConstraint?
    private var destination: OpenDestination
    private var renderedList: ListModel?
    private var renderedProfiles: [String]?
    var onPreferredContentSizeChange: ((NSSize) -> Void)?
    var onRequestClose: (() -> Void)?

    init(store: WorkspaceStore, defaults: UserDefaults = .standard, loginItem: LoginItemControlling? = nil) {
        self.store = store
        self.defaults = defaults
        self.loginItem = loginItem ?? MainAppLoginItem()
        destination = defaults.string(forKey: "openDestination") == OpenDestination.terminal.rawValue ? .terminal : .chatGPT
        super.init(nibName: nil, bundle: nil)
        preferredContentSize = NSSize(width: 400, height: 260)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() {
        let surface = NSView()
        surface.translatesAutoresizingMaskIntoConstraints = false
        view = surface
        heightConstraint = surface.heightAnchor.constraint(equalToConstant: 260)
        NSLayoutConstraint.activate([surface.widthAnchor.constraint(equalToConstant: 400), heightConstraint!])
        buildInterface()
        NotificationCenter.default.addObserver(self, selector: #selector(redrawSystemColours),
            name: NSColor.systemColorsDidChangeNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(redrawSystemColours),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
        store.onChange = { [weak self] in self?.render() }
        store.onError = { [weak self] message in self?.presentError(message) }
        render()
        Task { await store.refreshIfNeeded() }
    }

    func focusSearch() {
        selectedID = nil
        for row in rows { row.isSelectedRow = false }
        view.window?.makeKey()
        if !searchField.isHidden { view.window?.makeFirstResponder(searchField) }
    }

    func handleShortcut(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.numericPad, .function])
        if modifiers.isEmpty {
            let responder = view.window?.firstResponder
            let navigatingList = responder === searchField || responder === searchField.currentEditor() || responder is LaunchRowButton
            if [125, 126, 36, 76].contains(event.keyCode), !navigatingList { return false }
            switch event.keyCode {
            case 125: moveSelection(by: 1); return true
            case 126: moveSelection(by: -1); return true
            case 36, 76:
                let targets = store.filteredTargets
                if let item = targets.first(where: { $0.id == selectedID }) ?? targets.first(where: store.canLaunch) { launch(item) }
                return true
            case 53:
                if !store.query.isEmpty { clearSearch() } else { onRequestClose?() }
                return true
            default: return false
            }
        }
        guard modifiers == .command else { return false }
        switch event.charactersIgnoringModifiers?.lowercased() {
        case "k": focusSearch(); return true
        case "r": refresh(); return true
        case "q": NSApp.terminate(nil); return true
        case let value?:
            let targets = store.filteredTargets
            guard let index = Int(value), (1...9).contains(index), targets.indices.contains(index - 1) else { return false }
            launch(targets[index - 1]); return true
        case nil: return false
        }
    }

    @objc private func searchChanged() {
        selectedID = nil
        store.query = searchField.stringValue
    }

    private func buildInterface() {
        let mark = NSImageView(image: NSImage(systemSymbolName: "square.stack.3d.up.fill", accessibilityDescription: nil) ?? NSImage())
        mark.symbolConfiguration = .init(pointSize: 18, weight: .medium)
        mark.contentTintColor = .labelColor
        mark.widthAnchor.constraint(equalToConstant: 22).isActive = true
        let title = label("Codex Profiles", size: 14, weight: .semibold)
        let settings = symbolButton("gearshape", title: "Options", action: #selector(showSettingsMenu(_:)))
        let header = NSStackView(views: [mark, title, NSView(), settings])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 8
        header.translatesAutoresizingMaskIntoConstraints = false
        let headerDivider = NSBox()
        headerDivider.boxType = .separator
        headerDivider.translatesAutoresizingMaskIntoConstraints = false

        searchField.placeholderString = "Search profiles and workspaces"
        searchField.font = .systemFont(ofSize: 12)
        searchField.controlSize = .small
        searchField.target = self
        searchField.action = #selector(searchChanged)
        searchField.sendsSearchStringImmediately = true
        searchField.stringValue = store.query
        searchField.setAccessibilityLabel("Search profile and workspace names or folder paths")
        profilePicker.target = self
        profilePicker.action = #selector(profileFilterChanged)
        profilePicker.controlSize = .small
        profilePicker.font = .systemFont(ofSize: 11)
        profilePicker.setAccessibilityLabel("Filter profiles and workspaces")
        profilePicker.widthAnchor.constraint(equalToConstant: 140).isActive = true
        destinationPicker.selectedSegment = destination == .chatGPT ? 0 : 1
        destinationPicker.segmentStyle = .rounded
        destinationPicker.controlSize = .small
        destinationPicker.target = self
        destinationPicker.action = #selector(destinationChanged)
        destinationPicker.font = .systemFont(ofSize: 11)
        destinationPicker.setAccessibilityLabel("Open in")
        destinationPicker.widthAnchor.constraint(equalToConstant: 190).isActive = true
        toolbar.orientation = .horizontal
        toolbar.alignment = .centerY
        toolbar.spacing = 8
        [profilePicker, NSView(), destinationPicker].forEach { toolbar.addArrangedSubview($0) }
        let controls = NSStackView(views: [searchField, toolbar])
        controls.orientation = .vertical
        controls.alignment = .width
        controls.spacing = 8
        controls.translatesAutoresizingMaskIntoConstraints = false
        searchField.heightAnchor.constraint(equalToConstant: 24).isActive = true
        toolbar.heightAnchor.constraint(equalToConstant: 24).isActive = true

        let divider = NSBox()
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        let add = addButton
        add.title = "Add workspace…"
        add.target = self
        add.action = #selector(addWorkspace(_:))
        add.image = NSImage(systemSymbolName: "plus", accessibilityDescription: nil)
        add.imagePosition = .imageLeading
        add.isBordered = false
        add.font = .systemFont(ofSize: 12)
        add.toolTip = "Optional: bind a project folder to a profile"
        add.setContentHuggingPriority(.required, for: .horizontal)
        footerLabel.font = .systemFont(ofSize: 11)
        footerLabel.textColor = .secondaryLabelColor
        footerLabel.lineBreakMode = .byTruncatingTail
        footerLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        footerLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        configureSymbolButton(refreshButton, symbol: "arrow.clockwise", title: "Refresh profiles, workspaces and Codex usage (⌘R)", action: #selector(refresh))
        let footer = NSStackView(views: [add, NSView(), footerLabel, refreshButton])
        footer.orientation = .horizontal
        footer.alignment = .centerY
        footer.spacing = 8
        footer.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        [header, headerDivider, controls, contentContainer, divider, footer].forEach { view.addSubview($0) }
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            header.heightAnchor.constraint(equalToConstant: 44),
            headerDivider.topAnchor.constraint(equalTo: header.bottomAnchor),
            headerDivider.leadingAnchor.constraint(equalTo: view.leadingAnchor), headerDivider.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controls.topAnchor.constraint(equalTo: headerDivider.bottomAnchor, constant: 10),
            controls.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            controls.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            contentContainer.topAnchor.constraint(equalTo: controls.bottomAnchor, constant: 8),
            contentContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: divider.topAnchor),
            divider.leadingAnchor.constraint(equalTo: view.leadingAnchor), divider.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            divider.bottomAnchor.constraint(equalTo: footer.topAnchor),
            footer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            footer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            footer.bottomAnchor.constraint(equalTo: view.bottomAnchor), footer.heightAnchor.constraint(equalToConstant: 38),
        ])
    }

    private func render() {
        let targets = store.filteredTargets
        let populated = store.phase == .ready && (!store.profiles.isEmpty || !store.workspaces.isEmpty)
        let shouldFocusSearch = populated && searchField.isHidden
        searchField.isHidden = !populated
        toolbar.isHidden = !populated
        addButton.isHidden = !populated || store.profiles.isEmpty
        footerLabel.stringValue = ["Choose a profile or workspace", "Create a profile to get started"].contains(store.statusMessage) ? "" : store.statusMessage
        footerLabel.toolTip = footerLabel.stringValue
        refreshButton.isEnabled = !store.isRefreshing && !store.isRefreshingUsage
        selectedID = targets.first { $0.id == selectedID && store.canLaunch($0) }?.id
        updateProfilePicker()

        let list = store.phase == .ready && !targets.isEmpty ? listModel(for: targets) : nil
        if let list, list == renderedList, scrollView != nil {
            for row in rows {
                row.isSelectedRow = row.item.id == selectedID
                if row.item.workspace == nil { row.update(usage: store.usageState(for: row.item.profile)) }
            }
            return
        }
        renderedList = list
        let scrollPosition = scrollView?.contentView.bounds.origin ?? .zero
        contentContainer.subviews.forEach { $0.removeFromSuperview() }
        rows.removeAll()
        scrollView = nil
        switch store.phase {
        case .idle, .loading:
            showState(symbol: "square.stack.3d.up", title: "Loading your profiles", detail: "Reading local profiles and bindings…", progress: true)
        case let .failed(message):
            showState(symbol: "exclamationmark.triangle", title: "Couldn’t load profiles", detail: message, actionTitle: "Try again", action: #selector(refresh))
        case .ready where store.profiles.isEmpty && store.workspaces.isEmpty:
            showState(symbol: "person.crop.circle.badge.plus", title: "Create your first profile", detail: "Open separate ChatGPT windows for work and personal use.", actionTitle: "Create profile…", action: #selector(createProfile))
        case .ready where targets.isEmpty:
            showState(symbol: "magnifyingglass", title: "No matches", detail: "Try another profile or project name.", actionTitle: "Reset filters", action: #selector(resetFilters))
        case .ready:
            if let list { showLaunchList(list) }
        }
        let contentHeight = scrollView?.documentView?.fittingSize.height
            ?? contentContainer.subviews.first.map { $0.fittingSize.height + 24 } ?? 100
        // Header, filters, separators and footer occupy 158 points.
        let height: CGFloat = populated ? min(500, max(260, 158 + contentHeight)) : 260
        heightConstraint?.constant = height
        preferredContentSize = NSSize(width: 400, height: height)
        onPreferredContentSizeChange?(preferredContentSize)
        view.layoutSubtreeIfNeeded()
        if shouldFocusSearch, view.window?.isKeyWindow == true { focusSearch() }
        if let scrollView {
            let maxY = max(0, (scrollView.documentView?.bounds.height ?? 0) - scrollView.contentView.bounds.height)
            scrollView.contentView.scroll(to: NSPoint(x: 0, y: min(scrollPosition.y, maxY)))
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
    }

    private func listModel(for targets: [LaunchTarget]) -> ListModel {
        ListModel(destination: destination, rows: targets.map { item in
            ListModel.Row(
                item: item,
                pinned: item.workspace.map(store.isPinned) ?? false,
                launching: store.launchingID == item.id,
                changing: store.isChanging(item),
                enabled: store.canLaunch(item) && store.launchingID == nil
            )
        })
    }

    /// Rebuilds the filter only when profiles change, so an open filter menu
    /// is not replaced while usage readings arrive.
    private func updateProfilePicker() {
        if renderedProfiles != store.profiles {
            profilePicker.removeAllItems()
            profilePicker.addItem(withTitle: "All profiles")
            for profile in store.profiles { profilePicker.addItem(withTitle: profile) }
            renderedProfiles = store.profiles
        }
        let index = store.selectedProfile.flatMap { store.profiles.firstIndex(of: $0) }.map { $0 + 1 } ?? 0
        if profilePicker.indexOfSelectedItem != index { profilePicker.selectItem(at: index) }
    }

    private func showLaunchList(_ list: ListModel) {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        let document = FlippedView()
        document.translatesAutoresizingMaskIntoConstraints = false
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(stack)
        var previousGroup: String?
        for (index, model) in list.rows.enumerated() {
            let item = model.item
            let groupTitle = item.workspace == nil ? "Profiles" : model.pinned ? "Pinned workspaces" : "Workspaces"
            if previousGroup != groupTitle {
                let heading = label(groupTitle, size: 10, weight: .semibold)
                heading.textColor = .secondaryLabelColor
                let group = NSStackView(views: [heading, NSView()])
                group.edgeInsets = NSEdgeInsets(top: 6, left: 14, bottom: 4, right: 10)
                if item.workspace == nil {
                    let usageHeading = label("Codex left", size: 10, weight: .semibold)
                    usageHeading.textColor = .secondaryLabelColor
                    usageHeading.alignment = .right
                    usageHeading.toolTip = "Remaining Codex CLI quota. ChatGPT may use a different account."
                    usageHeading.widthAnchor.constraint(equalToConstant: ProfileUsageView.columnWidth).isActive = true
                    group.addArrangedSubview(usageHeading)
                    let actionsSpace = NSView()
                    actionsSpace.widthAnchor.constraint(equalToConstant: 86).isActive = true
                    group.addArrangedSubview(actionsSpace)
                }
                group.heightAnchor.constraint(equalToConstant: 24).isActive = true
                stack.addArrangedSubview(group)
                group.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
                previousGroup = groupTitle
            }
            let row = LaunchRowButton(item: item, shortcutIndex: index, destination: list.destination,
                usage: item.workspace == nil ? store.usageState(for: item.profile) : nil, pinned: model.pinned,
                selected: selectedID == item.id, launching: model.launching, changing: model.changing,
                enabled: model.enabled, target: self, action: #selector(launchClicked(_:)))
            row.onShowActions = { [weak self] sender in
                guard let self else { return }
                self.actionsMenu(for: item).popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height), in: sender)
            }
            rows.append(row)
            stack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            if index < list.rows.count - 1 {
                let separator = NSBox()
                separator.boxType = .separator
                stack.addArrangedSubview(separator)
                separator.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            }
        }
        scroll.documentView = document
        scrollView = scroll
        contentContainer.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor), scroll.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: contentContainer.topAnchor), scroll.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            document.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor), document.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: document.leadingAnchor), stack.trailingAnchor.constraint(equalTo: document.trailingAnchor),
            stack.topAnchor.constraint(equalTo: document.topAnchor), stack.bottomAnchor.constraint(equalTo: document.bottomAnchor),
        ])
    }

    private func moveSelection(by offset: Int) {
        let available = store.filteredTargets.filter(store.canLaunch)
        guard !available.isEmpty else { return }
        let current = available.firstIndex { $0.id == selectedID } ?? (offset > 0 ? -1 : available.count)
        selectedID = available[min(available.count - 1, max(0, current + offset))].id
        for row in rows { row.isSelectedRow = row.item.id == selectedID }
        if let row = rows.first(where: { $0.item.id == selectedID }) { row.scrollToVisible(row.bounds) }
    }

    /// The store explains refusals, such as a missing folder, in the footer.
    private func launch(_ item: LaunchTarget, in requested: OpenDestination? = nil) {
        guard store.launchingID == nil else { return }
        let destination = requested ?? self.destination
        Task { if await store.launch(item, in: destination) { onRequestClose?() } }
    }

    private func showState(symbol: String, title: String, detail: String, progress: Bool = false, actionTitle: String? = nil, action: Selector? = nil) {
        let icon = NSImageView(image: NSImage(systemSymbolName: symbol, accessibilityDescription: nil) ?? NSImage())
        icon.symbolConfiguration = .init(pointSize: 32, weight: .light)
        icon.contentTintColor = .secondaryLabelColor
        let heading = label(title, size: 16, weight: .semibold)
        let copy = NSTextField(wrappingLabelWithString: detail)
        copy.font = .systemFont(ofSize: 12)
        copy.textColor = .secondaryLabelColor
        copy.alignment = .center
        copy.maximumNumberOfLines = 4
        copy.widthAnchor.constraint(lessThanOrEqualToConstant: 340).isActive = true
        let stack = NSStackView(views: [icon, heading, copy])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        if progress {
            let spinner = NSProgressIndicator()
            spinner.style = .spinning
            spinner.controlSize = .small
            spinner.startAnimation(nil)
            stack.addArrangedSubview(spinner)
        } else if let actionTitle, let action {
            let button = NSButton(title: actionTitle, target: self, action: action)
            button.bezelStyle = .rounded
            stack.addArrangedSubview(button)
        }
        contentContainer.addSubview(stack)
        NSLayoutConstraint.activate([stack.centerXAnchor.constraint(equalTo: contentContainer.centerXAnchor), stack.centerYAnchor.constraint(equalTo: contentContainer.centerYAnchor), stack.widthAnchor.constraint(lessThanOrEqualTo: contentContainer.widthAnchor, constant: -24)])
    }

    /// A row's actions. Items are enabled explicitly: NSMenu's default
    /// auto-enabling would re-enable every item whose target responds.
    func actionsMenu(for item: LaunchTarget) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let idle = store.launchingID == nil
        for destination in [OpenDestination.chatGPT, .terminal] {
            let open = menuItem("Open in \(destination.label)", #selector(openFromMenu(_:)), symbol: destination.symbolName,
                LaunchRequest(item: item, destination: destination))
            open.isEnabled = idle && store.canLaunch(item)
            menu.addItem(open)
        }
        menu.addItem(.separator())
        guard let workspace = item.workspace else {
            menu.addItem(menuItem("Add workspace…", #selector(addWorkspaceForProfile(_:)), symbol: "folder.badge.plus", item.profile))
            menu.addItem(menuItem("Sign in to Codex CLI…", #selector(signInToCLI(_:)), symbol: "person.badge.key", item.profile))
            return menu
        }
        let changing = store.isChanging(item)
        menu.addItem(menuItem(store.isPinned(workspace) ? "Unpin workspace" : "Pin workspace", #selector(togglePin(_:)), symbol: "pin", workspace))
        let reveal = menuItem("Show in Finder", #selector(revealWorkspace(_:)), symbol: "folder", workspace)
        reveal.isEnabled = workspace.pathExists
        menu.addItem(reveal)
        menu.addItem(menuItem("Copy path", #selector(copyWorkspacePath(_:)), symbol: "doc.on.doc", workspace))
        let reassign = NSMenuItem(title: "Change profile", action: nil, keyEquivalent: "")
        reassign.image = NSImage(systemSymbolName: "person.2", accessibilityDescription: nil)
        let profiles = NSMenu()
        profiles.autoenablesItems = false
        for profile in store.profiles {
            let choice = menuItem(profile, #selector(reassignWorkspace(_:)), symbol: nil, [workspace.path, profile])
            choice.state = profile == workspace.profile ? .on : .off
            choice.isEnabled = workspace.pathExists && profile != workspace.profile && idle && !changing
            profiles.addItem(choice)
        }
        reassign.submenu = profiles
        reassign.isEnabled = !store.profiles.isEmpty
        menu.addItem(reassign)
        if !workspace.pathExists {
            let locate = menuItem("Locate moved folder…", #selector(locateWorkspace(_:)), symbol: "folder.badge.questionmark", workspace)
            locate.isEnabled = !changing
            menu.addItem(locate)
        }
        menu.addItem(.separator())
        let remove = menuItem("Remove workspace binding", #selector(removeWorkspace(_:)), symbol: "minus.circle", workspace)
        remove.isEnabled = idle && !changing
        menu.addItem(remove)
        return menu
    }

    func settingsMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(menuItem("New profile…", #selector(createProfile), symbol: nil, nil))
        let login = NSMenuItem(title: "Sign in to Codex CLI", action: nil, keyEquivalent: "")
        let profiles = NSMenu()
        for profile in store.profiles { profiles.addItem(menuItem(profile, #selector(signInToCLI(_:)), symbol: nil, profile)) }
        login.submenu = profiles
        login.isEnabled = !store.profiles.isEmpty
        menu.addItem(login)
        menu.addItem(.separator())
        let openAtLogin = menuItem("Open at Login", #selector(toggleOpenAtLogin), symbol: nil, nil)
        switch loginItem.status {
        case .enabled: openAtLogin.state = .on
        case .requiresApproval:
            openAtLogin.state = .mixed
            openAtLogin.toolTip = "Allow Codex Profiles in System Settings › General › Login Items"
        case .disabled: openAtLogin.state = .off
        }
        menu.addItem(openAtLogin)
        menu.addItem(.separator())
        menu.addItem(menuItem("About Codex Profiles", #selector(showAbout), symbol: nil, nil))
        let guardItem = NSMenuItem(title: "Workspace guard: \(store.guardMode)", action: nil, keyEquivalent: "")
        guardItem.isEnabled = false
        menu.addItem(guardItem)
        menu.addItem(.separator())
        let quit = menuItem("Quit Codex Profiles", #selector(quit), symbol: nil, nil)
        quit.keyEquivalent = "q"
        menu.addItem(quit)
        return menu
    }

    private func menuItem(_ title: String, _ action: Selector, symbol: String?, _ represented: Any?) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.representedObject = represented
        item.image = symbol.flatMap { NSImage(systemSymbolName: $0, accessibilityDescription: nil) }
        return item
    }

    @objc private func redrawSystemColours() {
        for row in rows {
            row.updateSystemColours()
            row.redrawUsageMeters()
        }
    }

    private func label(_ text: String, size: CGFloat, weight: NSFont.Weight) -> NSTextField {
        let value = NSTextField(labelWithString: text)
        value.font = .systemFont(ofSize: size, weight: weight)
        return value
    }

    private func configureSymbolButton(_ button: NSButton, symbol: String, title: String, action: Selector) {
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        button.isBordered = false
        button.target = self
        button.action = action
        button.toolTip = title
        button.setAccessibilityLabel(title)
        button.widthAnchor.constraint(equalToConstant: 28).isActive = true
        button.heightAnchor.constraint(equalToConstant: 28).isActive = true
    }

    private func symbolButton(_ symbol: String, title: String, action: Selector) -> NSButton {
        let button = NSButton()
        configureSymbolButton(button, symbol: symbol, title: title, action: action)
        return button
    }

    @objc private func launchClicked(_ sender: LaunchRowButton) { launch(sender.item) }
    @objc private func openFromMenu(_ sender: NSMenuItem) {
        guard let request = sender.representedObject as? LaunchRequest else { return }
        launch(request.item, in: request.destination)
    }
    @objc private func refresh() { Task { await store.refresh(); await store.refreshUsage(force: true) } }
    @objc private func clearSearch() { selectedID = nil; searchField.stringValue = ""; store.query = ""; focusSearch() }
    @objc private func resetFilters() { store.selectedProfile = nil; clearSearch() }
    @objc private func profileFilterChanged() { selectedID = nil; store.selectedProfile = profilePicker.indexOfSelectedItem == 0 ? nil : profilePicker.titleOfSelectedItem }
    @objc private func destinationChanged() {
        destination = destinationPicker.selectedSegment == 1 ? .terminal : .chatGPT
        defaults.set(destination.rawValue, forKey: "openDestination")
        render()
    }
    @objc private func togglePin(_ sender: NSMenuItem) { if let workspace = sender.representedObject as? WorkspaceBinding { store.togglePin(workspace) } }
    @objc private func revealWorkspace(_ sender: NSMenuItem) { if let workspace = sender.representedObject as? WorkspaceBinding { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: workspace.path)]) } }
    @objc private func copyWorkspacePath(_ sender: NSMenuItem) {
        guard let workspace = sender.representedObject as? WorkspaceBinding else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(workspace.path, forType: .string)
        store.showMessage("Copied workspace path")
    }
    @objc private func reassignWorkspace(_ sender: NSMenuItem) {
        guard let choice = sender.representedObject as? [String], choice.count == 2,
            let workspace = store.workspaces.first(where: { $0.path == choice[0] }) else { return }
        Task { await store.rebindWorkspace(workspace, to: choice[1]) }
    }
    @objc private func removeWorkspace(_ sender: NSMenuItem) {
        guard let workspace = sender.representedObject as? WorkspaceBinding else { return }
        Task { await store.unbindWorkspace(workspace) }
    }
    @objc private func locateWorkspace(_ sender: NSMenuItem) {
        guard let workspace = sender.representedObject as? WorkspaceBinding else { return }
        chooseFolder(for: workspace.profile, replacing: workspace)
    }
    @objc private func addWorkspace(_ sender: NSButton) {
        guard !store.profiles.isEmpty else { promptForProfile(addingWorkspace: true); return }
        if let profile = store.selectedProfile ?? (store.profiles.count == 1 ? store.profiles.first : nil) { chooseFolder(for: profile); return }
        let menu = NSMenu(title: "Choose profile")
        for profile in store.profiles {
            let item = NSMenuItem(title: profile, action: #selector(profileChosen(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = profile
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let create = NSMenuItem(title: "New profile…", action: #selector(createProfileForWorkspace), keyEquivalent: "")
        create.target = self
        menu.addItem(create)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height), in: sender)
    }
    @objc private func profileChosen(_ sender: NSMenuItem) { if let profile = sender.representedObject as? String { chooseFolder(for: profile) } }
    @objc private func addWorkspaceForProfile(_ sender: NSMenuItem) { if let profile = sender.representedObject as? String { chooseFolder(for: profile) } }

    private func chooseFolder(for profile: String, replacing: WorkspaceBinding? = nil) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = replacing == nil ? "Add workspace" : "Use this folder"
        panel.message = "Choose a project folder for the \(profile) profile."
        onRequestClose?()
        panel.begin { [weak self] response in
            guard response == .OK, let path = panel.url?.path else { return }
            Task {
                guard let self else { return }
                if let replacing { await self.store.relocateWorkspace(replacing, to: path) }
                else { await self.store.bindWorkspace(path: path, profile: profile) }
            }
        }
    }

    @objc private func showSettingsMenu(_ sender: NSButton) {
        settingsMenu().popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height), in: sender)
    }
    @objc private func showAbout() { onRequestClose?(); NSApp.orderFrontStandardAboutPanel(nil) }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func toggleOpenAtLogin() {
        do {
            switch loginItem.status {
            case .enabled:
                try loginItem.unregister()
                store.showMessage("Codex Profiles won’t open at login")
            case .requiresApproval:
                loginItem.openSystemSettings()
                store.showMessage("Allow Codex Profiles in Login Items")
            case .disabled:
                try loginItem.register()
                if loginItem.status == .requiresApproval {
                    loginItem.openSystemSettings()
                    store.showMessage("Allow Codex Profiles in Login Items")
                } else {
                    store.showMessage("Codex Profiles will open at login")
                }
            }
        } catch {
            presentError("Couldn’t change Open at Login: \(error.localizedDescription)")
        }
    }

    @objc private func createProfile() { promptForProfile(addingWorkspace: false) }
    @objc private func createProfileForWorkspace() { promptForProfile(addingWorkspace: true) }

    private func promptForProfile(addingWorkspace: Bool) {
        let alert = NSAlert()
        alert.messageText = "Create a profile"
        alert.informativeText = "Choose a name such as work, personal or client. Sign into ChatGPT when you open its window."
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        field.placeholderString = "Profile name"
        field.setAccessibilityLabel("New profile name")
        alert.accessoryView = field
        alert.addButton(withTitle: "Create profile")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard CLIClient.isValidProfileName(name) else {
            presentError(CLIClientError.invalidProfileName.localizedDescription)
            return
        }
        Task {
            if await store.createProfile(name) {
                clearSearch()
                store.selectedProfile = name
                if addingWorkspace { chooseFolder(for: name) }
                await store.refreshUsage()
            }
        }
    }

    @objc private func signInToCLI(_ sender: NSMenuItem) {
        guard let profile = sender.representedObject as? String else { return }
        Task { await store.signInToCLI(profile) }
    }

    private func presentError(_ message: String) {
        // Schedule outside render and menu tracking so the alert gets keyboard focus.
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Codex Profiles couldn’t complete the action"
            alert.informativeText = message
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}

final class FlippedView: NSView { override var isFlipped: Bool { true } }

final class LaunchRowButton: NSButton {
    let item: LaunchTarget
    var onShowActions: ((NSButton) -> Void)?
    var isSelectedRow: Bool { didSet { setAccessibilitySelected(isSelectedRow); needsDisplay = true } }
    private var isHovered = false
    private var tracking: NSTrackingArea?
    private let destination: OpenDestination
    private let metadata: NSTextField
    private let profileDetail: String
    private let usageView: ProfileUsageView?

    init(item: LaunchTarget, shortcutIndex: Int, destination: OpenDestination, usage: UsageState?, pinned: Bool, selected: Bool,
         launching: Bool, changing: Bool, enabled: Bool, target: AnyObject?, action: Selector?) {
        self.item = item
        self.destination = destination
        isSelectedRow = selected
        profileDetail = destination == .terminal ? "Codex CLI profile" : item.profile == "default" ? "Standard ChatGPT window" : "Separate ChatGPT window"
        metadata = NSTextField(labelWithString: item.workspace.map { "\($0.profile) · \($0.displayPath())" } ?? profileDetail)
        usageView = item.workspace == nil ? ProfileUsageView(usage: usage ?? UsageState()) : nil
        super.init(frame: .zero)
        self.target = target
        self.action = action
        title = ""
        isBordered = false
        wantsLayer = true
        focusRingType = .none
        isEnabled = enabled
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: item.workspace == nil ? 44 : item.isAvailable ? 56 : 72).isActive = true
        let state = changing ? "Updating" : "Open in \(destination.label)"
        setAccessibilityLabel(item.workspace.map { "\($0.name), profile \($0.profile), \($0.path). \($0.availabilityReason ?? state)" }
            ?? "Profile \(item.profile). \(state)")
        setAccessibilitySelected(selected)
        toolTip = item.workspace.map { "\($0.path)\nProfile: \($0.profile)" } ?? "Open profile \(item.profile) without a project folder"
        let icon = NSImageView(image: NSImage(systemSymbolName: item.workspace == nil ? "person.crop.circle" : pinned ? "pin.fill" : "folder", accessibilityDescription: nil) ?? NSImage())
        icon.symbolConfiguration = .init(pointSize: 18, weight: .regular)
        icon.contentTintColor = .secondaryLabelColor
        icon.widthAnchor.constraint(equalToConstant: 22).isActive = true
        let name = NSTextField(labelWithString: item.name)
        name.font = .systemFont(ofSize: 13, weight: .semibold)
        name.lineBreakMode = .byTruncatingTail
        name.toolTip = item.name
        name.textColor = item.isAvailable ? .labelColor : .secondaryLabelColor
        metadata.font = .systemFont(ofSize: 11)
        metadata.textColor = .secondaryLabelColor
        // Paths keep both ends readable; prose keeps its beginning.
        metadata.lineBreakMode = item.workspace == nil ? .byTruncatingTail : .byTruncatingMiddle
        if let workspace = item.workspace {
            let metadataText = NSMutableAttributedString(attributedString: metadata.attributedStringValue)
            metadataText.addAttribute(.font, value: NSFont.systemFont(ofSize: 11, weight: .medium),
                range: NSRange(location: 0, length: (workspace.profile as NSString).length))
            metadata.attributedStringValue = metadataText
        }
        metadata.toolTip = toolTip
        let labels = NSStackView(views: [name, metadata])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 3
        for value in [name, metadata] {
            value.widthAnchor.constraint(equalTo: labels.widthAnchor).isActive = true
            value.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }
        labels.setContentHuggingPriority(.defaultLow, for: .horizontal)
        labels.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        if let reason = item.workspace?.availabilityReason {
            let warning = NSTextField(labelWithString: reason)
            warning.font = .systemFont(ofSize: 10)
            warning.textColor = .secondaryLabelColor
            warning.lineBreakMode = .byTruncatingTail
            labels.addArrangedSubview(warning)
            warning.widthAnchor.constraint(equalTo: labels.widthAnchor).isActive = true
            warning.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }
        let openTitle = launching ? "Opening…" : changing ? "Updating…" : "Open"
        let open = NSButton(title: openTitle, target: self, action: #selector(openTarget(_:)))
        open.bezelStyle = .rounded
        open.controlSize = .small
        open.font = .systemFont(ofSize: 11)
        open.contentTintColor = .labelColor
        open.isEnabled = enabled
        open.widthAnchor.constraint(equalToConstant: openTitle == "Open" ? 56 : 78).isActive = true
        open.toolTip = "Open in \(destination.label)" + (shortcutIndex < 9 ? " (⌘\(shortcutIndex + 1))" : "")
        open.setAccessibilityLabel("Open \(item.name) in \(destination.label)")
        let more = NSButton(image: NSImage(systemSymbolName: "ellipsis", accessibilityDescription: "Actions for \(item.name)") ?? NSImage(), target: self, action: #selector(showActions(_:)))
        more.isBordered = false
        more.contentTintColor = .secondaryLabelColor
        more.toolTip = item.workspace == nil ? "Open elsewhere, add a workspace, or sign in to Codex CLI" : "Open elsewhere, pin, change profile, or remove binding"
        more.isEnabled = !changing
        more.widthAnchor.constraint(equalToConstant: 22).isActive = true
        more.heightAnchor.constraint(equalToConstant: 24).isActive = true
        var rowViews: [NSView] = [icon, labels]
        if let usageView { rowViews.append(usageView) }
        rowViews += [open, more]
        let row = NSStackView(views: rowViews)
        row.orientation = .horizontal
        row.alignment = .centerY
        row.distribution = .fill
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14), row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            row.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        if item.workspace == nil { update(usage: usage ?? UsageState()) }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Shows a newer usage reading without rebuilding the row.
    func update(usage: UsageState, now: Date = Date()) {
        guard let usageView else { return }
        usageView.update(usage, now: now)
        let detail = usage.detail(at: now)
        toolTip = "Open profile \(item.profile) without a project folder\n\(detail)"
        metadata.toolTip = toolTip
        // A low quota matters more than the destination description.
        metadata.stringValue = usage.summary(at: now) ?? profileDetail
        setAccessibilityLabel("Profile \(item.profile). Open in \(destination.label). \(detail)")
    }

    override var wantsUpdateLayer: Bool { true }
    override func updateLayer() { updateSystemColours() }

    func updateSystemColours(
        reduceTransparency: Bool = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency,
        increaseContrast: Bool = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
    ) {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            let solid = reduceTransparency || increaseContrast
            let fill: NSColor = isSelectedRow ? (solid ? .unemphasizedSelectedContentBackgroundColor : .controlAccentColor.withAlphaComponent(0.14))
                : isHovered && isEnabled ? (solid ? .unemphasizedSelectedContentBackgroundColor : .quaternaryLabelColor.withAlphaComponent(0.08)) : .clear
            layer?.backgroundColor = fill.cgColor
            // Shape identifies keyboard selection even without colour cues.
            layer?.borderWidth = isSelectedRow ? 1 : 0
            layer?.borderColor = NSColor.labelColor.cgColor
        }
    }

    func redrawUsageMeters() { usageView?.redrawMeters() }
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); needsDisplay = true }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        tracking = NSTrackingArea(rect: bounds, options: [.activeInKeyWindow, .mouseEnteredAndExited, .inVisibleRect], owner: self)
        addTrackingArea(tracking!)
    }
    override func mouseEntered(with event: NSEvent) { isHovered = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent) { isHovered = false; needsDisplay = true }
    @objc private func openTarget(_ sender: NSButton) { performClick(nil) }
    @objc private func showActions(_ sender: NSButton) { onShowActions?(sender) }
}

final class ProfileUsageView: NSStackView {
    static let columnWidth: CGFloat = 100

    init(usage: UsageState, now: Date = Date()) {
        super.init(frame: .zero)
        orientation = .vertical
        alignment = .width
        spacing = 4
        widthAnchor.constraint(equalToConstant: Self.columnWidth).isActive = true
        setContentCompressionResistancePriority(.required, for: .horizontal)
        setAccessibilityLabel("Codex quota remaining")
        update(usage, now: now)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Replaces the readings in place. A refresh dims the previous reading
    /// rather than hiding it; expired windows show a dash, never restored quota.
    func update(_ usage: UsageState, now: Date = Date()) {
        arrangedSubviews.forEach { $0.removeFromSuperview() }
        toolTip = usage.detail(at: now)
        setAccessibilityValue(toolTip)
        guard let limits = usage.limits else {
            let checking = usage.reading == nil || usage.isRefreshing
            let message = NSTextField(labelWithString: checking ? "Checking…" : "Unavailable")
            message.font = .systemFont(ofSize: 10)
            message.textColor = .secondaryLabelColor
            message.alignment = .right
            addArrangedSubview(message)
            message.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
            return
        }
        for (index, window) in limits.windows.enumerated() {
            let expired = window.hasReset(at: now)
            let duration = NSTextField(labelWithString: window.durationLabel ?? "Limit \(index + 1)")
            duration.font = .systemFont(ofSize: 10)
            duration.textColor = .secondaryLabelColor
            duration.alignment = .right
            duration.lineBreakMode = .byTruncatingTail
            duration.setContentHuggingPriority(.defaultLow, for: .horizontal)
            duration.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            let meter = QuotaMeter()
            meter.fraction = expired ? 0 : CGFloat(window.remainingPercent) / 100
            meter.level = expired ? .normal : window.level
            let remaining = NSTextField(labelWithString: expired ? "—" : "\(window.remainingPercent)%")
            remaining.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
            remaining.textColor = expired ? .secondaryLabelColor : window.level == .critical ? .systemRed : .labelColor
            remaining.alignment = .right
            remaining.widthAnchor.constraint(equalToConstant: 30).isActive = true
            let line = NSStackView(views: [duration, meter, remaining])
            line.distribution = .fill
            line.alignment = .centerY
            line.spacing = 4
            line.alphaValue = usage.isRefreshing ? 0.45 : 1
            addArrangedSubview(line)
            line.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
        }
    }

    func redrawMeters() {
        for line in arrangedSubviews { for case let meter as QuotaMeter in line.subviews { meter.needsDisplay = true } }
    }
}

/// A thin capacity bar beside each quota percentage. The number carries the
/// value; low and critical colours only add emphasis.
final class QuotaMeter: NSView {
    var fraction: CGFloat = 0 { didSet { needsDisplay = true } }
    var level: QuotaLevel = .normal { didSet { needsDisplay = true } }
    private let fill = CALayer()

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        fill.actions = ["bounds": NSNull(), "position": NSNull(), "backgroundColor": NSNull(), "cornerRadius": NSNull()]
        layer?.addSublayer(fill)
        setAccessibilityElement(false)
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 32).isActive = true
        heightAnchor.constraint(equalToConstant: 4).isActive = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var wantsUpdateLayer: Bool { true }
    override func layout() { super.layout(); needsDisplay = true }
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); needsDisplay = true }

    override func updateLayer() {
        guard let layer else { return }
        let contrast = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer.backgroundColor = (contrast ? NSColor.tertiaryLabelColor : .quaternaryLabelColor).cgColor
            let colour: NSColor = switch level {
            case .critical: .systemRed
            case .low: .systemOrange
            case .normal: contrast ? .labelColor : .secondaryLabelColor
            }
            fill.backgroundColor = colour.cgColor
        }
        let radius = bounds.height / 2
        layer.cornerRadius = radius
        fill.cornerRadius = radius
        // Keep any remaining quota visible as at least a dot.
        let width = fraction > 0 ? max(bounds.height, bounds.width * min(1, fraction)) : 0
        fill.frame = CGRect(x: 0, y: 0, width: width, height: bounds.height)
    }
}
