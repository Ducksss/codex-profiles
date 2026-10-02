import Foundation

@main
@MainActor
struct CodexProfilesMenuTests {
    static func main() async throws {
        try testDecodesWorkspaceListResponse()
        testSearchMatchesNameProfileAndPath()
        testDisplayPathAbbreviatesOnlyTheHomeDirectory()
        testTerminalScriptQuotesRuntimeArgumentsInsteadOfInterpolatingThem()
        testParsesProfiles()
        testAvailabilityReasons()
        try await testStoreFilteringPinsAndRecents()
        try await testRefreshPreservesContentAndSerializesRequests()
        try await testMutationsAndLaunchResults()
        testProfileNames()
        try await testProcessDrainsBothStreams()
        try await testProcessTerminationAndLaunchFailure()
        try await testCreatesAndBindsWithRealCLI()
        try await testErrorsRemainActionable()
        try await testTerminalCommandsPreserveArguments()
        print("CodexProfilesMenu unit tests passed.")
    }

    private static func testDecodesWorkspaceListResponse() throws {
        let json = """
        {
          "guard_mode": "warn",
          "bindings": [
            {
              "path": "/Users/test/Dev/codex-profiles",
              "profile": "work-main",
              "path_exists": true,
              "profile_exists": true
            }
          ]
        }
        """

        let response = try JSONDecoder().decode(
            WorkspaceListResponse.self,
            from: Data(json.utf8)
        )

        expect(response.guardMode == "warn", "guard mode was not decoded")
        expect(response.bindings.count == 1, "binding count was not decoded")
        expect(response.bindings[0].name == "codex-profiles", "workspace name was not derived")
        expect(response.bindings[0].isAvailable, "available binding was marked unavailable")
    }

    private static func testSearchMatchesNameProfileAndPath() {
        let binding = WorkspaceBinding(
            path: "/Users/test/Dev/client-dashboard",
            profile: "consulting",
            pathExists: true,
            profileExists: true
        )

        expect(binding.matches("dashboard"), "search did not match workspace name")
        expect(binding.matches("CONSULT"), "search did not match profile")
        expect(binding.matches("/Dev/client"), "search did not match path")
        expect(binding.matches("   "), "blank search did not match")
        expect(!binding.matches("personal"), "unrelated search matched")
    }

    private static func testDisplayPathAbbreviatesOnlyTheHomeDirectory() {
        let home = URL(fileURLWithPath: "/Users/test")
        let inside = WorkspaceBinding(
            path: "/Users/test/Dev/project",
            profile: "work",
            pathExists: true,
            profileExists: true
        )
        let outside = WorkspaceBinding(
            path: "/Users/testing/project",
            profile: "work",
            pathExists: true,
            profileExists: true
        )

        expect(inside.displayPath(homeDirectory: home) == "~/Dev/project", "home path was not abbreviated")
        expect(outside.displayPath(homeDirectory: home) == "/Users/testing/project", "path prefix was over-abbreviated")
    }

    private static func testTerminalScriptQuotesRuntimeArgumentsInsteadOfInterpolatingThem() {
        let script = CLIClient.terminalAppleScript

        expect(script.contains("quoted form of workspacePath"), "workspace path is not shell quoted")
        expect(script.contains("quoted form of toolPath"), "tool path is not shell quoted")
        expect(script.contains("quoted form of profileName"), "profile is not shell quoted")
        expect(!script.contains("/Users/test"), "runtime path was interpolated into AppleScript")
    }

    private static func testParsesProfiles() {
        let profiles = CLIClient.parseProfiles(Data("default\npersonal\nwork\n".utf8))
        expect(profiles == ["default", "personal", "work"], "profiles were not parsed")
    }

    private static func testProfileNames() {
        for name in ["default", "work", "Work-2", "a.b_c"] {
            expect(CLIClient.isValidProfileName(name), "valid profile was rejected: \(name)")
        }
        for name in ["", "-work", ".work", "../work", "work name", "work\n", "work;echo", "é"] {
            expect(!CLIClient.isValidProfileName(name), "invalid profile was accepted: \(name)")
        }
    }

    private static func testProcessDrainsBothStreams() async throws {
        let result = try await ProcessRunner().run(
            executableURL: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", "dd if=/dev/zero bs=1024 count=2048 2>/dev/null; dd if=/dev/zero bs=1024 count=2048 >&2 2>/dev/null"]
        )
        expect(result.terminationStatus == 0, "large-output process failed")
        expect(result.standardOutput.count == 2 * 1024 * 1024, "stdout was truncated")
        expect(result.standardError.count == 2 * 1024 * 1024, "stderr was truncated")
    }

    private static func testProcessTerminationAndLaunchFailure() async throws {
        for _ in 0..<20 {
            let result = try await ProcessRunner().run(executableURL: URL(fileURLWithPath: "/usr/bin/true"), arguments: [])
            expect(result.terminationStatus == 0, "immediately exiting process failed")
        }
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        do {
            _ = try await ProcessRunner().run(executableURL: fixture.url("missing-executable"), arguments: [])
            expect(false, "missing executable was launched")
        } catch {
            expect(!error.localizedDescription.isEmpty, "process launch failure omitted its error")
        }
    }

    private static func testCreatesAndBindsWithRealCLI() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let cliPath = environment["PROFILE_TEST_CLI"], let home = environment["HOME"],
              home.hasPrefix(environment["PROFILE_TEST_TMP"] ?? "missing") else {
            throw CLIClientError.commandFailed("Tests require an isolated HOME and PROFILE_TEST_CLI.")
        }
        let client = CLIClient(executableURL: URL(fileURLWithPath: cliPath))
        let suite = "CodexProfilesMenuTests.realCLI." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = WorkspaceStore(client: client, defaults: defaults)
        let loaded = await store.refresh()
        expect(loaded && store.profiles.isEmpty && store.workspaces.isEmpty, "first run was not empty")
        let created = await store.createProfile("work-main")
        expect(created && store.profiles == ["work-main"], "profile creation did not refresh the GUI")
        let profileHome = URL(fileURLWithPath: home).appendingPathComponent(".codex-work-main")
        let permissions = try FileManager.default.attributesOfItem(atPath: profileHome.path)[.posixPermissions] as? NSNumber
        expect(permissions?.intValue == 0o700, "created profile is not private")

        let folder = URL(fileURLWithPath: home).appendingPathComponent("project ' \"$HOME\" ; space")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let bound = await store.bindWorkspace(path: folder.path, profile: "work-main")
        expect(bound && store.workspaces.count == 1, "new profile's folder was not bound")
        let requestedAttributes = try FileManager.default.attributesOfItem(atPath: folder.path)
        let boundAttributes = try FileManager.default.attributesOfItem(atPath: store.workspaces[0].path)
        expect(requestedAttributes[.systemNumber] is NSNumber
            && requestedAttributes[.systemFileNumber] is NSNumber,
            "filesystem did not expose directory identity")
        expect(requestedAttributes[.systemNumber] as? NSNumber == boundAttributes[.systemNumber] as? NSNumber
            && requestedAttributes[.systemFileNumber] as? NSNumber == boundAttributes[.systemFileNumber] as? NSNumber,
            "folder arguments changed")
        expect(store.workspaces[0].profile == "work-main" && store.workspaces[0].isAvailable, "binding is unavailable")

        let defaultCreated = await store.createProfile("default")
        expect(defaultCreated && store.profiles.contains("default"), "default could not be initialized")
        let existingCreated = await store.createProfile("work-main")
        expect(existingCreated && store.workspaces.count == 1, "existing profile creation lost its workspace")
        await expectFailure({ try await client.createProfile("../escape") }, containing: "Start with a letter or number")
        await expectFailure({ try await client.bindWorkspace(path: folder.path, profile: "default") }, containing: "already bound")
        let bindings = try await client.loadWorkspaces()
        expect(bindings.bindings[0].profile == "work-main", "binding conflict replaced the existing profile")
        await expectFailure({ try await client.bindWorkspace(path: folder.appendingPathComponent("missing").path, profile: "default") }, containing: "directory")

        let previous = store.workspaces[0]
        store.togglePin(previous)
        defaults.set([previous.id: 123.0], forKey: "workspaceRecents")
        let movedFolder = URL(fileURLWithPath: home).appendingPathComponent("moved ' \"$HOME\" ; space")
        try FileManager.default.createDirectory(at: movedFolder, withIntermediateDirectories: true)
        await store.relocateWorkspace(previous, to: movedFolder.path)
        expect(store.workspaces.count == 1 && store.workspaces[0].name == movedFolder.lastPathComponent, "real CLI relocation did not replace the old folder through its canonical alias")
        let moved = store.workspaces[0]
        expect(store.isPinned(moved) && !store.isPinned(previous), "real relocation lost pin preferences")
        let recents = defaults.dictionary(forKey: "workspaceRecents") as? [String: TimeInterval]
        expect(recents?[moved.id] == 123.0 && recents?[previous.id] == nil, "real relocation lost recent preferences")
    }

    private static func testErrorsRemainActionable() async throws {
        let failure = try executable("failure", body: "printf 'Cannot create directory: choose another profile\\n' >&2\nexit 7\n")
        let store = WorkspaceStore(client: CLIClient(executableURL: failure))
        var presentedError: String?
        store.onError = { presentedError = $0 }
        let created = await store.createProfile("work")
        expect(!created, "failed profile creation reported success")
        expect(presentedError == "Cannot create directory: choose another profile", "native alert lost the remedy")
        expect(store.statusMessage == presentedError, "footer lost the full error")
        await expectFailure({ _ = try await CLIClient(executableURL: nil).loadProfiles() }, containing: "could not be found")

        let refreshFailure = try executable("refresh-failure", body: """
        case "$1 $2" in
          'workspace list') printf '%s\\n' '{"guard_mode":"warn","bindings":[]}' ;;
          'list ') printf 'Refresh failed: repair local state\\n' >&2; exit 9 ;;
        esac
        """)
        let failedRefreshStore = WorkspaceStore(client: CLIClient(executableURL: refreshFailure))
        let bound = await failedRefreshStore.bindWorkspace(path: "/unused", profile: "work")
        expect(!bound, "failed refresh reported binding success")
        expect(failedRefreshStore.phase == .failed("Refresh failed: repair local state"), "refresh failure was hidden")
        expect(failedRefreshStore.statusMessage.contains("Refresh failed: repair local state"), "refresh failure lost its remedy")
    }

    private static func testTerminalCommandsPreserveArguments() async throws {
        let probe = try executable("tool ' \"$HOME\" `echo bad` ;", body: "printf '%s\\n' \"$PWD\" \"$@\"\n")
        let folder = probe.deletingLastPathComponent().appendingPathComponent("folder ' \"$HOME\" $(echo bad) ;")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for (script, command, arguments) in [
            (CLIClient.terminalAppleScript, "launchCommand", [probe.path, "work-main", folder.path]),
            (CLIClient.terminalLoginAppleScript, "loginCommand", [probe.path, "default"]),
        ] {
            let commandScript = script.replacingOccurrences(
                of: "tell application \"Terminal\"\n        activate\n        do script \(command)\n    end tell",
                with: "return \(command)"
            )
            expect(!commandScript.contains("tell application"), "test would invoke Terminal")
            let generated = try await ProcessRunner().run(
                executableURL: URL(fileURLWithPath: "/usr/bin/osascript"),
                arguments: ["-e", commandScript] + arguments
            )
            expect(generated.terminationStatus == 0, "AppleScript did not parse")
            guard let shellCommand = String(data: generated.standardOutput, encoding: .utf8) else {
                throw CLIClientError.invalidResponse("AppleScript did not return a command")
            }
            let executed = try await ProcessRunner().run(
                executableURL: URL(fileURLWithPath: "/bin/sh"),
                arguments: ["-c", shellCommand]
            )
            expect(executed.terminationStatus == 0, "quoted command could not execute")
            let output = String(data: executed.standardOutput, encoding: .utf8) ?? ""
            if command == "launchCommand" {
                expect(output == "\(folder.path)\ncli\nwork-main\n", "workspace or CLI arguments were shell interpreted")
            } else {
                expect(output.hasSuffix("\nlogin\ndefault\n"), "login command arguments changed")
            }
        }
    }

    private static func executable(_ name: String, body: String) throws -> URL {
        guard let temp = ProcessInfo.processInfo.environment["PROFILE_TEST_TMP"] else {
            throw CLIClientError.commandFailed("PROFILE_TEST_TMP is required")
        }
        let path = URL(fileURLWithPath: temp).appendingPathComponent(name)
        try Data(("#!/bin/sh\n" + body).utf8).write(to: path)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: path.path)
        return path
    }

    private static func expectFailure(_ operation: () async throws -> Void, containing message: String) async {
        do {
            try await operation()
            expect(false, "operation unexpectedly succeeded")
        } catch {
            expect(error.localizedDescription.contains(message), "failure was not actionable: \(error.localizedDescription)")
        }
    }

    private static func testAvailabilityReasons() {
        expect(binding("ready", "work").availabilityReason == nil, "available workspace has an error")
        expect(binding("missing", "work", pathExists: false).availabilityReason == "Folder is missing", "missing folder reason was lost")
        expect(binding("missing", "work", profileExists: false).availabilityReason == "Profile work is missing", "missing profile reason was lost")
        expect(binding("missing", "work", pathExists: false, profileExists: false).availabilityReason == "Folder and profile are missing", "combined availability error was lost")
    }

    private static func testStoreFilteringPinsAndRecents() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        let alpha = binding("alpha", "work")
        let beta = binding("beta", "personal")
        let gamma = binding("gamma", "work")
        try fixture.writeWorkspaces([alpha, beta, gamma])
        fixture.defaults.set([gamma.id: 200.0, beta.id: 100.0], forKey: "workspaceRecents")
        let store = fixture.store()
        expect(await store.refresh(), "store did not refresh")
        expect(store.guardMode == "warn", "workspace guard mode was not retained")
        expect(store.filteredWorkspaces == [gamma, beta, alpha], "recent workspaces were not ordered")
        store.togglePin(alpha)
        expect(store.filteredWorkspaces == [alpha, gamma, beta], "pinned workspace did not precede recents")
        let restored = fixture.store()
        await restored.refresh()
        expect(restored.isPinned(alpha), "pin was not persisted")
        expect(restored.filteredWorkspaces == [alpha, gamma, beta], "restored pin ordering differs")
        restored.selectedProfile = "work"
        restored.query = "ALPHA"
        expect(restored.filteredWorkspaces == [alpha], "profile and search filters were not combined")
        restored.query = "beta"
        expect(restored.filteredWorkspaces.isEmpty, "search bypassed the selected profile")
        restored.selectedProfile = nil
        expect(restored.filteredWorkspaces == [beta], "clearing profile filter did not restore search result")
        restored.query = ""
        restored.togglePin(alpha)
        expect(restored.filteredWorkspaces == [gamma, beta, alpha], "unpin did not restore recency ordering")
        fixture.defaults.removeObject(forKey: "workspaceRecents")
        expect(restored.filteredWorkspaces == [alpha, beta, gamma], "equal recents changed registry order")
    }

    private static func testRefreshPreservesContentAndSerializesRequests() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        let alpha = binding("alpha", "work")
        try fixture.writeWorkspaces([alpha])
        let store = fixture.store()
        await store.refresh()
        store.selectedProfile = "work"
        try fixture.write("", to: "hold-refresh")
        try FileManager.default.removeItem(at: fixture.url("refresh-started"))
        let first = Task { await store.refresh() }
        try await waitForFile(fixture.url("refresh-started"))
        expect(store.isRefreshing, "refresh activity was not exposed")
        expect(store.phase == .ready && store.workspaces == [alpha], "refresh hid previously loaded content")
        var secondRequested = false
        let second = Task {
            secondRequested = true
            return await store.refresh()
        }
        while !secondRequested { await Task.yield() }
        try FileManager.default.removeItem(at: fixture.url("hold-refresh"))
        let firstSucceeded = await first.value
        let secondSucceeded = await second.value
        expect(firstSucceeded && secondSucceeded, "queued refresh did not finish")
        expect(!FileManager.default.fileExists(atPath: fixture.url("refresh-overlap").path), "workspace loads overlapped")
        expect(try fixture.read("refresh-calls").split(whereSeparator: \.isNewline).count == 3, "overlapping requests did not produce one serial reload")
        expect(store.selectedProfile == "work", "valid profile filter was cleared")
        try fixture.write("registry unavailable", to: "refresh-error")
        expect(!(await store.refresh()), "failed refresh reported success")
        expect(store.phase == .ready && store.workspaces == [alpha], "failed refresh discarded loaded content")
        expect(!store.isRefreshing && store.statusMessage.contains("registry unavailable"), "refresh error was not visible")
        try FileManager.default.removeItem(at: fixture.url("refresh-error"))
        store.selectedProfile = "personal"
        try fixture.write("default\nwork\n", to: "profiles")
        await store.refresh()
        expect(store.selectedProfile == nil, "removed profile filter was retained")
        try fixture.write("not json", to: "workspaces.json")
        expect(!(await store.refresh()), "invalid JSON was accepted")
        expect(store.workspaces == [alpha] && store.statusMessage.contains("Could not read workspace bindings"), "invalid JSON lost content or useful error")
        let missingCLI = WorkspaceStore(client: CLIClient(executableURL: nil), defaults: fixture.defaults)
        expect(!(await missingCLI.refresh()), "missing CLI reported success")
        if case .failed = missingCLI.phase {} else { expect(false, "initial failure did not expose failure phase") }
    }

    private static func testMutationsAndLaunchResults() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        let alpha = binding("O'Brien workspace", "work")
        let beta = binding("beta", "personal")
        let reassigned = binding("O'Brien workspace", "personal")
        try fixture.writeWorkspaces([alpha, beta])
        let store = fixture.store()
        await store.refresh()
        store.togglePin(alpha)
        expect(await store.launch(alpha, in: .chatGPT), "successful launch reported failure")
        expect(store.launchingID == nil && store.statusMessage.contains("Opened"), "launch did not clear activity or report outcome")
        try fixture.writeWorkspaces([reassigned, beta], to: "next-workspaces.json")
        await store.rebindWorkspace(alpha, to: "personal")
        expect(store.workspaces == [reassigned, beta], "rebind did not reload bindings")
        expect(store.isPinned(reassigned) && !store.isPinned(alpha), "rebind did not preserve pin on the replacement binding")
        let recents = fixture.defaults.dictionary(forKey: "workspaceRecents") as? [String: TimeInterval]
        expect(recents?[reassigned.id] != nil && recents?[alpha.id] == nil, "rebind did not preserve recency")
        expect(try fixture.read("arguments").contains("workspace\u{0}bind\u{0}\(alpha.path)\u{0}personal\u{0}--force\u{0}\n"), "rebind did not pass exact runtime arguments with --force")
        try fixture.write("binding locked", to: "mutation-error")
        await store.rebindWorkspace(reassigned, to: "work")
        expect(store.workspaces == [reassigned, beta] && store.statusMessage == "binding locked", "failed mutation changed bindings or hid the error")
        try FileManager.default.removeItem(at: fixture.url("mutation-error"))
        try fixture.writeWorkspaces([beta], to: "next-workspaces.json")
        await store.unbindWorkspace(reassigned)
        expect(store.workspaces == [beta] && !store.isPinned(reassigned), "unbind did not reload or clear pin")
        let unbindArguments = try fixture.read("arguments")
        expect(store.statusMessage.contains("Removed") && unbindArguments.contains("workspace\u{0}unbind\u{0}\(alpha.path)\u{0}\n"), "unbind outcome or arguments were wrong")
        try fixture.writeWorkspaces([alpha, beta], to: "next-workspaces.json")
        await store.bindWorkspace(path: alpha.path, profile: "work")
        expect(store.workspaces == [alpha, beta] && store.statusMessage == "Workspace added to work", "add did not reload bindings or report outcome")
        try fixture.write("launch failed", to: "launch-error")
        var launchError: String?
        store.onError = { launchError = $0 }
        expect(!(await store.launch(alpha, in: .chatGPT)), "failed launch reported success")
        expect(store.launchingID == nil && store.statusMessage == "launch failed", "failed launch left activity or hid error")
        expect(launchError == "launch failed", "failed launch did not present its full error")
        let stale = binding("missing", "work", pathExists: false)
        let argumentsBefore = try fixture.read("arguments")
        expect(!(await store.launch(stale, in: .chatGPT)), "missing folder was launched")
        expect(try fixture.read("arguments") == argumentsBefore, "unavailable workspace invoked a process")
        let moved = binding("relocated", "work")
        store.togglePin(alpha)
        fixture.defaults.set([alpha.id: 123.0], forKey: "workspaceRecents")
        try fixture.write("new folder refused", to: "mutation-error")
        await store.relocateWorkspace(alpha, to: moved.path)
        expect(store.workspaces == [alpha, beta] && store.isPinned(alpha), "failed relocate discarded the old binding or pin")
        expect((fixture.defaults.dictionary(forKey: "workspaceRecents") as? [String: TimeInterval])?[alpha.id] == 123.0, "failed relocate changed recency")
        try FileManager.default.removeItem(at: fixture.url("mutation-error"))
        try fixture.writeWorkspaces([alpha, moved, beta], to: "next-workspaces.json")
        try fixture.writeWorkspaces([moved, beta], to: "next-unbound-workspaces.json")
        await store.relocateWorkspace(alpha, to: moved.path)
        expect(store.workspaces == [moved, beta] && store.statusMessage.contains("Moved"), "relocate did not replace the old binding")
        expect(store.isPinned(moved) && !store.isPinned(alpha), "relocate did not preserve the pin")
        let movedRecents = fixture.defaults.dictionary(forKey: "workspaceRecents") as? [String: TimeInterval]
        expect(movedRecents?[moved.id] == 123.0 && movedRecents?[alpha.id] == nil, "relocate did not preserve recency")
        try fixture.write("refresh failed after remove", to: "refresh-error")
        await store.unbindWorkspace(moved)
        expect(store.workspaces == [moved, beta], "post-mutation refresh failure discarded loaded content")
        expect(store.statusMessage.contains("Removed") && store.statusMessage.contains("refresh failed after remove"), "successful mutation with failed reload lost either outcome")
        do {
            try await CLIClient(executableURL: fixture.executable).bindWorkspace(path: alpha.path, profile: "--bad")
            expect(false, "invalid profile name was accepted")
        } catch CLIClientError.invalidProfileName {} catch { expect(false, "invalid profile produced unexpected error") }
    }

    private static func binding(_ name: String, _ profile: String, pathExists: Bool = true, profileExists: Bool = true) -> WorkspaceBinding {
        WorkspaceBinding(path: "/Users/test/Dev/" + name, profile: profile, pathExists: pathExists, profileExists: profileExists)
    }

    private static func waitForFile(_ url: URL) async throws {
        let deadline = Date().addingTimeInterval(5)
        while !FileManager.default.fileExists(atPath: url.path) {
            expect(Date() < deadline, "fake command did not reach the expected state")
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    private struct Fixture {
        let root: URL
        let defaults: UserDefaults
        let suite: String
        var executable: URL { url("codex-profile") }

        init() throws {
            root = FileManager.default.temporaryDirectory.appendingPathComponent("CodexProfilesMenuTests-" + UUID().uuidString)
            suite = "CodexProfilesMenuTests." + UUID().uuidString
            defaults = UserDefaults(suiteName: suite)!
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try write("default\npersonal\nwork\n", to: "profiles")
            try write(#"""
            #!/bin/sh
            fixture=$(dirname "$0")
            printf '%s\0' "$@" >> "$fixture/arguments"
            printf '\n' >> "$fixture/arguments"
            case "$1:${2:-}" in
              workspace:list)
                if ! mkdir "$fixture/refresh-active" 2>/dev/null; then touch "$fixture/refresh-overlap"; fi
                trap 'rmdir "$fixture/refresh-active" 2>/dev/null' EXIT
                printf 'refresh\n' >> "$fixture/refresh-calls"
                touch "$fixture/refresh-started"
                count=0
                while [ -f "$fixture/hold-refresh" ] && [ "$count" -lt 500 ]; do
                  sleep 0.01
                  count=$((count + 1))
                done
                if [ -f "$fixture/refresh-error" ]; then cat "$fixture/refresh-error" >&2; exit 1; fi
                cat "$fixture/workspaces.json"
                ;;
              list:*) cat "$fixture/profiles" ;;
              workspace:bind|workspace:unbind)
                if [ -f "$fixture/mutation-error" ]; then cat "$fixture/mutation-error" >&2; exit 1; fi
                if [ "$2" = unbind ] && [ -f "$fixture/next-unbound-workspaces.json" ]; then
                  cp "$fixture/next-unbound-workspaces.json" "$fixture/workspaces.json"
                elif [ -f "$fixture/next-workspaces.json" ]; then
                  cp "$fixture/next-workspaces.json" "$fixture/workspaces.json"
                fi
                ;;
              app:*)
                if [ -f "$fixture/launch-error" ]; then cat "$fixture/launch-error" >&2; exit 1; fi
                ;;
              *) printf 'unexpected command\n' >&2; exit 1 ;;
            esac
            """#, to: "codex-profile")
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        }

        func url(_ name: String) -> URL { root.appendingPathComponent(name) }
        func write(_ value: String, to name: String) throws { try Data(value.utf8).write(to: url(name)) }
        func read(_ name: String) throws -> String { try String(contentsOf: url(name), encoding: .utf8) }
        @MainActor func store() -> WorkspaceStore { WorkspaceStore(client: CLIClient(executableURL: executable), defaults: defaults) }
        func cleanup() {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: root)
        }

        func writeWorkspaces(_ bindings: [WorkspaceBinding], to name: String = "workspaces.json") throws {
            let rows = bindings.map { binding in
                ["path": binding.path, "profile": binding.profile, "path_exists": binding.pathExists, "profile_exists": binding.profileExists] as [String: Any]
            }
            let data = try JSONSerialization.data(withJSONObject: ["guard_mode": "warn", "bindings": rows])
            try data.write(to: url(name))
        }
    }

    private static func expect(_ condition: Bool, _ message: String) {
        guard condition else {
            FileHandle.standardError.write(Data("Test failed: \(message)\n".utf8))
            exit(1)
        }
    }
}
