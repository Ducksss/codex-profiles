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

    var query = "" {
        didSet { notify() }
    }

    var selectedProfile: String? {
        didSet { notify() }
    }

    private(set) var phase: Phase = .idle
    private(set) var workspaces: [WorkspaceBinding] = []
    private(set) var profiles: [String] = []
    private(set) var usage: [String: ProfileUsage] = [:]
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

    var isRefreshingUsage: Bool { usageTask != nil }

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
                for profile in pending { usage[profile] = .loading }
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
                        if profiles.contains(profile) { usage[profile] = result; notify() }
                        if let next = iterator.next() { add(next) }
                    }
                }
                if Task.isCancelled {
                    for profile in pending where usage[profile] == .loading { usage.removeValue(forKey: profile) }
                }
            } while usageRefreshRequested && !Task.isCancelled
            usageTask = nil
            notify()
        }
        usageTask = task
        notify()
        await task.value
    }

    func cancelUsageRefresh() {
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
        guard await bindWorkspace(path: canonicalPath, profile: workspace.profile) else { return }
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

    @discardableResult
    func launch(_ target: LaunchTarget, in destination: OpenDestination) async -> Bool {
        guard launchingID == nil else { return false }
        guard target.isAvailable else {
            showMessage(target.workspace?.availabilityReason ?? "Profile is unavailable")
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
    func loadPreview(_ bindings: [WorkspaceBinding], profiles previewProfiles: [String]? = nil, usage previewUsage: [String: ProfileUsage] = [:]) {
        workspaces = bindings
        profiles = Array(Set(previewProfiles ?? bindings.filter(\.profileExists).map(\.profile))).sorted()
        usage = previewUsage
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
