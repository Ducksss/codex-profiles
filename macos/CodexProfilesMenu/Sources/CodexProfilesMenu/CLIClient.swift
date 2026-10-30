import Foundation

enum CLIClientError: LocalizedError, Equatable {
    case executableNotFound
    case commandFailed(String)
    case invalidResponse(String)
    case invalidProfileName

    var errorDescription: String? {
        switch self {
        case .executableNotFound:
            "The codex-profile command could not be found. Rebuild the app or install the CLI."
        case let .commandFailed(message):
            message
        case let .invalidResponse(message):
            "Could not read workspace bindings: \(message)"
        case .invalidProfileName:
            "Use letters, numbers, dots, dashes, or underscores. Start with a letter or number."
        }
    }
}

struct CommandResult: Equatable {
    let standardOutput: Data
    let standardError: Data
    let terminationStatus: Int32
}

struct ProcessRunner {
    func run(executableURL: URL, arguments: [String]) async throws -> CommandResult {
        let process = Process()
        let standardOutput = Pipe()
        let standardError = Pipe()

        process.executableURL = executableURL
        process.arguments = arguments
        // Profile-only launches must not inherit a project binding from the
        // directory where the menu app happened to start.
        process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
        process.standardOutput = standardOutput
        process.standardError = standardError

        async let output = read(standardOutput.fileHandleForReading)
        async let error = read(standardError.fileHandleForReading)
        let status: Int32 = try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { completed in
                completed.terminationHandler = nil
                continuation.resume(returning: completed.terminationStatus)
            }
            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                try? standardOutput.fileHandleForWriting.close()
                try? standardError.fileHandleForWriting.close()
                continuation.resume(throwing: error)
            }
        }

        return await CommandResult(
            standardOutput: output,
            standardError: error,
            terminationStatus: status
        )
    }

    private func read(_ handle: FileHandle) async -> Data {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                continuation.resume(returning: handle.readDataToEndOfFile())
            }
        }
    }
}

struct CLIClient: Sendable {
    let executableURL: URL?

    init(executableURL: URL? = CLIClient.discoverExecutable()) {
        self.executableURL = executableURL
    }

    func loadWorkspaces() async throws -> WorkspaceListResponse {
        let executableURL = try requiredExecutableURL()
        return try await Task.detached(priority: .userInitiated) {
            let result = try await ProcessRunner().run(
                executableURL: executableURL,
                arguments: ["workspace", "list", "--json"]
            )

            guard result.terminationStatus == 0 else {
                throw CLIClientError.commandFailed(Self.errorMessage(from: result))
            }

            do {
                return try JSONDecoder().decode(
                    WorkspaceListResponse.self,
                    from: result.standardOutput
                )
            } catch {
                throw CLIClientError.invalidResponse(error.localizedDescription)
            }
        }.value
    }

    /// Every initialized profile's colour and symbol, chosen or automatic.
    func loadAppearances() async throws -> [String: ProfileAppearance] {
        let executableURL = try requiredExecutableURL()
        return try await Task.detached(priority: .userInitiated) {
            let result = try await ProcessRunner().run(executableURL: executableURL, arguments: ["appearance", "--json"])
            guard result.terminationStatus == 0 else {
                throw CLIClientError.commandFailed(Self.errorMessage(from: result))
            }
            return try Self.parseAppearances(result.standardOutput)
        }.value
    }

    /// Saves a profile's colour and symbol with the CLI, which the prompt,
    /// Raycast and launchers also read; nil restores the automatic one.
    func setAppearance(_ appearance: ProfileAppearance?, for profile: String) async throws {
        guard Self.isValidProfileName(profile) else { throw CLIClientError.invalidProfileName }
        let executableURL = try requiredExecutableURL()
        let choice = appearance.map { ["--color", $0.colour.rawValue, "--symbol", $0.symbol.rawValue] } ?? ["--reset"]
        try await Task.detached(priority: .userInitiated) {
            let result = try await ProcessRunner().run(executableURL: executableURL, arguments: ["appearance", profile] + choice)
            guard result.terminationStatus == 0 else {
                throw CLIClientError.commandFailed(Self.errorMessage(from: result))
            }
        }.value
    }

    /// Entries naming a colour or symbol this app does not know are skipped,
    /// so those profiles keep their automatic appearance.
    static func parseAppearances(_ data: Data) throws -> [String: ProfileAppearance] {
        struct Entry: Decodable {
            let profile: String
            let color: String
            let symbol: String
        }
        struct Response: Decodable { let profiles: [Entry] }
        let response: Response
        do {
            response = try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw CLIClientError.commandFailed("Could not read profile appearances: \(error.localizedDescription)")
        }
        var appearances: [String: ProfileAppearance] = [:]
        for entry in response.profiles {
            guard let colour = ProfileAppearance.Colour(rawValue: entry.color),
                  let symbol = ProfileAppearance.Symbol(rawValue: entry.symbol) else { continue }
            appearances[entry.profile] = ProfileAppearance(colour: colour, symbol: symbol)
        }
        return appearances
    }

    func loadProfiles() async throws -> [String] {
        let executableURL = try requiredExecutableURL()
        return try await Task.detached(priority: .userInitiated) {
            let result = try await ProcessRunner().run(
                executableURL: executableURL,
                arguments: ["list"]
            )

            guard result.terminationStatus == 0 else {
                throw CLIClientError.commandFailed(Self.errorMessage(from: result))
            }
            return Self.parseProfiles(result.standardOutput)
        }.value
    }

    func bindWorkspace(path: String, profile: String, force: Bool = false) async throws {
        guard Self.isValidProfileName(profile) else { throw CLIClientError.invalidProfileName }
        let executableURL = try requiredExecutableURL()
        try await Task.detached(priority: .userInitiated) {
            let result = try await ProcessRunner().run(
                executableURL: executableURL,
                arguments: ["workspace", "bind", path, profile] + (force ? ["--force"] : [])
            )

            guard result.terminationStatus == 0 else {
                throw CLIClientError.commandFailed(Self.errorMessage(from: result))
            }
        }.value
    }

    func unbindWorkspace(path: String) async throws {
        let executableURL = try requiredExecutableURL()
        try await Task.detached(priority: .userInitiated) {
            let result = try await ProcessRunner().run(
                executableURL: executableURL,
                arguments: ["workspace", "unbind", path]
            )
            guard result.terminationStatus == 0 else {
                throw CLIClientError.commandFailed(Self.errorMessage(from: result))
            }
        }.value
    }

    func createProfile(_ profile: String) async throws {
        guard Self.isValidProfileName(profile) else { throw CLIClientError.invalidProfileName }
        let executableURL = try requiredExecutableURL()
        try await Task.detached(priority: .userInitiated) {
            let result = try await ProcessRunner().run(
                executableURL: executableURL,
                arguments: ["init", profile]
            )
            guard result.terminationStatus == 0 else {
                throw CLIClientError.commandFailed(Self.errorMessage(from: result))
            }
        }.value
    }

    /// The app asks for the typed name itself, so the CLI's own prompt is skipped.
    func removeProfile(_ profile: String) async throws {
        guard Self.isValidProfileName(profile) else { throw CLIClientError.invalidProfileName }
        let executableURL = try requiredExecutableURL()
        try await Task.detached(priority: .userInitiated) {
            let result = try await ProcessRunner().run(
                executableURL: executableURL,
                arguments: ["remove", profile, "--yes"]
            )
            guard result.terminationStatus == 0 else {
                throw CLIClientError.commandFailed(Self.errorMessage(from: result))
            }
        }.value
    }

    func signInToCLI(_ profile: String) async throws {
        guard Self.isValidProfileName(profile) else { throw CLIClientError.invalidProfileName }
        let executableURL = try requiredExecutableURL()
        try await Task.detached(priority: .userInitiated) {
            let result = try await ProcessRunner().run(
                executableURL: URL(fileURLWithPath: "/usr/bin/osascript"),
                arguments: [
                    "-e",
                    Self.terminalAppleScript,
                    Self.terminalLoginCommand(toolPath: executableURL.path, profile: profile),
                ]
            )
            guard result.terminationStatus == 0 else {
                throw CLIClientError.commandFailed(Self.terminalErrorMessage(from: result))
            }
        }.value
    }

    func launch(_ target: LaunchTarget, in destination: OpenDestination) async throws {
        guard Self.isValidProfileName(target.profile) else { throw CLIClientError.invalidProfileName }
        let executableURL = try requiredExecutableURL()
        try await Task.detached(priority: .userInitiated) {
            switch destination {
            case .chatGPT:
                let result = try await ProcessRunner().run(
                    executableURL: executableURL,
                    arguments: ["app", target.profile] + (target.workspace.map { [$0.path] } ?? [])
                )
                guard result.terminationStatus == 0 else {
                    throw CLIClientError.commandFailed(Self.errorMessage(from: result))
                }
            case .terminal:
                let result = try await ProcessRunner().run(
                    executableURL: URL(fileURLWithPath: "/usr/bin/osascript"),
                    arguments: [
                        "-e",
                        Self.terminalAppleScript,
                        Self.terminalLaunchCommand(
                            toolPath: executableURL.path,
                            profile: target.profile,
                            workspacePath: target.workspace?.path
                                ?? FileManager.default.homeDirectoryForCurrentUser.path
                        ),
                    ]
                )
                guard result.terminationStatus == 0 else {
                    throw CLIClientError.commandFailed(Self.terminalErrorMessage(from: result))
                }
            }
        }.value
    }

    private func requiredExecutableURL() throws -> URL {
        guard let executableURL else { throw CLIClientError.executableNotFound }
        return executableURL
    }

    /// The finished shell command travels as an osascript argument, so no
    /// runtime value is interpolated into AppleScript source.
    static let terminalAppleScript = """
    on run argv
        tell application "Terminal"
            activate
            do script (item 1 of argv)
        end tell
    end run
    """

    static func terminalLaunchCommand(toolPath: String, profile: String, workspacePath: String) -> String {
        "cd \(shellQuote(workspacePath)) && exec \(shellQuote(toolPath)) cli \(shellQuote(profile))"
    }

    static func terminalLoginCommand(toolPath: String, profile: String) -> String {
        "exec \(shellQuote(toolPath)) login \(shellQuote(profile))"
    }

    /// Terminal runs the command in the user's login shell. AppleScript's
    /// `quoted form of` is POSIX-only: fish reads `\'` and `\\` inside single
    /// quotes as escapes, so quotes and backslashes are written outside them.
    static func shellQuote(_ value: String) -> String {
        var quoted = "'"
        for character in value {
            switch character {
            case "'": quoted += "'\\''"
            case "\\": quoted += "'\\\\'"
            default: quoted.append(character)
            }
        }
        return quoted + "'"
    }

    static func isValidProfileName(_ profile: String) -> Bool {
        profile.range(of: "^[A-Za-z0-9][A-Za-z0-9._-]*$", options: .regularExpression)
            == profile.startIndex..<profile.endIndex
    }

    static func discoverExecutable(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        bundle: Bundle = .main,
        fileManager: FileManager = .default
    ) -> URL? {
        var candidates: [URL] = []

        if let override = environment["CODEX_PROFILE_BIN"], !override.isEmpty {
            candidates.append(URL(fileURLWithPath: override))
        }

        if let resourceURL = bundle.resourceURL {
            candidates.append(resourceURL.appendingPathComponent("bin/codex-profile"))
        }

        if let home = environment["HOME"], !home.isEmpty {
            candidates.append(URL(fileURLWithPath: home).appendingPathComponent(".local/bin/codex-profile"))
        }

        candidates.append(URL(fileURLWithPath: "/opt/homebrew/bin/codex-profile"))
        candidates.append(URL(fileURLWithPath: "/usr/local/bin/codex-profile"))

        if let path = environment["PATH"] {
            candidates.append(contentsOf: path.split(separator: ":").map {
                URL(fileURLWithPath: String($0)).appendingPathComponent("codex-profile")
            })
        }

        return candidates.first { candidate in
            var isDirectory: ObjCBool = false
            return fileManager.fileExists(atPath: candidate.path, isDirectory: &isDirectory)
                && !isDirectory.boolValue
                && fileManager.isExecutableFile(atPath: candidate.path)
        }
    }

    static func parseProfiles(_ data: Data) -> [String] {
        guard let output = String(data: data, encoding: .utf8) else { return [] }
        return output
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func errorMessage(from result: CommandResult) -> String {
        let error = String(data: result.standardError, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let output = String(data: result.standardOutput, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let error, !error.isEmpty { return error }
        if let output, !output.isEmpty { return output }
        return "codex-profile exited with status \(result.terminationStatus)."
    }

    /// osascript reports a denied Automation permission as error -1743.
    static func terminalErrorMessage(from result: CommandResult) -> String {
        let message = errorMessage(from: result)
        guard message.contains("(-1743)") || message.localizedCaseInsensitiveContains("not authorized to send apple events") else {
            return message
        }
        return "Codex Profiles isn’t allowed to control Terminal. Turn it on in System Settings › Privacy & Security › Automation, then try again."
    }
}
