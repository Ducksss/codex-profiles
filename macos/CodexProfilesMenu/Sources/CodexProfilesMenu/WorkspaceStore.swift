import Foundation

@MainActor
final class WorkspaceStore {
    enum Phase: Equatable {
        case idle
        case loading
        case ready
        case failed(String)
    }

    var onChange: (() -> Void)?
    var onError: ((String) -> Void)?
    /// Called when a usage reading changes, whether or not the menu is open.
    var onUsageChange: (() -> Void)?

    var query = "" {
        didSet { notify() }
    }

    var selectedProfile: String? {
        didSet { notify() }
    }

    private(set) var phase: Phase = .idle
    private(set) var workspaces: [WorkspaceBinding] = []
    private(set) var profiles: [String] = []
    private(set) var usage: [String: ProfileUsage] = [:] {
        didSet { if usage != oldValue { onUsageChange?() } }
    }
    /// Profiles with a usage read in flight; their previous reading stays visible.
    private(set) var readingUsage: Set<String> = []
    /// Folders whose binding is being changed. Their rows cannot launch until
    /// the CLI reports the outcome, so a stale row never opens the old profile.
    private(set) var changingPaths: Set<String> = []
    private(set) var guardMode = "off"
    private(set) var isRefreshing = false
    private(set) var launchingID: LaunchTarget.ID?
    private(set) var statusMessage = "Choose a profile or workspace"

    private let client: CLIClient
    private let defaults: UserDefaults
    private let recentsKey = "workspaceRecents"
    private let pinsKey = "workspacePins"
    private var refreshTask: Task<Bool, Never>?
    private var refreshRequested = false
    private var hasLoaded = false
    private var usageTask: Task<Void, Never>?
    private var usageRefreshRequested = false
    private var forceUsageRefresh = false
    private var backgroundUsageTask: Task<Void, Never>?

    var isRefreshingUsage: Bool { usageTask != nil }
    /// Whether periodic usage reads are scheduled, which only low-quota alerts request.
    var isRefreshingUsageInBackground: Bool { backgroundUsageTask != nil }

    init(client: CLIClient, defaults: UserDefaults = .standard) {
        self.client = client
        self.defaults = defaults
    }

    var filteredWorkspaces: [WorkspaceBinding] {
        sortByRecency(workspaces.filter {
            $0.matches(query) && (selectedProfile == nil || $0.profile == selectedProfile)
        })
    }

    var filteredTargets: [LaunchTarget] {
        profiles.map(LaunchTarget.profile).filter {
            $0.matches(query) && (selectedProfile == nil || $0.profile == selectedProfile)
        } + filteredWorkspaces.map(LaunchTarget.workspace)
    }

    func isPinned(_ workspace: WorkspaceBinding) -> Bool {
        (defaults.stringArray(forKey: pinsKey) ?? []).contains(workspace.id)
    }

    func usageState(for profile: String) -> UsageState {
        UsageState(reading: usage[profile], isRefreshing: readingUsage.contains(profile))
    }

    func isChanging(_ target: LaunchTarget) -> Bool {
        target.workspace.map { changingPaths.contains($0.path) } ?? false
    }

    /// Whether a row may launch now: available, current and not being changed.
    func canLaunch(_ target: LaunchTarget) -> Bool {
        target.isAvailable && !isChanging(target)
    }

    func togglePin(_ workspace: WorkspaceBinding) {
        var pins = defaults.stringArray(forKey: pinsKey) ?? []
        if let index = pins.firstIndex(of: workspace.id) {
            pins.remove(at: index)
        } else {
            pins.append(workspace.id)
        }
        defaults.set(pins, forKey: pinsKey)
        notify()
    }

    func refreshIfNeeded() async {
        guard phase == .idle else { return }
        await refresh()
        await refreshUsage()
    }

    func refreshUsage(force: Bool = false) async {
        forceUsageRefresh = forceUsageRefresh || force
        if let usageTask {
            usageRefreshRequested = true
            await usageTask.value
            return
        }
        let task = Task { @MainActor in
            repeat {
                usageRefreshRequested = false
                let now = Date()
                let pending = profiles.filter { forceUsageRefresh || (usage[$0]?.needsRefresh(at: now) ?? true) }
                forceUsageRefresh = false
                readingUsage.formUnion(pending)
                notify()
                let client = self.client
                // Two short-lived readers at most, even for a long profile list.
                await withTaskGroup(of: (String, ProfileUsage).self) { group in
                    var iterator = pending.makeIterator()
                    func add(_ profile: String) {
                        group.addTask {
                            do {
                                let limits = try await client.loadUsage(for: profile)
                                return (profile, .available(limits, checkedAt: Date()))
                            } catch {
                                return (profile, .unavailable(checkedAt: Date()))
                            }
                        }
                    }
                    for _ in 0..<2 { if let profile = iterator.next() { add(profile) } }
                    for await (profile, result) in group {
                        guard !Task.isCancelled else { group.cancelAll(); return }
                        readingUsage.remove(profile)
                        if profiles.contains(profile) { usage[profile] = result }
                        notify()
                        if let next = iterator.next() { add(next) }
                    }
                }
                // Cancelled reads keep the previous reading and record nothing new.
                readingUsage.subtract(pending)
            } while usageRefreshRequested && !Task.isCancelled
            usageTask = nil
            notify()
        }
        usageTask = task
        notify()
        await task.value
    }

    /// Reads usage now and then about every `interval` seconds until stopped.
    /// Each pass goes through refreshUsage, so the cache, the two-reader bound,
    /// deadlines and process cleanup apply unchanged. Without initialized
    /// profiles a pass starts no reader.
    func startBackgroundUsageRefresh(every interval: TimeInterval) {
        guard backgroundUsageTask == nil else { return }
        let period = Duration.milliseconds(Int64(max(0.01, interval) * 1000))
        backgroundUsageTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let store = self else { return }
                await store.refreshUsageInBackground()
                // Tolerance lets macOS coalesce the wake-up with other timers.
                try? await Task.sleep(for: period, tolerance: period / 5, clock: .continuous)
            }
        }
    }

    /// Stops scheduling reads. A read already in flight finishes or times out
    /// as usual, because the menu may be waiting for the same reading.
    func stopBackgroundUsageRefresh() {
        backgroundUsageTask?.cancel()
        backgroundUsageTask = nil
    }

    private func refreshUsageInBackground() async {
        // A login launch has not listed profiles yet; the menu refreshes the
        // list whenever it opens.
        if !hasLoaded { await refresh() }
        guard !profiles.isEmpty, !Task.isCancelled else { return }
        await refreshUsage()
    }

    func cancelUsageRefresh() {
        stopBackgroundUsageRefresh()
        usageRefreshRequested = false
        forceUsageRefresh = false
        usageTask?.cancel()
    }

    func stopUsageRefresh() async {
        cancelUsageRefresh()
        await usageTask?.value
    }

    @discardableResult
    func refresh() async -> Bool {
        if let refreshTask {
            refreshRequested = true
            return await refreshTask.value
        }

        let task = Task { @MainActor in
            isRefreshing = true
            if !hasLoaded { phase = .loading }
            statusMessage = "Refreshing profiles…"
            notify()

            var succeeded = false
            repeat {
                refreshRequested = false
                succeeded = await loadSnapshot()
            } while refreshRequested

            isRefreshing = false
            refreshTask = nil
            notify()
            return succeeded
        }
        refreshTask = task
        return await task.value
    }

    private func loadSnapshot() async -> Bool {
        do {
            async let workspaceResponse = client.loadWorkspaces()
            async let profileResponse = client.loadProfiles()
            let (response, loadedProfiles) = try await (workspaceResponse, profileResponse)
            workspaces = response.bindings
            profiles = loadedProfiles
            usage = usage.filter { profiles.contains($0.key) }
            guardMode = response.guardMode
            if let selectedProfile, !profiles.contains(selectedProfile) {
                self.selectedProfile = nil
            }
            hasLoaded = true
            phase = .ready
            statusMessage = profiles.isEmpty && workspaces.isEmpty
                ? "Create a profile to get started"
                : "Choose a profile or workspace"
            return true
        } catch {
            if !hasLoaded { phase = .failed(error.localizedDescription) }
            statusMessage = "Could not refresh: \(error.localizedDescription)"
            return false
        }
    }

    @discardableResult
    func bindWorkspace(path: String, profile: String) async -> Bool {
        guard beginChanging([path]) else { return false }
        defer { endChanging([path]) }
        return await bind(path: path, profile: profile)
    }

    private func bind(path: String, profile: String) async -> Bool {
        statusMessage = "Adding \(URL(fileURLWithPath: path).lastPathComponent)…"
        notify()
        defer { notify() }

        do {
            try await client.bindWorkspace(path: path, profile: profile)
            return await refreshAfterMutation("Workspace added to \(profile)")
        } catch {
            statusMessage = error.localizedDescription
            onError?(statusMessage)
            return false
        }
    }

    @discardableResult
    func createProfile(_ profile: String) async -> Bool {
        statusMessage = "Creating \(profile)…"
        notify()
        defer { notify() }

        do {
            try await client.createProfile(profile)
            return await refreshAfterMutation("Profile \(profile) created")
        } catch {
            statusMessage = error.localizedDescription
            onError?(statusMessage)
            return false
        }
    }

    func signInToCLI(_ profile: String) async {
        statusMessage = "Opening sign-in for \(profile)…"
        notify()

        do {
            try await client.signInToCLI(profile)
            statusMessage = "Finish signing in to \(profile) in Terminal"
        } catch {
            statusMessage = error.localizedDescription
            onError?(statusMessage)
        }
        notify()
    }

    func unbindWorkspace(_ workspace: WorkspaceBinding) async {
        guard beginChanging([workspace.path]) else { return }
        defer { endChanging([workspace.path]) }
        statusMessage = "Removing \(workspace.name)…"
        notify()

        do {
            try await client.unbindWorkspace(path: workspace.path)
            workspaces.removeAll { $0.path == workspace.path }
            forget(workspace)
            await refreshAfterMutation("Removed \(workspace.name) from the launcher")
        } catch {
            statusMessage = error.localizedDescription
            onError?(statusMessage)
        }
        notify()
    }

    func rebindWorkspace(_ workspace: WorkspaceBinding, to profile: String) async {
        guard beginChanging([workspace.path]) else { return }
        defer { endChanging([workspace.path]) }
        statusMessage = "Assigning \(workspace.name) to \(profile)…"
        notify()

        do {
            try await client.bindWorkspace(path: workspace.path, profile: profile, force: true)
            let replacement = WorkspaceBinding(
                path: workspace.path,
                profile: profile,
                pathExists: workspace.pathExists,
                profileExists: true
            )
            if let index = workspaces.firstIndex(where: { $0.path == workspace.path }) {
                workspaces[index] = replacement
            }
            movePreferences(from: workspace, to: replacement)
            await refreshAfterMutation("Assigned \(workspace.name) to \(profile)")
        } catch {
            statusMessage = error.localizedDescription
            onError?(statusMessage)
        }
        notify()
    }

    func relocateWorkspace(_ workspace: WorkspaceBinding, to path: String) async {
        let canonicalPath = path.withCString { pointer in
            guard let resolved = realpath(pointer, nil) else { return path }
            defer { free(resolved) }
            return String(cString: resolved)
        }
        guard canonicalPath != workspace.path else {
            await refresh()
            return
        }
        let paths = [workspace.path, canonicalPath]
        guard beginChanging(paths) else { return }
        defer { endChanging(paths) }
        guard await bind(path: canonicalPath, profile: workspace.profile) else { return }
        guard let replacement = workspaces.first(where: { $0.path == canonicalPath && $0.profile == workspace.profile }) else {
            showMessage("Could not verify the new folder binding; the previous binding was kept")
            onError?(statusMessage)
            return
        }

        do {
            try await client.unbindWorkspace(path: workspace.path)
            workspaces.removeAll { $0.path == workspace.path }
            movePreferences(from: workspace, to: replacement)
            await refreshAfterMutation("Moved \(workspace.name) to \(replacement.name)")
        } catch {
            statusMessage = "Could not remove the previous binding: \(error.localizedDescription)"
            onError?(statusMessage)
        }
        notify()
    }

    @discardableResult
    private func refreshAfterMutation(_ successMessage: String) async -> Bool {
        if await refresh() {
            statusMessage = successMessage
            return true
        } else {
            statusMessage = "\(successMessage). \(statusMessage)"
            onError?(statusMessage)
            return false
        }
    }

    func showMessage(_ message: String) {
        statusMessage = message
        notify()
    }

    /// Marks folders as changing for one binding mutation. Returns false when
    /// another change to one of them is still in flight.
    private func beginChanging(_ paths: [String]) -> Bool {
        guard changingPaths.isDisjoint(with: paths) else {
            showMessage("Wait for the current change to that workspace to finish.")
            return false
        }
        changingPaths.formUnion(paths)
        notify()
        return true
    }

    private func endChanging(_ paths: [String]) {
        changingPaths.subtract(paths)
        notify()
    }

    @discardableResult
    func launch(_ target: LaunchTarget, in destination: OpenDestination) async -> Bool {
        guard launchingID == nil else { return false }
        guard target.isAvailable else {
            showMessage(target.workspace?.availabilityReason ?? "Profile is unavailable")
            return false
        }
        if let workspace = target.workspace, changingPaths.contains(workspace.path) {
            showMessage("\(workspace.name) is being updated. Try again when it finishes.")
            return false
        }
        if let workspace = target.workspace, !workspaces.contains(where: { $0.id == workspace.id }) {
            showMessage("Workspace binding changed. Refresh and choose it again.")
            return false
        }
        launchingID = target.id
        statusMessage = "Opening \(target.name) in \(destination.label)…"
        notify()

        var succeeded = false
        do {
            try await client.launch(target, in: destination)
            if let workspace = target.workspace { remember(workspace) }
            statusMessage = "Opened \(target.name) in \(destination.label)"
            succeeded = true
        } catch {
            statusMessage = error.localizedDescription
            onError?(statusMessage)
        }

        launchingID = nil
        notify()
        return succeeded
    }

    #if TESTING
    func loadPreview(_ bindings: [WorkspaceBinding], profiles previewProfiles: [String]? = nil, usage previewUsage: [String: ProfileUsage] = [:],
                     readingUsage previewReading: Set<String> = [], changingPaths previewChanging: Set<String> = []) {
        workspaces = bindings
        profiles = Array(Set(previewProfiles ?? bindings.filter(\.profileExists).map(\.profile))).sorted()
        usage = previewUsage
        readingUsage = previewReading
        changingPaths = previewChanging
        guardMode = "warn"
        hasLoaded = true
        phase = .ready
        statusMessage = profiles.isEmpty && bindings.isEmpty ? "Create a profile to get started" : "Choose a profile or workspace"
        notify()
    }
    #endif

    private func notify() {
        onChange?()
    }

    private func remember(_ workspace: WorkspaceBinding) {
        var recents = defaults.dictionary(forKey: recentsKey) as? [String: TimeInterval] ?? [:]
        recents[workspace.id] = Date().timeIntervalSince1970
        defaults.set(recents, forKey: recentsKey)
    }

    private func forget(_ workspace: WorkspaceBinding) {
        defaults.set((defaults.stringArray(forKey: pinsKey) ?? []).filter { $0 != workspace.id }, forKey: pinsKey)
        var recents = defaults.dictionary(forKey: recentsKey) as? [String: TimeInterval] ?? [:]
        recents.removeValue(forKey: workspace.id)
        defaults.set(recents, forKey: recentsKey)
    }

    private func movePreferences(from workspace: WorkspaceBinding, to replacement: WorkspaceBinding) {
        guard workspace.id != replacement.id else { return }
        var pins = defaults.stringArray(forKey: pinsKey) ?? []
        if pins.contains(workspace.id) {
            pins.removeAll { $0 == workspace.id }
            if !pins.contains(replacement.id) { pins.append(replacement.id) }
            defaults.set(pins, forKey: pinsKey)
        }
        var recents = defaults.dictionary(forKey: recentsKey) as? [String: TimeInterval] ?? [:]
        if let date = recents.removeValue(forKey: workspace.id) {
            recents[replacement.id] = max(date, recents[replacement.id] ?? 0)
            defaults.set(recents, forKey: recentsKey)
        }
    }

    private func sortByRecency(_ bindings: [WorkspaceBinding]) -> [WorkspaceBinding] {
        let pins = Set(defaults.stringArray(forKey: pinsKey) ?? [])
        let recents = defaults.dictionary(forKey: recentsKey) as? [String: TimeInterval] ?? [:]
        return bindings.enumerated().sorted { lhs, rhs in
            let lhsPinned = pins.contains(lhs.element.id)
            let rhsPinned = pins.contains(rhs.element.id)
            if lhsPinned != rhsPinned { return lhsPinned }
            let lhsDate = recents[lhs.element.id] ?? 0
            let rhsDate = recents[rhs.element.id] ?? 0
            if lhsDate == rhsDate { return lhs.offset < rhs.offset }
            return lhsDate > rhsDate
        }.map(\.element)
    }
}
