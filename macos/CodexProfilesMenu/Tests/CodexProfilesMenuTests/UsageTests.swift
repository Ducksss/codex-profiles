import Darwin
import Foundation

@MainActor
enum UsageTests {
    static func run() async throws {
        try decodingAndFreshness()
        lineFraming()
        summariesAndResetTimes()
        print("Checking usage handshake and isolation…")
        try await handshakeAndIsolation()
        print("Checking usage failure and cancellation cleanup…")
        try await failuresAndCleanup()
        print("Checking usage refresh caching and concurrency…")
        try await refreshCachingAndConcurrency()
        print("Checking usage through the real profile wrapper…")
        try await realWrapperRespectsProfileAndGuard()
        print("Per-profile usage protocol, cache and cleanup tests passed.")
    }

    private static let response = #"{"rateLimits":{"primary":{"usedPercent":55}},"rateLimitsByLimitId":{"codex":{"limitId":"codex","primary":{"usedPercent":23,"windowDurationMins":300,"resetsAt":4102444800},"secondary":{"usedPercent":91,"windowDurationMins":10080,"resetsAt":4102444800}},"code_reviews":{"primary":{"usedPercent":100}}}}"#

    private static func decodingAndFreshness() throws {
        let limits = try CodexRateLimits.decode(Data(response.utf8))
        expect(limits.windows.map(\.remainingPercent) == [77, 9], "the Codex bucket must win over legacy and code-review limits")
        expect(limits.windows.map(\.durationLabel) == ["5h", "7d"], "labels must use the reported window durations")
        let legacy = try CodexRateLimits.decode(Data(#"{"rateLimits":{"primary":{"usedPercent":100,"windowDurationMins":15},"secondary":null},"rateLimitsByLimitId":null}"#.utf8))
        expect(legacy.windows.count == 1 && legacy.windows[0].durationLabel == "15m" && legacy.windows[0].remainingPercent == 0,
            "legacy single-window responses and an exhausted quota must remain usable")
        let unknown = try CodexRateLimits.decode(Data(#"{"rateLimits":{"primary":{"usedPercent":12.4,"windowDurationMins":null,"resetsAt":null}}}"#.utf8))
        expect(unknown.windows[0].durationLabel == nil && unknown.windows[0].remainingPercent == 87,
            "missing durations must not become a guessed 5h window or overstate remaining quota")
        for json in [#"{"rateLimits":{"primary":null,"secondary":null}}"#,
                     #"{"rateLimits":{"primary":{"windowDurationMins":300}}}"#,
                     #"{"rateLimits":{"limitId":"code_reviews","primary":{"usedPercent":1}}}"#] {
            do { _ = try CodexRateLimits.decode(Data(json.utf8)); fatalError("missing or unrelated quotas were accepted") }
            catch {}
        }
        expect(RateLimitWindow(usedPercent: -12, windowDurationMins: 90, resetsAt: nil).remainingPercent == 100,
            "remaining quota must not exceed 100 percent")
        expect(RateLimitWindow(usedPercent: 112, windowDurationMins: 90, resetsAt: nil).remainingPercent == 0,
            "remaining quota must not become negative")
        let now = Date(timeIntervalSince1970: 1000)
        let cached = ProfileUsage.available(limits, checkedAt: now)
        expect(!cached.needsRefresh(at: now.addingTimeInterval(59)), "reopening should reuse a fresh reading")
        expect(cached.needsRefresh(at: now.addingTimeInterval(60)), "the next open must refresh after 60 seconds")
        let expired = ProfileUsage.available(CodexRateLimits(windows: [RateLimitWindow(usedPercent: 90, windowDurationMins: 300, resetsAt: 1001)]), checkedAt: now)
        expect(expired.needsRefresh(at: now.addingTimeInterval(2)), "a reset must invalidate cached usage")
        let expiredDetail = UsageState(reading: expired).detail(at: now.addingTimeInterval(2))
        expect(expiredDetail.contains("Awaiting a fresh reading") && expiredDetail.contains("Reset at") && !expiredDetail.contains("Resets in"),
            "a passed reset must not invent restored quota or a future reset")
        expect(unknown.windows[0].resetsAt == nil && UsageState(reading: .available(unknown, checkedAt: now)).detail(at: now).contains("Reset time unavailable"),
            "missing reset times must have an honest description")
        expect(ProfileUsage.unavailable(checkedAt: now).needsRefresh(at: now.addingTimeInterval(60)), "unavailable profiles must be retried")
    }

    private static func lineFraming() {
        var lines = LineBuffer(limit: 64)
        expect(lines.append(Array(#"{"id":1}"#.utf8)[...]) && lines.next() == nil, "a partial line must wait for its newline")
        expect(lines.append(Array("\n{\"id\":2}\n{\"i".utf8)[...]), "chunks within the limit must be accepted")
        expect(lines.next() == Data(#"{"id":1}"#.utf8) && lines.next() == Data(#"{"id":2}"#.utf8) && lines.next() == nil,
            "lines split across and within chunks must be framed exactly once")
        expect(lines.append(Array("d\":3}\n".utf8)[...]) && lines.next() == Data(#"{"id":3}"#.utf8), "a line resumed after compaction lost bytes")
        var bounded = LineBuffer(limit: 8)
        expect(bounded.append(Array("12345678".utf8)[...]) && !bounded.append(Array("9".utf8)[...]),
            "output beyond the limit must be refused even without a newline")
    }

    private static func summariesAndResetTimes() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        func window(_ remaining: Double, _ minutes: Int?, resetIn seconds: TimeInterval?) -> RateLimitWindow {
            RateLimitWindow(usedPercent: 100 - remaining, windowDurationMins: minutes, resetsAt: seconds.map { now.timeIntervalSince1970 + $0 })
        }
        func state(_ windows: RateLimitWindow...) -> UsageState {
            UsageState(reading: .available(CodexRateLimits(windows: windows), checkedAt: now))
        }
        expect([QuotaLevel(remainingPercent: 26), QuotaLevel(remainingPercent: 25), QuotaLevel(remainingPercent: 10), QuotaLevel(remainingPercent: 0)]
            == [.normal, .low, .critical, .critical], "quota levels changed their thresholds")
        expect(state(window(80, 300, resetIn: 600), window(60, 10080, resetIn: 86400)).summary(at: now) == nil,
            "healthy quota must keep the destination description")
        expect(state(window(20, 300, resetIn: 4320), window(60, 10080, resetIn: 86400)).summary(at: now) == "5h limit low · resets in 1h 12m",
            "a low window must summarise its countdown")
        expect(state(window(0, 300, resetIn: 600), window(0, 10080, resetIn: 90000)).summary(at: now) == "7d limit reached · resets in 1d 1h",
            "with every window exhausted, the later reset decides when Codex is usable")
        expect(state(window(5, 300, resetIn: -1), window(70, 10080, resetIn: 9000)).summary(at: now) == nil,
            "an expired window must not be summarised as low")
        expect(state(window(5, nil, resetIn: nil)).summary(at: now) == "Limit low", "missing durations and reset times must stay honest")
        expect(window(50, 300, resetIn: 30).resetDescription(at: now).hasPrefix("Resets in 1 min"), "sub-minute resets must round up")
        let refreshing = UsageState(reading: .available(CodexRateLimits(windows: [window(50, 300, resetIn: 600)]), checkedAt: now), isRefreshing: true)
        expect(refreshing.limits != nil && refreshing.detail(at: now).contains("Refreshing"), "a refresh must keep the previous reading and say so")
        expect(UsageState(reading: .unavailable(checkedAt: now), isRefreshing: true).detail(at: now).hasPrefix("Checking"),
            "retrying an unavailable reading must say it is checking")
    }

    private static func handshakeAndIsolation() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        let client = CLIClient(executableURL: fixture.executable)
        let result = try await client.loadUsage(for: "work")
        expect(result.windows.map(\.remainingPercent) == [77, 9], "the handshake did not return real protocol values")
        expect(try fixture.read("arguments-work") == "cli\nwork\napp-server\n", "usage must select the requested profile through the bundled CLI")
        let requests = try fixture.read("requests-work").split(whereSeparator: \.isNewline)
        expect(requests.count == 3, "usage must not issue account, login, thread or inference requests")
        let methods = try requests.map { try JSONSerialization.jsonObject(with: Data($0.utf8)) as! [String: Any] }.map { $0["method"] as! String }
        expect(methods == ["initialize", "initialized", "account/rateLimits/read"], "the official initialization ordering was not followed")
        let directory = try fixture.read("cwd-work").trimmingCharacters(in: .whitespacesAndNewlines)
        expect(directory != FileManager.default.homeDirectoryForCurrentUser.path && directory.contains("codex-profile-usage-"),
            "account queries must not inherit a project-bound directory")
        expect(!FileManager.default.fileExists(atPath: directory), "the private query directory must be cleaned up")
        expect(!(try fixture.isRunning("work")), "a successful read left an app-server running")
        do { _ = try await client.loadUsage(for: "invalid;profile"); fatalError("invalid profile accepted") }
        catch { expect(error as? CLIClientError == .invalidProfileName, "profile validation lost its error") }
    }

    private static func failuresAndCleanup() async throws {
        for mode in ["init-error", "rate-error", "malformed", "oversized", "early-exit", "hang"] {
            let fixture = try Fixture(mode: mode)
            defer { fixture.cleanup() }
            let start = Date()
            do { _ = try await CLIClient(executableURL: fixture.executable).loadUsage(for: "work", timeout: mode == "hang" ? 0.3 : 2); fatalError("\(mode) unexpectedly succeeded") }
            catch {
                if mode == "hang" { expect(error as? UsageReadError == .timedOut, "a stalled server must reach its deadline") }
                if mode == "oversized" { expect(error as? UsageReadError == .invalidResponse, "oversized output must hit the memory bound, not \(error)") }
                if mode == "malformed" { expect(error as? UsageReadError == .invalidResponse, "malformed JSON must be an invalid response, not \(error)") }
                if ["init-error", "rate-error"].contains(mode) {
                    expect(error as? UsageReadError == .unavailable, "\(mode) returned \(String(describing: error as? UsageReadError)) (\(type(of: error))) instead of unavailable usage")
                }
            }
            expect(Date().timeIntervalSince(start) < 3, "\(mode) exceeded its bounded read and cleanup time")
            expect(!(try fixture.isRunning("work")), "\(mode) left its process running")
        }
        let fixture = try Fixture(mode: "hang")
        defer { fixture.cleanup() }
        let task = Task { try await CLIClient(executableURL: fixture.executable).loadUsage(for: "work", timeout: 5) }
        try await waitForFile(fixture.url("pid-work"))
        task.cancel()
        do { _ = try await task.value; fatalError("cancelled query succeeded") }
        catch { expect(error is CancellationError, "cancellation was not propagated to the owned process") }
        expect(!(try fixture.isRunning("work")), "cancellation left an app-server running")
    }

    private static func refreshCachingAndConcurrency() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        try fixture.write("", to: "hold")
        let suite = "UsageStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = WorkspaceStore(client: CLIClient(executableURL: fixture.executable), defaults: defaults)
        let profiles = (1...6).map { "profile\($0)" }
        store.loadPreview([], profiles: profiles)
        let first = Task { await store.refreshUsage() }
        try await waitForFile(fixture.url("pid-profile1"))
        try await waitForFile(fixture.url("pid-profile2"))
        let second = Task { await store.refreshUsage() }
        try await Task.sleep(nanoseconds: 100_000_000)
        expect(store.isRefreshingUsage && store.usageState(for: "profile1") == UsageState(reading: nil, isRefreshing: true),
            "loading must be visible without blocking profile rows")
        expect(!FileManager.default.fileExists(atPath: fixture.url("pid-profile3").path), "more than two app-servers started together")
        try FileManager.default.removeItem(at: fixture.url("hold"))
        await first.value
        await second.value
        expect(!store.isRefreshingUsage && store.usage.count == 6, "usage refresh did not finish for every profile")
        for state in store.usage.values {
            guard case let .available(limits, _) = state else { fatalError("profile usage failed to reach the store") }
            expect(limits.windows.map(\.remainingPercent) == [77, 9], "the store lost a profile's quota")
        }
        expect(try fixture.read("calls").split(whereSeparator: \.isNewline).count == 6, "overlapping refreshes must coalesce and use the cache")
        await store.refreshUsage()
        expect(try fixture.read("calls").split(whereSeparator: \.isNewline).count == 6, "fresh usage spawned redundant readers")
        guard case let .available(_, firstChecked) = store.usage["profile1"] else { fatalError("profile usage was not cached") }
        try fixture.write("", to: "hold")
        let forced = Task { await store.refreshUsage(force: true) }
        try await waitForCalls(fixture, count: 8)
        let refreshing = store.usageState(for: "profile1")
        expect(refreshing.isRefreshing && refreshing.limits?.windows.map(\.remainingPercent) == [77, 9],
            "a refresh must keep the previous reading visible instead of blanking it")
        try FileManager.default.removeItem(at: fixture.url("hold"))
        await forced.value
        expect(try fixture.read("calls").split(whereSeparator: \.isNewline).count == 12, "explicit refresh must bypass the cache")
        guard case let .available(_, secondChecked) = store.usage["profile1"], secondChecked > firstChecked else {
            fatalError("a completed refresh must replace the previous reading")
        }
        expect(store.readingUsage.isEmpty, "finished reads must not stay marked as refreshing")

        let unavailable = try Fixture(mode: "rate-error")
        defer { unavailable.cleanup() }
        let failedStore = WorkspaceStore(client: CLIClient(executableURL: unavailable.executable), defaults: defaults)
        failedStore.loadPreview([], profiles: ["work"])
        var alerted = false
        failedStore.onError = { _ in alerted = true }
        await failedStore.refreshUsage()
        guard case .unavailable = failedStore.usage["work"] else { fatalError("failed usage must remain unavailable rather than show zero") }
        expect(!alerted && failedStore.filteredTargets == [.profile("work")], "usage failures must not hide launchable profiles or raise alerts")
        expect(!failedStore.usageState(for: "work").detail().contains("private diagnostic"), "upstream diagnostic text leaked into the UI")

        let quitting = try Fixture(mode: "hang")
        defer { quitting.cleanup() }
        let quittingStore = WorkspaceStore(client: CLIClient(executableURL: quitting.executable), defaults: defaults)
        quittingStore.loadPreview([], profiles: ["work"])
        let refresh = Task { await quittingStore.refreshUsage() }
        try await waitForFile(quitting.url("pid-work"))
        await quittingStore.stopUsageRefresh()
        await refresh.value
        let stopped = try !quitting.isRunning("work")
        expect(!quittingStore.isRefreshingUsage && quittingStore.usage["work"] == nil && quittingStore.readingUsage.isEmpty && stopped,
            "Quit must await process cleanup and discard unfinished cache entries")
    }

    private static func waitForCalls(_ fixture: Fixture, count: Int) async throws {
        let deadline = Date().addingTimeInterval(3)
        while (try? fixture.read("calls").split(whereSeparator: \.isNewline).count) ?? 0 < count {
            expect(Date() < deadline, "the forced refresh did not start its readers")
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    private static func realWrapperRespectsProfileAndGuard() async throws {
        guard let wrapper = ProcessInfo.processInfo.environment["PROFILE_TEST_CLI"] else { fatalError("missing real CLI fixture") }
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        let home = fixture.url("home")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: false)
        let proxy = fixture.url("proxy")
        let body = """
        #!/bin/sh
        exec env HOME='\(home.path)' CODEX_PROFILE_CONFIG_HOME='\(home.path)/.config/codex-profile' CODEX_CLI='\(fixture.executable.path)' CODEX_PROFILE_NO_UPDATE_CHECK=1 '\(wrapper)' "$@"
        """
        try Data(body.utf8).write(to: proxy)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: proxy.path)
        let client = CLIClient(executableURL: proxy)
        try await client.createProfile("work")
        try await client.createProfile("home-owner")
        try await client.bindWorkspace(path: home.path, profile: "home-owner")
        let guardResult = try await ProcessRunner().run(executableURL: proxy, arguments: ["workspace", "guard", "strict"])
        expect(guardResult.terminationStatus == 0, "strict guard fixture could not be enabled")
        let limits = try await client.loadUsage(for: "work")
        expect(limits.windows[0].remainingPercent == 77, "the real wrapper blocked an unbound account read")
        expect(try fixture.read("codex-home-work").trimmingCharacters(in: .whitespacesAndNewlines) == home.appendingPathComponent(".codex-work").path,
            "the official app-server did not receive the selected profile's CODEX_HOME")
    }

    @MainActor
    private struct Fixture {
        let root: URL
        var executable: URL { url("server") }

        init(mode: String = "success") throws {
            root = FileManager.default.temporaryDirectory.appendingPathComponent("UsageTests-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
            let body = #"""
            #!/bin/sh
            fixture='\#(root.path)'
            mode='\#(mode)'
            if [ "$1" = --version ]; then printf 'codex-cli 0.152.1\n'; exit; fi
            profile=${2:-work}
            if [ "$1" = app-server ]; then profile=work; fi
            printf '%s\n' "$@" > "$fixture/arguments-$profile"
            printf '%s\n' "$$" > "$fixture/pid-$profile"
            printf '%s\n' "$profile" >> "$fixture/calls"
            printf '%s\n' "$PWD" > "$fixture/cwd-$profile"
            printf '%s\n' "${CODEX_HOME:-}" > "$fixture/codex-home-$profile"
            [ -z "${CODEX_ACCESS_TOKEN+x}" ] && [ -z "${CODEX_API_KEY+x}" ] && [ -z "${OPENAI_API_KEY+x}" ] || exit 83
            [ "$mode" != early-exit ] || exit 1
            if [ "$mode" = hang ]; then
              trap '' TERM
              exec /usr/bin/tail -f /dev/null
            fi
            while [ -f "$fixture/hold" ]; do sleep 0.01; done
            IFS= read -r request || exit 2
            printf '%s\n' "$request" >> "$fixture/requests-$profile"
            case "$request" in *'"method":"initialize"'*) ;; *) exit 3 ;; esac
            if [ "$mode" = init-error ]; then
              printf '%s\n' '{"id":1,"error":{"code":-32600,"message":"private diagnostic"}}'
              exit
            fi
            printf '%s\n' '{"method":"notice","params":{}}' '{"id":999,"result":{}}'
            printf '%s' '{"id":1,'
            sleep 0.02
            printf '%s\n' '"result":{}}'
            IFS= read -r request || exit 4
            printf '%s\n' "$request" >> "$fixture/requests-$profile"
            case "$request" in *'"method":"initialized"'*) ;; *) exit 5 ;; esac
            IFS= read -r request || exit 6
            printf '%s\n' "$request" >> "$fixture/requests-$profile"
            case "$request" in *'"method":"account\/rateLimits\/read"'*|*'"method":"account/rateLimits/read"'*) ;; *) exit 7 ;; esac
            printf '%s\n' '{"id":2,"method":"account/chatgptAuthTokens/refresh","params":{}}'
            case "$mode" in
              rate-error) printf '%s\n' '{"id":2,"error":{"code":-32600,"message":"private diagnostic"}}' ;;
              malformed) printf '%s\n' 'invalid json' ;;
              oversized) exec /usr/bin/head -c 1048577 /dev/zero ;;
              *) printf '%s\n' '{"id":2,"result":\#(UsageTests.response)}' ;;
            esac
            while IFS= read -r request; do :; done
            """#
            try Data(body.utf8).write(to: executable)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        }

        func url(_ name: String) -> URL { root.appendingPathComponent(name) }
        func write(_ value: String, to name: String) throws { try Data(value.utf8).write(to: url(name)) }
        func read(_ name: String) throws -> String { try String(contentsOf: url(name), encoding: .utf8) }
        func isRunning(_ profile: String) throws -> Bool {
            guard FileManager.default.fileExists(atPath: url("pid-\(profile)").path) else { return false }
            let pid = Int32(try read("pid-\(profile)").trimmingCharacters(in: .whitespacesAndNewlines))!
            return kill(pid, 0) == 0
        }
        func cleanup() { try? FileManager.default.removeItem(at: root) }
    }

    private static func waitForFile(_ url: URL) async throws {
        let deadline = Date().addingTimeInterval(3)
        while !FileManager.default.fileExists(atPath: url.path) {
            expect(Date() < deadline, "the usage reader did not start")
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }
    private static func expect(_ condition: Bool, _ message: String) {
        guard condition else { fatalError(message) }
    }
}
