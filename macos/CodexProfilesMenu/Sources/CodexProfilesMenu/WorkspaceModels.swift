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
