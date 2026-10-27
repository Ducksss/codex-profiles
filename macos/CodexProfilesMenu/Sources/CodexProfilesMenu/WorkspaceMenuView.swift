import AppKit

@MainActor
final class WorkspaceMenuViewController: NSViewController {
    static let width: CGFloat = 360
    private static let headerHeight: CGFloat = 44
    private static let footerHeight: CGFloat = 36

    /// Everything that shapes the list except live usage. Usage updates rows in
    /// place, so streaming readings keep hover, focus and the VoiceOver cursor.
    private struct ListModel: Equatable {
        struct Row: Equatable {
            let item: LaunchTarget
            let pinned: Bool
            /// Listed under its own profile's row, so it needs no profile name.
            let nested: Bool
            /// The colour and symbol of the row's profile.
            let appearance: ProfileAppearance
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
    private let alerts: QuotaAlertController?
    private let searchField = NSSearchField()
    private let titleLabel = NSTextField(labelWithString: "Codex Profiles")
    private let contentContainer = NSView()
    private let footerLabel = NSTextField(labelWithString: "")
    private let refreshButton = NSButton()
    private let addButton = NSButton()
    private var rows: [LaunchRowButton] = []
    private var scrollView: NSScrollView?
    private var selectedID: LaunchTarget.ID?
    private var heightConstraint: NSLayoutConstraint?
    private var headerLeadingConstraint: NSLayoutConstraint?
    private var destination: OpenDestination
    private var renderedList: ListModel?
    /// The profile whose colour and symbol are being chosen, in place of the list.
    private var editingProfile: String?
    private var appearanceEditor: AppearanceEditorView?
    var onPreferredContentSizeChange: ((NSSize) -> Void)?
    var onRequestClose: (() -> Void)?

    init(store: WorkspaceStore, defaults: UserDefaults = .standard, loginItem: LoginItemControlling? = nil,
         alerts: QuotaAlertController? = nil) {
        self.store = store
        self.defaults = defaults
        self.loginItem = loginItem ?? MainAppLoginItem()
        self.alerts = alerts
        destination = defaults.string(forKey: "openDestination") == OpenDestination.terminal.rawValue ? .terminal : .chatGPT
        super.init(nibName: nil, bundle: nil)
        preferredContentSize = NSSize(width: Self.width, height: 260)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() {
        let surface = NSView()
        surface.translatesAutoresizingMaskIntoConstraints = false
        view = surface
        heightConstraint = surface.heightAnchor.constraint(equalToConstant: 260)
        NSLayoutConstraint.activate([surface.widthAnchor.constraint(equalToConstant: Self.width), heightConstraint!])
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

    /// Opening starts unselected; a search left over from last time selects
    /// its first match, so Return's target is visible.
    func focusSearch() {
        selectedID = nil
        selectFirstMatch(in: store.filteredTargets)
        updateSelection()
        view.window?.makeKey()
        if !searchField.isHidden { view.window?.makeFirstResponder(searchField) }
    }

    func handleShortcut(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.numericPad, .function])
        // The appearance editor keeps native control handling; Escape returns to the list.
        if editingProfile != nil {
            guard modifiers.isEmpty, event.keyCode == 53 else { return false }
            closeAppearanceEditor()
            return true
        }
        let responder = view.window?.firstResponder
        let navigatingList = responder === searchField || responder === searchField.currentEditor() || responder is LaunchRowButton
        let isReturn = [36, 76].contains(event.keyCode)
        if modifiers.isEmpty {
            if [125, 126, 36, 76].contains(event.keyCode), !navigatingList { return false }
            switch event.keyCode {
            case 125: moveSelection(by: 1); return true
            case 126: moveSelection(by: -1); return true
            case 36, 76: launchSelection(alternate: false); return true
            case 53:
                if !store.query.isEmpty { clearSearch() } else { onRequestClose?() }
                return true
            default: return false
            }
        }
        guard modifiers == .command else { return false }
        // Command-Return opens the selection in the other destination.
        if isReturn {
            guard navigatingList else { return false }
            launchSelection(alternate: true)
            return true
        }
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
        searchField.placeholderString = "Search profiles and workspaces"
        searchField.font = .systemFont(ofSize: 13)
        searchField.target = self
        searchField.action = #selector(searchChanged)
        searchField.sendsSearchStringImmediately = true
        searchField.stringValue = store.query
        searchField.toolTip = "Search profiles, workspaces and folder paths (⌘K)"
        searchField.setAccessibilityLabel("Search profile and workspace names or folder paths")
        searchField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        // The title stands in for search until there is something to search.
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let settings = symbolButton("gearshape", title: "Options", action: #selector(showSettingsMenu(_:)))
        let header = NSStackView(views: [searchField, titleLabel, settings])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.distribution = .fill
        header.spacing = 6
        header.translatesAutoresizingMaskIntoConstraints = false
        searchField.heightAnchor.constraint(equalToConstant: 28).isActive = true
        let listDivider = NSBox()
        listDivider.boxType = .separator
        listDivider.translatesAutoresizingMaskIntoConstraints = false

        let divider = NSBox()
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        configureSymbolButton(addButton, symbol: "plus", title: "Add a workspace", action: #selector(addWorkspace(_:)))
        footerLabel.font = .systemFont(ofSize: 11)
        footerLabel.textColor = .secondaryLabelColor
        footerLabel.lineBreakMode = .byTruncatingTail
        footerLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        footerLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        configureSymbolButton(refreshButton, symbol: "arrow.clockwise", title: "Refresh profiles, workspaces and Codex usage (⌘R)", action: #selector(refresh))
        let footer = NSStackView(views: [footerLabel, addButton, refreshButton])
        footer.orientation = .horizontal
        footer.alignment = .centerY
        footer.distribution = .fill
        footer.spacing = 2
        footer.setCustomSpacing(8, after: footerLabel)
        footer.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        // Search and options form one line above a single rule, so scrolled
        // rows pass under a clear edge.
        [header, listDivider, contentContainer, divider, footer].forEach { view.addSubview($0) }
        headerLeadingConstraint = header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.topAnchor),
            headerLeadingConstraint!,
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            header.heightAnchor.constraint(equalToConstant: Self.headerHeight),
            listDivider.topAnchor.constraint(equalTo: header.bottomAnchor),
            listDivider.leadingAnchor.constraint(equalTo: view.leadingAnchor), listDivider.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentContainer.topAnchor.constraint(equalTo: listDivider.bottomAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: divider.topAnchor),
            divider.leadingAnchor.constraint(equalTo: view.leadingAnchor), divider.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            divider.bottomAnchor.constraint(equalTo: footer.topAnchor),
            footer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: LaunchRowButton.contentInset),
            footer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            footer.bottomAnchor.constraint(equalTo: view.bottomAnchor), footer.heightAnchor.constraint(equalToConstant: Self.footerHeight),
        ])
    }

    private func render() {
        let targets = store.filteredTargets
        let populated = store.phase == .ready && (!store.profiles.isEmpty || !store.workspaces.isEmpty)
        if let profile = editingProfile, !populated || !store.profiles.contains(profile) { editingProfile = nil }
        let editing = editingProfile != nil
        let shouldFocusSearch = populated && !editing && searchField.isHidden
        searchField.isHidden = !populated || editing
        titleLabel.isHidden = populated && !editing
        titleLabel.stringValue = editing ? "Appearance" : "Codex Profiles"
        // The search field's bezel sits slightly outside the text column; the title sits on it.
        headerLeadingConstraint?.constant = populated && !editing ? 10 : LaunchRowButton.contentInset
        addButton.isHidden = !populated || store.profiles.isEmpty || editing
        addButton.toolTip = store.profiles.count == 1 ? "Add a workspace" : "Add a workspace or profile"
        refreshButton.isEnabled = !store.isRefreshing && !store.isRefreshingUsage
        selectedID = targets.first { $0.id == selectedID && store.canLaunch($0) }?.id
        selectFirstMatch(in: targets)
        if let profile = editingProfile {
            showAppearanceEditor(for: profile)
            return
        }
        if appearanceEditor != nil {
            appearanceEditor = nil
            renderedList = nil
        }

        let list = store.phase == .ready && !targets.isEmpty ? listModel(for: targets) : nil
        if let list, list == renderedList, scrollView != nil {
            for row in rows {
                row.isSelectedRow = row.item.id == selectedID
                if row.item.workspace == nil { row.update(usage: store.usageState(for: row.item.profile)) }
            }
            updateFooter()
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
            showState(symbol: "magnifyingglass", title: "No matches", detail: "Try another profile or project name.", actionTitle: "Clear search", action: #selector(clearSearch))
        case .ready:
            if let list { showLaunchList(list) }
        }
        // A list fits its rows up to 500 points; a message keeps room to breathe.
        if let document = scrollView?.documentView {
            resize(toFit: document.fittingSize.height)
        } else {
            resize(toFit: (contentContainer.subviews.first.map { $0.fittingSize.height + 48 } ?? 100), minimum: 260)
        }
        updateFooter()
        if shouldFocusSearch, view.window?.isKeyWindow == true { focusSearch() }
        if let scrollView {
            let maxY = max(0, (scrollView.documentView?.bounds.height ?? 0) - scrollView.contentView.bounds.height)
            scrollView.contentView.scroll(to: NSPoint(x: 0, y: min(scrollPosition.y, maxY)))
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
    }

    private func resize(toFit contentHeight: CGFloat, minimum: CGFloat = 0) {
        let height = min(500, max(minimum, Self.headerHeight + Self.footerHeight + 2 + contentHeight))
        heightConstraint?.constant = height
        preferredContentSize = NSSize(width: Self.width, height: height)
        onPreferredContentSizeChange?(preferredContentSize)
        view.layoutSubtreeIfNeeded()
    }

    /// Shows the editor in place of the list. Later readings update it in
    /// place, so keyboard focus stays on the chosen control.
    private func showAppearanceEditor(for profile: String) {
        let appearance = store.appearance(for: profile)
        if let appearanceEditor, appearanceEditor.profile == profile {
            appearanceEditor.update(appearance)
        } else {
            contentContainer.subviews.forEach { $0.removeFromSuperview() }
            rows.removeAll()
            scrollView = nil
            renderedList = nil
            let editor = AppearanceEditorView(profile: profile, appearance: appearance)
            editor.onChoose = { [weak self] choice in self?.store.setAppearance(choice, for: profile) }
            editor.onReset = { [weak self] in self?.store.setAppearance(nil, for: profile) }
            editor.onDone = { [weak self] in self?.closeAppearanceEditor() }
            editor.translatesAutoresizingMaskIntoConstraints = false
            contentContainer.addSubview(editor)
            NSLayoutConstraint.activate([
                editor.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
                editor.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
                editor.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            ])
            appearanceEditor = editor
            resize(toFit: editor.fittingSize.height)
        }
        updateFooter()
    }

    /// Replaces the list with the profile's colour and symbol choices.
    func editAppearance(of profile: String) {
        editingProfile = profile
        render()
    }

    private func closeAppearanceEditor() {
        editingProfile = nil
        render()
        focusSearch()
    }

    private func listModel(for targets: [LaunchTarget]) -> ListModel {
        let listedProfiles = Set(targets.filter { $0.workspace == nil }.map(\.profile))
        return ListModel(destination: destination, rows: targets.map { item in
            ListModel.Row(
                item: item,
                pinned: item.workspace.map(store.isPinned) ?? false,
                nested: item.workspace.map { listedProfiles.contains($0.profile) } ?? false,
                appearance: store.appearance(for: item.profile),
                launching: store.launchingID == item.id,
                changing: store.isChanging(item),
                enabled: store.canLaunch(item) && store.launchingID == nil
            )
        })
    }

    private var isSearching: Bool { !store.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// While searching, the first available match is selected so Return's
    /// target is visible before it is pressed.
    private func selectFirstMatch(in targets: [LaunchTarget]) {
        guard selectedID == nil, isSearching else { return }
        selectedID = targets.first(where: store.canLaunch)?.id
    }

    private func updateSelection() {
        for row in rows { row.isSelectedRow = row.item.id == selectedID }
        updateFooter()
    }

    /// The footer says what Return and Command-Return do until the store has
    /// news to report, such as a launch or a refresh failure.
    private func updateFooter() {
        let other = "⌘↩ \(destination.alternate.label)"
        if editingProfile != nil {
            footerLabel.stringValue = "Changes apply at once  ·  Esc returns"
        } else if store.hasStatusNews {
            footerLabel.stringValue = store.statusMessage
        } else if let item = rows.first(where: { $0.item.id == selectedID })?.item {
            footerLabel.stringValue = "↩ Open \(item.name) in \(destination.label)  ·  \(other)"
        } else if !rows.isEmpty {
            footerLabel.stringValue = "↩ Open in \(destination.label)  ·  \(other)"
        } else {
            footerLabel.stringValue = ""
        }
        footerLabel.toolTip = footerLabel.stringValue
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
        stack.edgeInsets = NSEdgeInsets(top: 6, left: 0, bottom: 6, right: 0)
        stack.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(stack)
        // A profile and the workspaces nested under it form one group; search
        // results without their profile row form another.
        func group(of row: ListModel.Row) -> String? {
            row.item.workspace == nil || row.nested ? row.item.profile : nil
        }
        for (index, model) in list.rows.enumerated() {
            let item = model.item
            if index > 0, group(of: model) != group(of: list.rows[index - 1]) {
                let divider = GroupDivider()
                stack.addArrangedSubview(divider)
                divider.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            }
            let row = LaunchRowButton(item: item, appearance: model.appearance, destination: list.destination,
                usage: item.workspace == nil ? store.usageState(for: item.profile) : nil, pinned: model.pinned, nested: model.nested,
                selected: selectedID == item.id, launching: model.launching, changing: model.changing,
                enabled: model.enabled, target: self, action: #selector(launchClicked(_:)))
            row.onShowActions = { [weak self] sender in
                guard let self else { return }
                self.actionsMenu(for: item).popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height), in: sender)
            }
            row.contextMenu = { [weak self] in self?.actionsMenu(for: item) }
            row.onLocate = { [weak self] in
                if let workspace = item.workspace { self?.chooseFolder(for: workspace.profile, replacing: workspace) }
            }
            rows.append(row)
            stack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
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
        updateSelection()
        if let row = rows.first(where: { $0.item.id == selectedID }) { row.scrollToVisible(row.bounds) }
    }

    /// Return opens the selection, or the first available row without one.
    private func launchSelection(alternate: Bool) {
        let targets = store.filteredTargets
        guard let item = targets.first(where: { $0.id == selectedID }) ?? targets.first(where: store.canLaunch) else { return }
        launch(item, in: alternate ? destination.alternate : nil)
    }

    /// The store explains refusals, such as a missing folder, in the footer.
    private func launch(_ item: LaunchTarget, in requested: OpenDestination? = nil) {
        guard store.launchingID == nil else { return }
        let destination = requested ?? self.destination
        Task { if await store.launch(item, in: destination) { onRequestClose?() } }
    }

    private func showState(symbol: String, title: String, detail: String, progress: Bool = false, actionTitle: String? = nil, action: Selector? = nil) {
        let icon = NSImageView(image: NSImage(systemSymbolName: symbol, accessibilityDescription: nil) ?? NSImage())
        icon.symbolConfiguration = .init(pointSize: 28, weight: .light)
        icon.contentTintColor = .secondaryLabelColor
        let heading = label(title, size: 15, weight: .semibold)
        let copy = NSTextField(wrappingLabelWithString: detail)
        copy.font = .systemFont(ofSize: 12)
        copy.textColor = .secondaryLabelColor
        copy.alignment = .center
        copy.maximumNumberOfLines = 4
        copy.widthAnchor.constraint(lessThanOrEqualToConstant: 280).isActive = true
        let stack = NSStackView(views: [icon, heading, copy])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 6
        stack.setCustomSpacing(12, after: icon)
        stack.setCustomSpacing(16, after: copy)
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
        if item.workspace == nil {
            for line in usageItems(for: store.usageState(for: item.profile)) { menu.addItem(line) }
            menu.addItem(.separator())
        }
        for destination in [OpenDestination.chatGPT, .terminal] {
            let open = menuItem("Open in \(destination.label)", #selector(openFromMenu(_:)), symbol: destination.symbolName,
                LaunchRequest(item: item, destination: destination))
            open.isEnabled = idle && store.canLaunch(item)
            menu.addItem(open)
        }
        menu.addItem(.separator())
        guard let workspace = item.workspace else {
            menu.addItem(menuItem("Add workspace…", #selector(addWorkspaceForProfile(_:)), symbol: "folder.badge.plus", item.profile))
            menu.addItem(menuItem("Appearance…", #selector(editAppearance(_:)), symbol: "paintpalette", item.profile))
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

    /// Every window with its reset time, which the row's single figure leaves
    /// out. The lines are information, so they stay disabled.
    private func usageItems(for usage: UsageState, now: Date = Date()) -> [NSMenuItem] {
        var lines = ["Codex CLI usage"]
        if case let .available(limits, checkedAt) = usage.reading {
            lines += limits.windows.enumerated().map { index, window in
                let name = window.durationLabel ?? "Limit \(index + 1)"
                guard !window.hasReset(at: now) else { return "\(name): awaiting a fresh reading" }
                let reset = window.resetsAt.map { " · resets \(UsageFormat.clock(Date(timeIntervalSince1970: $0), relativeTo: now))" } ?? ""
                return "\(name): \(window.remainingPercent)% left\(reset)"
            }
            lines.append((usage.isRefreshing ? "Refreshing… " : "") + "Checked \(UsageFormat.clock(checkedAt, relativeTo: now))")
        } else if usage.reading == nil || usage.isRefreshing {
            lines.append("Checking…")
        } else {
            lines.append("Unavailable · sign in to Codex CLI, then refresh")
        }
        return lines.map { line in
            let item = NSMenuItem(title: line, action: nil, keyEquivalent: "")
            item.isEnabled = false
            return item
        }
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
        // Command-Return and Command-click open the other one.
        let returnOpens = NSMenuItem(title: "Return opens in", action: nil, keyEquivalent: "")
        let destinations = NSMenu()
        destinations.autoenablesItems = false
        for choice in [OpenDestination.chatGPT, .terminal] {
            let option = menuItem(choice.label, #selector(destinationChosen(_:)), symbol: nil, choice.rawValue)
            option.state = choice == destination ? .on : .off
            destinations.addItem(option)
        }
        returnOpens.submenu = destinations
        menu.addItem(returnOpens)
        let openAtLogin = menuItem("Open at Login", #selector(toggleOpenAtLogin), symbol: nil, nil)
        switch loginItem.status {
        case .enabled: openAtLogin.state = .on
        case .requiresApproval:
            openAtLogin.state = .mixed
            openAtLogin.toolTip = "Allow Codex Profiles in System Settings › General › Login Items"
        case .disabled: openAtLogin.state = .off
        }
        menu.addItem(openAtLogin)
        if let alerts {
            let lowQuota = menuItem("Low-quota alerts", #selector(toggleLowQuotaAlerts), symbol: nil, nil)
            if alerts.isBlocked {
                lowQuota.state = .mixed
                lowQuota.toolTip = "Notifications are not allowed. Allow Codex Profiles in System Settings › Notifications, or choose this to turn alerts off; turning them on again asks macOS."
            } else {
                lowQuota.state = alerts.isEnabled ? .on : .off
                lowQuota.toolTip = "Notify when a profile’s Codex quota falls to 25%, and again at 10%. Checks usage every 5 minutes; never switches profiles."
            }
            lowQuota.isEnabled = !alerts.isChanging
            menu.addItem(lowQuota)
            let figure = menuItem("Quota in menu bar", #selector(toggleMenuBarFigure), symbol: nil, nil)
            figure.state = alerts.showsFigure ? .on : .off
            figure.toolTip = "Show the lowest remaining Codex quota beside the icon. Checks usage every 5 minutes while on; never switches profiles."
            menu.addItem(figure)
        }
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
            row.redrawAvatar()
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
        button.contentTintColor = .secondaryLabelColor
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

    /// Clicking opens in the default destination; Command-click opens in the other.
    @objc private func launchClicked(_ sender: LaunchRowButton) {
        let alternate = NSApp.currentEvent?.modifierFlags.contains(.command) == true
        launch(sender.item, in: alternate ? destination.alternate : nil)
    }
    @objc private func openFromMenu(_ sender: NSMenuItem) {
        guard let request = sender.representedObject as? LaunchRequest else { return }
        launch(request.item, in: request.destination)
    }
    @objc private func refresh() { Task { await store.refresh(); await store.refreshUsage(force: true) } }
    @objc private func clearSearch() { selectedID = nil; searchField.stringValue = ""; store.query = ""; focusSearch() }
    @objc private func destinationChosen(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? String, let choice = OpenDestination(rawValue: value) else { return }
        destination = choice
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
        if store.profiles.count == 1, let profile = store.profiles.first { chooseFolder(for: profile); return }
        let menu = NSMenu(title: "Choose profile")
        let heading = NSMenuItem(title: "Add a workspace for", action: nil, keyEquivalent: "")
        heading.isEnabled = false
        menu.addItem(heading)
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
    @objc private func editAppearance(_ sender: NSMenuItem) {
        if let profile = sender.representedObject as? String { editAppearance(of: profile) }
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

    @objc private func toggleLowQuotaAlerts() {
        guard let alerts else { return }
        Task {
            switch await alerts.setEnabled(!alerts.isEnabled) {
            case .enabled: store.showMessage("Low-quota alerts on · usage checked every 5 minutes")
            case .disabled: store.showMessage("Low-quota alerts off")
            case .denied:
                store.showMessage("Notifications are off for Codex Profiles")
                presentError(QuotaAlertController.permissionDeniedMessage)
            case .busy: break
            }
        }
    }

    @objc private func toggleMenuBarFigure() {
        guard let alerts else { return }
        alerts.setShowsFigure(!alerts.showsFigure)
        store.showMessage(alerts.showsFigure ? "Lowest quota shown in the menu bar · checked every 5 minutes" : "Quota hidden from the menu bar")
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

/// One launchable row. A profile row is 46 points with its quota beside the
/// name; a workspace is a single 30-point line nested under its profile, and
/// grows to two lines only to explain why it cannot open.
final class LaunchRowButton: NSButton {
    /// Column metrics shared with the header, dividers and nested workspaces.
    static let contentInset: CGFloat = 14
    static let avatarSize: CGFloat = 26
    static let avatarSpacing: CGFloat = 10
    /// Where profile names start. Nested workspace symbols start here too, so
    /// each workspace reads as part of the profile above it.
    static let titleInset = contentInset + avatarSize + avatarSpacing
    static let symbolSize: CGFloat = 16
    private static let moreWidth: CGFloat = 22

    let item: LaunchTarget
    var onShowActions: ((NSButton) -> Void)?
    /// Right-click and Control-click show the same actions as the ⋯ button.
    var contextMenu: (() -> NSMenu?)?
    var onLocate: (() -> Void)?
    var isSelectedRow: Bool { didSet { setAccessibilitySelected(isSelectedRow); highlightChanged() } }
    /// The inset, rounded plate behind hover and keyboard selection.
    let highlight = RowHighlightView()
    var showsPlate: Bool { isSelectedRow || isHovered && isEnabled }
    private var isHovered = false { didSet { highlightChanged() } }
    private var tracking: NSTrackingArea?
    private let destination: OpenDestination
    private let launching: Bool
    private let detail: NSTextField
    private let profileDetail: String
    private let usageView: ProfileUsageView?
    private let avatar: RowAvatar?
    private let more: NSButton

    init(item: LaunchTarget, appearance: ProfileAppearance, destination: OpenDestination, usage: UsageState?, pinned: Bool, nested: Bool, selected: Bool,
         launching: Bool, changing: Bool, enabled: Bool, target: AnyObject?, action: Selector?) {
        self.item = item
        self.destination = destination
        self.launching = launching
        isSelectedRow = selected
        let workspace = item.workspace
        profileDetail = launching ? "Opening in \(destination.label)…"
            : destination == .terminal ? "Codex CLI profile" : item.profile == "default" ? "Standard ChatGPT window" : "Separate ChatGPT window"
        let workspaceDetail = workspace.map { workspace in
            changing ? "Updating…" : launching ? "Opening in \(destination.label)…"
                : workspace.availabilityReason.map { "\($0) · \(workspace.displayPath())" } ?? workspace.displayPath()
        }
        detail = NSTextField(labelWithString: workspaceDetail ?? profileDetail)
        usageView = workspace == nil ? ProfileUsageView(usage: usage ?? UsageState()) : nil
        // A tile in the profile's colour marks each profile; workspaces carry a bare symbol.
        avatar = workspace == nil ? RowAvatar(profile: item.profile, appearance: appearance) : nil
        more = NSButton(image: NSImage(systemSymbolName: "ellipsis", accessibilityDescription: "Actions for \(item.name)") ?? NSImage(), target: nil, action: nil)
        super.init(frame: .zero)
        self.target = target
        self.action = action
        title = ""
        isBordered = false
        wantsLayer = true
        focusRingType = .none
        isEnabled = enabled
        translatesAutoresizingMaskIntoConstraints = false
        let twoLines = workspace == nil || !item.isAvailable
        heightAnchor.constraint(equalToConstant: workspace == nil ? 46 : twoLines ? 44 : 30).isActive = true
        let state = changing ? "Updating" : "Open in \(destination.label)"
        setAccessibilityLabel(workspace.map { "\($0.name), profile \($0.profile), \($0.path). \($0.availabilityReason ?? state)" }
            ?? "Profile \(item.profile). \(state)")
        setAccessibilitySelected(selected)
        toolTip = workspace.map { "\($0.path)\nProfile: \($0.profile)" } ?? "Open profile \(item.profile) without a project folder"

        let name = NSTextField(labelWithString: item.name)
        name.font = .systemFont(ofSize: 13, weight: workspace == nil ? .semibold : .regular)
        name.lineBreakMode = .byTruncatingTail
        name.toolTip = item.name
        name.textColor = item.isAvailable ? .labelColor : .secondaryLabelColor
        detail.font = .systemFont(ofSize: 11)
        detail.textColor = .secondaryLabelColor
        // Paths keep both ends readable; prose keeps its beginning.
        detail.lineBreakMode = workspace == nil || changing || launching ? .byTruncatingTail : .byTruncatingMiddle
        detail.toolTip = toolTip
        name.setContentCompressionResistancePriority(.init(260), for: .horizontal)
        detail.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let labels = NSStackView(views: [name, detail])
        labels.orientation = twoLines ? .vertical : .horizontal
        labels.alignment = twoLines ? .leading : .firstBaseline
        labels.spacing = twoLines ? 1 : 8
        if twoLines {
            for value in [name, detail] { value.widthAnchor.constraint(lessThanOrEqualTo: labels.widthAnchor).isActive = true }
        }
        labels.setContentHuggingPriority(.defaultLow, for: .horizontal)
        labels.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        var rowViews: [NSView] = []
        if let avatar { rowViews.append(avatar) }
        if let workspace {
            let symbol = NSImageView(image: NSImage(systemSymbolName: !workspace.isAvailable ? "questionmark.folder" : pinned ? "pin" : "folder",
                accessibilityDescription: nil) ?? NSImage())
            symbol.symbolConfiguration = .init(pointSize: 12, weight: .regular)
            symbol.contentTintColor = .secondaryLabelColor
            symbol.widthAnchor.constraint(equalToConstant: Self.symbolSize).isActive = true
            symbol.setContentHuggingPriority(.required, for: .horizontal)
            rowViews.append(symbol)
        }
        rowViews.append(labels)
        if let workspace, !nested {
            // Without its profile's row above, a workspace names its profile
            // beside a dot in the profile's colour.
            let tag = NSTextField(labelWithString: workspace.profile)
            tag.font = .systemFont(ofSize: 11, weight: .medium)
            tag.textColor = .secondaryLabelColor
            tag.lineBreakMode = .byTruncatingTail
            let marked = NSStackView(views: [ColourDot(appearance.colour), tag])
            marked.spacing = 4
            marked.alignment = .centerY
            marked.setContentHuggingPriority(.required, for: .horizontal)
            marked.setContentCompressionResistancePriority(.init(255), for: .horizontal)
            tag.setContentCompressionResistancePriority(.init(255), for: .horizontal)
            rowViews.append(marked)
        }
        if let usageView { rowViews.append(usageView) }
        if let workspace, !workspace.pathExists {
            let locate = NSButton(title: "Locate…", target: self, action: #selector(locateFolder(_:)))
            locate.bezelStyle = .rounded
            locate.controlSize = .small
            locate.font = .systemFont(ofSize: 11)
            locate.isEnabled = !changing
            locate.toolTip = "Choose where \(workspace.name) moved"
            locate.setContentHuggingPriority(.required, for: .horizontal)
            rowViews.append(locate)
        }
        more.target = self
        more.action = #selector(showActions(_:))
        more.isBordered = false
        more.contentTintColor = .secondaryLabelColor
        more.toolTip = workspace == nil ? "Open elsewhere, add a workspace, or sign in to Codex CLI" : "Open elsewhere, pin, change profile, or remove binding"
        more.isEnabled = !changing
        more.widthAnchor.constraint(equalToConstant: Self.moreWidth).isActive = true
        more.heightAnchor.constraint(equalToConstant: 22).isActive = true
        rowViews.append(more)

        let row = NSStackView(views: rowViews)
        row.orientation = .horizontal
        row.alignment = .centerY
        row.distribution = .fill
        row.spacing = 8
        if let avatar { row.setCustomSpacing(Self.avatarSpacing, after: avatar) }
        if let usageView { row.setCustomSpacing(4, after: usageView) }
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(highlight)
        addSubview(row)
        // Nested workspaces start at the profile's title column; others centre
        // their symbol under the profile tiles.
        let leading = workspace == nil ? Self.contentInset : nested ? Self.titleInset : Self.contentInset + (Self.avatarSize - Self.symbolSize) / 2
        NSLayoutConstraint.activate([
            highlight.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6), highlight.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            highlight.topAnchor.constraint(equalTo: topAnchor, constant: 1), highlight.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -1),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: leading),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            row.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        if workspace == nil { update(usage: usage ?? UsageState()) }
        updateActionsVisibility()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Shows a newer usage reading without rebuilding the row.
    func update(usage: UsageState, now: Date = Date()) {
        guard let usageView else { return }
        usageView.update(usage, now: now)
        let explanation = usage.detail(at: now)
        toolTip = "Open profile \(item.profile) without a project folder\n\(explanation)"
        detail.toolTip = toolTip
        // A low quota matters more than the destination description.
        if !launching { detail.stringValue = usage.summary(at: now) ?? profileDetail }
        setAccessibilityLabel("Profile \(item.profile). Open in \(destination.label). \(explanation)")
    }

    override var wantsUpdateLayer: Bool { true }
    override func updateLayer() { updateSystemColours() }

    func updateSystemColours(
        reduceTransparency: Bool = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency,
        increaseContrast: Bool = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
    ) {
        guard let plate = highlight.layer else { return }
        effectiveAppearance.performAsCurrentDrawingAppearance {
            let solid = reduceTransparency || increaseContrast
            let fill: NSColor = isSelectedRow ? (solid ? .unemphasizedSelectedContentBackgroundColor : .controlAccentColor.withAlphaComponent(0.16))
                : isHovered && isEnabled ? (solid ? .unemphasizedSelectedContentBackgroundColor : .labelColor.withAlphaComponent(0.06)) : .clear
            plate.backgroundColor = fill.cgColor
            // Shape identifies keyboard selection even without colour cues.
            plate.borderWidth = isSelectedRow ? 1 : 0
            plate.borderColor = NSColor.labelColor.withAlphaComponent(increaseContrast ? 1 : 0.28).cgColor
        }
    }

    func redrawUsageMeters() { usageView?.redrawMeters() }
    func redrawAvatar() { avatar?.needsDisplay = true }
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); needsDisplay = true }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        tracking = NSTrackingArea(rect: bounds, options: [.activeInKeyWindow, .mouseEnteredAndExited, .inVisibleRect], owner: self)
        addTrackingArea(tracking!)
    }
    override func mouseEntered(with event: NSEvent) { isHovered = true }
    override func mouseExited(with event: NSEvent) { isHovered = false }
    override func menu(for event: NSEvent) -> NSMenu? { contextMenu?() ?? super.menu(for: event) }
    private func highlightChanged() {
        needsDisplay = true
        updateActionsVisibility()
    }
    /// The actions button appears with the plate, so resting rows stay quiet.
    /// It stays in the accessibility tree, and rows that need repair always show it.
    private func updateActionsVisibility() { more.alphaValue = showsPlate || !item.isAvailable ? 1 : 0 }
    @objc private func showActions(_ sender: NSButton) { onShowActions?(sender) }
    @objc private func locateFolder(_ sender: NSButton) { onLocate?() }
}

/// A profile's tightest Codex window: its remaining percentage and duration
/// beside a ring. The number carries the value; colour adds emphasis when
/// the window is low.
final class ProfileUsageView: NSStackView {
    static let figureWidth: CGFloat = 64
    private let figure = NSTextField(labelWithString: "")
    private let caption = NSTextField(labelWithString: "")
    private let ring = QuotaRing()

    init(usage: UsageState, now: Date = Date()) {
        super.init(frame: .zero)
        orientation = .horizontal
        alignment = .centerY
        spacing = 8
        caption.font = .systemFont(ofSize: 11)
        caption.textColor = .secondaryLabelColor
        caption.alignment = .right
        let labels = NSStackView(views: [figure, caption])
        labels.orientation = .vertical
        labels.alignment = .trailing
        labels.spacing = 1
        labels.widthAnchor.constraint(equalToConstant: Self.figureWidth).isActive = true
        addArrangedSubview(labels)
        addArrangedSubview(ring)
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
        setAccessibilityLabel("Codex quota remaining")
        update(usage, now: now)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Replaces the reading in place. A refresh dims the previous reading
    /// rather than hiding it; a passed reset shows a dash, never restored quota.
    func update(_ usage: UsageState, now: Date = Date()) {
        toolTip = usage.detail(at: now)
        setAccessibilityValue(toolTip)
        for view in arrangedSubviews { view.alphaValue = usage.isRefreshing && usage.limits != nil ? 0.45 : 1 }
        if let window = usage.tightestWindow(at: now) {
            figure.attributedStringValue = Self.figure("\(window.remainingPercent)", unit: "%", level: window.level)
            caption.stringValue = "\(window.durationLabel ?? "Limit") left"
            ring.fraction = CGFloat(window.remainingPercent) / 100
            ring.level = window.level
        } else {
            figure.attributedStringValue = Self.figure("—", unit: "", level: nil)
            caption.stringValue = usage.limits != nil ? "Reset" : usage.reading == nil || usage.isRefreshing ? "Checking…" : "Unavailable"
            ring.fraction = nil
            ring.level = .normal
        }
    }

    /// Tabular figures with a smaller unit, so the column reads as numbers.
    private static func figure(_ value: String, unit: String, level: QuotaLevel?) -> NSAttributedString {
        let colour = level.map { QuotaPalette.text(for: $0) } ?? .secondaryLabelColor
        let text = NSMutableAttributedString(string: value, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold), .foregroundColor: colour,
        ])
        text.append(NSAttributedString(string: unit, attributes: [
            .font: NSFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: level == .normal ? NSColor.secondaryLabelColor : colour,
        ]))
        return text
    }

    func redrawMeters() { ring.needsDisplay = true }
}

/// Low and critical emphasis for quota figures and rings. In light mode these
/// are darker than systemOrange and systemRed, so a coloured figure keeps
/// 4.5:1 contrast on the popover and on a hovered row.
enum QuotaPalette {
    static let low = dynamic(light: (0.627, 0.306, 0), dark: (1, 0.702, 0.251))
    static let critical = dynamic(light: (0.784, 0, 0.102), dark: (1, 0.412, 0.380))

    static func text(for level: QuotaLevel) -> NSColor {
        switch level {
        case .critical: critical
        case .low: low
        case .normal: .labelColor
        }
    }

    static func ring(for level: QuotaLevel, increaseContrast: Bool) -> NSColor {
        level == .normal ? (increaseContrast ? .labelColor : .secondaryLabelColor) : text(for: level)
    }

    private static func dynamic(light: (CGFloat, CGFloat, CGFloat), dark: (CGFloat, CGFloat, CGFloat)) -> NSColor {
        NSColor(name: nil) { appearance in
            let value = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: value.0, green: value.1, blue: value.2, alpha: 1)
        }
    }
}

/// A 20-point ring filled clockwise from the top with a window's remaining
/// share. Any remaining quota shows at least a sliver; no reading shows the
/// track alone.
final class QuotaRing: NSView {
    static let size: CGFloat = 20
    private static let lineWidth: CGFloat = 2.5
    var fraction: CGFloat? { didSet { needsDisplay = true } }
    var level: QuotaLevel = .normal { didSet { needsDisplay = true } }
    private let track = CAShapeLayer()
    private let arc = CAShapeLayer()

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        for shape in [track, arc] {
            shape.fillColor = nil
            shape.lineWidth = Self.lineWidth
            shape.actions = ["path": NSNull(), "strokeColor": NSNull(), "strokeEnd": NSNull(), "hidden": NSNull()]
            layer?.addSublayer(shape)
        }
        arc.lineCap = .round
        setAccessibilityElement(false)
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: Self.size).isActive = true
        heightAnchor.constraint(equalToConstant: Self.size).isActive = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var wantsUpdateLayer: Bool { true }
    override func layout() { super.layout(); needsDisplay = true }
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); needsDisplay = true }

    override func updateLayer() {
        let contrast = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        let radius = (min(bounds.width, bounds.height) - Self.lineWidth) / 2
        let centre = CGPoint(x: bounds.midX, y: bounds.midY)
        let path = CGMutablePath()
        // Layer coordinates run upwards, so decreasing angles run clockwise.
        path.addArc(center: centre, radius: radius, startAngle: .pi / 2, endAngle: .pi / 2 - 2 * .pi, clockwise: true)
        track.path = path
        arc.path = path
        effectiveAppearance.performAsCurrentDrawingAppearance {
            track.strokeColor = (contrast ? NSColor.tertiaryLabelColor : .quaternaryLabelColor).cgColor
            arc.strokeColor = QuotaPalette.ring(for: level, increaseContrast: contrast).cgColor
        }
        let share = min(1, fraction ?? 0)
        arc.isHidden = share <= 0
        arc.strokeEnd = max(0.03, share)
    }
}

/// The rounded plate a row paints for hover and keyboard selection. It sits
/// behind the row's content and lets clicks reach the row.
final class RowHighlightView: NSView {
    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 7
        layer?.cornerCurve = .continuous
        layer?.actions = ["backgroundColor": NSNull(), "borderColor": NSNull(), "borderWidth": NSNull()]
        translatesAutoresizingMaskIntoConstraints = false
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

extension ProfileAppearance.Colour {
    var nsColor: NSColor { NSColor(srgbRed: components.red, green: components.green, blue: components.blue, alpha: 1) }
}

/// A profile's mark: a rounded tile in its colour holding its initial or
/// chosen symbol in white. Colour belongs to profile identity; quota keeps
/// orange and red, which the palette leaves out.
final class RowAvatar: NSView {
    var profileAppearance: ProfileAppearance { didSet { if profileAppearance != oldValue { showGlyph(); needsDisplay = true } } }
    private let initial: String
    private let size: CGFloat

    init(profile: String, appearance: ProfileAppearance, size: CGFloat = LaunchRowButton.avatarSize) {
        profileAppearance = appearance
        initial = profile.first.map { String($0).uppercased() } ?? ""
        self.size = size
        super.init(frame: .zero)
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
        setAccessibilityElement(false)
        NSLayoutConstraint.activate([widthAnchor.constraint(equalToConstant: size), heightAnchor.constraint(equalToConstant: size)])
        showGlyph()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func showGlyph() {
        subviews.forEach { $0.removeFromSuperview() }
        let glyph: NSView
        if let name = profileAppearance.symbol.systemName, let image = NSImage(systemSymbolName: name, accessibilityDescription: nil) {
            let symbol = NSImageView(image: image)
            symbol.symbolConfiguration = .init(pointSize: (size * 0.48).rounded(), weight: .medium)
            symbol.contentTintColor = .white
            glyph = symbol
        } else {
            let letter = NSTextField(labelWithString: initial)
            let points = (size * 0.48).rounded()
            let font = NSFont.systemFont(ofSize: points, weight: .semibold)
            letter.font = font.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: points) } ?? font
            letter.textColor = .white
            letter.alignment = .center
            glyph = letter
        }
        glyph.setAccessibilityElement(false)
        glyph.translatesAutoresizingMaskIntoConstraints = false
        addSubview(glyph)
        NSLayoutConstraint.activate([glyph.centerXAnchor.constraint(equalTo: centerXAnchor), glyph.centerYAnchor.constraint(equalTo: centerYAnchor)])
    }

    override var wantsUpdateLayer: Bool { true }
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); needsDisplay = true }

    override func updateLayer() {
        guard let layer else { return }
        let contrast = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        layer.backgroundColor = profileAppearance.colour.nsColor.cgColor
        effectiveAppearance.performAsCurrentDrawingAppearance {
            // Increased contrast outlines the tile against the popover.
            layer.borderWidth = contrast ? 1 : 0
            layer.borderColor = NSColor.labelColor.cgColor
        }
        layer.cornerCurve = .continuous
        layer.cornerRadius = (size * 0.27).rounded()
    }
}

/// A small square in a profile's colour beside its name.
final class ColourDot: NSView {
    init(_ colour: ProfileAppearance.Colour) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = colour.nsColor.cgColor
        layer?.cornerRadius = 2.5
        setAccessibilityElement(false)
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([widthAnchor.constraint(equalToConstant: 8), heightAnchor.constraint(equalToConstant: 8)])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

/// Chooses a profile's colour and symbol in place of the list. A choice
/// applies at once; Reset restores the automatic appearance and Done returns.
final class AppearanceEditorView: NSStackView {
    let profile: String
    var onChoose: ((ProfileAppearance) -> Void)?
    var onReset: (() -> Void)?
    var onDone: (() -> Void)?
    private(set) var profileAppearance: ProfileAppearance
    private let preview: RowAvatar
    private var swatches: [SwatchButton] = []
    private var symbols: [SymbolChoiceButton] = []

    init(profile: String, appearance: ProfileAppearance) {
        self.profile = profile
        profileAppearance = appearance
        preview = RowAvatar(profile: profile, appearance: appearance, size: 40)
        super.init(frame: .zero)
        orientation = .vertical
        alignment = .leading
        spacing = 8
        edgeInsets = NSEdgeInsets(top: 14, left: LaunchRowButton.contentInset, bottom: 12, right: LaunchRowButton.contentInset)

        let name = Self.label(profile, size: 15, weight: .semibold)
        name.lineBreakMode = .byTruncatingTail
        // The profile's CODEX_HOME, from the documented mapping; nothing is read.
        let home = Self.label(profile == "default" ? "~/.codex" : "~/.codex-\(profile)", size: 11, weight: .regular)
        home.textColor = .secondaryLabelColor
        let names = NSStackView(views: [name, home])
        names.orientation = .vertical
        names.alignment = .leading
        names.spacing = 1
        let identity = NSStackView(views: [preview, names])
        identity.spacing = 12
        identity.alignment = .centerY
        addArrangedSubview(identity)
        setCustomSpacing(16, after: identity)

        let colourHeading = Self.heading("Colour")
        addArrangedSubview(colourHeading)
        swatches = ProfileAppearance.Colour.allCases.map { colour in
            let swatch = SwatchButton(colour: colour)
            swatch.target = self
            swatch.action = #selector(chooseColour(_:))
            return swatch
        }
        let palette = NSStackView(views: swatches)
        palette.spacing = 8
        palette.setAccessibilityElement(true)
        palette.setAccessibilityRole(.group)
        palette.setAccessibilityLabel("Colour")
        addArrangedSubview(palette)
        setCustomSpacing(16, after: palette)

        let symbolHeading = Self.heading("Symbol")
        addArrangedSubview(symbolHeading)
        symbols = ProfileAppearance.Symbol.allCases.map { symbol in
            let choice = SymbolChoiceButton(symbol: symbol, initial: profile.first.map { String($0).uppercased() } ?? "")
            choice.target = self
            choice.action = #selector(chooseSymbol(_:))
            return choice
        }
        let columns = 6
        let grid = NSStackView(views: stride(from: 0, to: symbols.count, by: columns).map { start in
            let line = NSStackView(views: Array(symbols[start..<min(start + columns, symbols.count)]))
            line.spacing = 6
            return line
        })
        grid.orientation = .vertical
        grid.alignment = .leading
        grid.spacing = 6
        grid.setAccessibilityElement(true)
        grid.setAccessibilityRole(.group)
        grid.setAccessibilityLabel("Symbol")
        addArrangedSubview(grid)
        setCustomSpacing(16, after: grid)

        let reset = NSButton(title: "Reset", target: self, action: #selector(reset(_:)))
        reset.bezelStyle = .rounded
        reset.toolTip = "Use the automatic colour and the profile’s initial"
        let done = NSButton(title: "Done", target: self, action: #selector(done(_:)))
        done.bezelStyle = .rounded
        done.keyEquivalent = "\r"
        let buttons = NSStackView(views: [NSView(), reset, done])
        buttons.spacing = 8
        addArrangedSubview(buttons)
        buttons.widthAnchor.constraint(equalTo: widthAnchor, constant: -2 * LaunchRowButton.contentInset).isActive = true
        update(appearance)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(_ appearance: ProfileAppearance) {
        profileAppearance = appearance
        preview.profileAppearance = appearance
        for swatch in swatches { swatch.isChosen = swatch.colour == appearance.colour }
        for choice in symbols { choice.show(chosen: choice.symbol == appearance.symbol, colour: appearance.colour) }
    }

    @objc private func chooseColour(_ sender: SwatchButton) {
        var choice = profileAppearance
        choice.colour = sender.colour
        update(choice)
        onChoose?(choice)
    }

    @objc private func chooseSymbol(_ sender: SymbolChoiceButton) {
        var choice = profileAppearance
        choice.symbol = sender.symbol
        update(choice)
        onChoose?(choice)
    }

    @objc private func reset(_ sender: NSButton) { onReset?() }
    @objc private func done(_ sender: NSButton) { onDone?() }

    private static func label(_ text: String, size: CGFloat, weight: NSFont.Weight) -> NSTextField {
        let value = NSTextField(labelWithString: text)
        value.font = .systemFont(ofSize: size, weight: weight)
        return value
    }

    private static func heading(_ text: String) -> NSTextField {
        let value = label(text, size: 11, weight: .semibold)
        value.textColor = .secondaryLabelColor
        return value
    }
}

/// A round colour choice. The chosen one gains a ring in the label colour,
/// so the choice never depends on colour alone.
final class SwatchButton: NSButton {
    let colour: ProfileAppearance.Colour
    var isChosen = false { didSet { state = isChosen ? .on : .off; needsDisplay = true } }
    private let fill = CALayer()

    init(colour: ProfileAppearance.Colour) {
        self.colour = colour
        super.init(frame: .zero)
        title = ""
        isBordered = false
        setButtonType(.pushOnPushOff)
        wantsLayer = true
        focusRingType = .default
        fill.actions = ["backgroundColor": NSNull(), "frame": NSNull()]
        layer?.addSublayer(fill)
        toolTip = colour.label
        setAccessibilityLabel(colour.label)
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([widthAnchor.constraint(equalToConstant: 30), heightAnchor.constraint(equalToConstant: 30)])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// The frame is the drawn shape, so layout spacing is the visible gap.
    override var alignmentRectInsets: NSEdgeInsets { NSEdgeInsetsZero }
    override var wantsUpdateLayer: Bool { true }
    override func layout() { super.layout(); needsDisplay = true }
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); needsDisplay = true }

    override func updateLayer() {
        guard let layer else { return }
        fill.frame = bounds.insetBy(dx: 4, dy: 4)
        fill.cornerRadius = fill.frame.width / 2
        fill.backgroundColor = colour.nsColor.cgColor
        layer.cornerRadius = bounds.width / 2
        layer.borderWidth = isChosen ? 2 : 0
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer.borderColor = NSColor.labelColor.cgColor
        }
    }
}

/// One symbol choice. The chosen symbol sits on the profile's colour in
/// white, as it will in the list.
final class SymbolChoiceButton: NSButton {
    let symbol: ProfileAppearance.Symbol
    private var chosen = false
    private var colour = ProfileAppearance.Colour.graphite

    init(symbol: ProfileAppearance.Symbol, initial: String) {
        self.symbol = symbol
        super.init(frame: .zero)
        isBordered = false
        setButtonType(.pushOnPushOff)
        wantsLayer = true
        if let name = symbol.systemName {
            title = ""
            image = NSImage(systemSymbolName: name, accessibilityDescription: symbol.label)
            symbolConfiguration = .init(pointSize: 14, weight: .regular)
            imagePosition = .imageOnly
        } else {
            let font = NSFont.systemFont(ofSize: 14, weight: .semibold)
            self.font = font.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: 14) } ?? font
            title = initial
        }
        toolTip = symbol.label
        setAccessibilityLabel(symbol.label)
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([widthAnchor.constraint(equalToConstant: 46), heightAnchor.constraint(equalToConstant: 32)])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show(chosen: Bool, colour: ProfileAppearance.Colour) {
        self.chosen = chosen
        self.colour = colour
        state = chosen ? .on : .off
        contentTintColor = chosen ? .white : .labelColor
        needsDisplay = true
    }

    /// The frame is the drawn shape, so layout spacing is the visible gap.
    override var alignmentRectInsets: NSEdgeInsets { NSEdgeInsetsZero }
    override var wantsUpdateLayer: Bool { true }
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); needsDisplay = true }

    override func updateLayer() {
        guard let layer else { return }
        layer.cornerCurve = .continuous
        layer.cornerRadius = 8
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer.backgroundColor = (chosen ? colour.nsColor : NSColor.labelColor.withAlphaComponent(0.06)).cgColor
        }
    }
}

/// A hairline between profile groups, inset to the content edges. Rows within
/// a group need no rules; the nesting already shows what belongs together.
final class GroupDivider: NSView {
    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separator)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 9),
            separator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: LaunchRowButton.contentInset),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -LaunchRowButton.contentInset),
            separator.centerYAnchor.constraint(equalTo: centerYAnchor), separator.heightAnchor.constraint(equalToConstant: 1),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
