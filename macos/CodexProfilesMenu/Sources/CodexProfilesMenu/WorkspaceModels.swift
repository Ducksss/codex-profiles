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

    /// Where Command-Return and Command-click open instead.
    var alternate: OpenDestination { self == .chatGPT ? .terminal : .chatGPT }
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

/// A profile's colour and symbol in the menu, so profiles are told apart at a
/// glance. The palette leaves out red, orange and yellow, which mean low quota.
struct ProfileAppearance: Equatable {
    enum Colour: String, CaseIterable {
        case blue, indigo, purple, pink, teal, green, brown, graphite

        var label: String { rawValue.capitalized }

        /// sRGB components. White symbols keep at least 4.5:1 contrast on each,
        /// which a unit test checks.
        var components: (red: Double, green: Double, blue: Double) {
            switch self {
            case .blue: (0.039, 0.424, 0.859)
            case .indigo: (0.306, 0.298, 0.769)
            case .purple: (0.537, 0.267, 0.671)
            case .pink: (0.780, 0.145, 0.357)
            case .teal: (0.043, 0.478, 0.518)
            case .green: (0.141, 0.522, 0.231)
            case .brown: (0.525, 0.400, 0.290)
            case .graphite: (0.451, 0.451, 0.471)
            }
        }
    }

    enum Symbol: String, CaseIterable {
        case monogram, person, house, briefcase, building, book, flask, code, terminal, globe, leaf, bolt

        var label: String {
            switch self {
            case .monogram: "Initial"
            case .code: "Code brackets"
            default: rawValue.capitalized
            }
        }

        /// The SF Symbol, or nil for the profile's initial.
        var systemName: String? {
            switch self {
            case .monogram: nil
            case .building: "building.2"
            case .code: "chevron.left.forwardslash.chevron.right"
            default: rawValue
            }
        }
    }

    var colour: Colour
    var symbol: Symbol

    /// Before a choice: graphite for `default`, the stock ChatGPT session, and
    /// otherwise a colour derived from the name, so it stays the same on every
    /// launch and does not shift when other profiles are added.
    static func automatic(for profile: String) -> Self {
        guard profile != "default" else { return Self(colour: .graphite, symbol: .monogram) }
        let choices = Colour.allCases.filter { $0 != .graphite }
        // FNV-1a, because Swift's hashValue changes between launches.
        var hash: UInt32 = 2_166_136_261
        for byte in profile.utf8 { hash = (hash ^ UInt32(byte)) &* 16_777_619 }
        return Self(colour: choices[Int(hash % UInt32(choices.count))], symbol: .monogram)
    }
}
