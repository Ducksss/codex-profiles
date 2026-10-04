import Foundation

enum OpenDestination: String {
    case chatGPT
    case terminal

    var label: String {
        switch self {
        case .chatGPT: "ChatGPT"
        case .terminal: "Terminal"
        }
    }

    var symbolName: String {
        switch self {
        case .chatGPT: "macwindow"
        case .terminal: "terminal"
        }
    }
}

enum LaunchTarget: Equatable, Identifiable {
    case profile(String)
    case workspace(WorkspaceBinding)

    var workspace: WorkspaceBinding? {
        if case let .workspace(binding) = self { return binding }
        return nil
    }

    var profile: String {
        switch self {
        case let .profile(name): name
        case let .workspace(binding): binding.profile
        }
    }

    var id: String { workspace?.id ?? "profile\u{0}\(profile)" }
    var name: String { workspace?.name ?? profile }
    var isAvailable: Bool { workspace?.isAvailable ?? true }

    func matches(_ query: String) -> Bool {
        if let workspace { return workspace.matches(query) }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || profile.localizedCaseInsensitiveContains(trimmed)
    }
}

struct WorkspaceListResponse: Decodable, Equatable {
    let guardMode: String
    let bindings: [WorkspaceBinding]

    enum CodingKeys: String, CodingKey {
        case guardMode = "guard_mode"
        case bindings
    }
}

struct WorkspaceBinding: Decodable, Equatable, Identifiable {
    let path: String
    let profile: String
    let pathExists: Bool
    let profileExists: Bool

    var id: String { "\(profile)\u{0}\(path)" }
    var isAvailable: Bool { pathExists && profileExists }

    var availabilityReason: String? {
        if !pathExists && !profileExists { return "Folder and profile are missing" }
        if !pathExists { return "Folder is missing" }
        if !profileExists { return "Profile \(profile) is missing" }
        return nil
    }

    var name: String {
        let value = URL(fileURLWithPath: path).lastPathComponent
        return value.isEmpty ? path : value
    }

    enum CodingKeys: String, CodingKey {
        case path
        case profile
        case pathExists = "path_exists"
        case profileExists = "profile_exists"
    }

    func displayPath(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> String {
        let home = homeDirectory.standardizedFileURL.path
        guard path == home || path.hasPrefix(home + "/") else { return path }
        return "~" + path.dropFirst(home.count)
    }

    func matches(_ query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        return name.localizedCaseInsensitiveContains(trimmed)
            || profile.localizedCaseInsensitiveContains(trimmed)
            || path.localizedCaseInsensitiveContains(trimmed)
    }
}
