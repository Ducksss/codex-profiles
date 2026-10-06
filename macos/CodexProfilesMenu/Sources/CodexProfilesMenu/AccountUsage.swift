import Darwin
import Foundation

struct RateLimitWindow: Decodable, Equatable, Sendable {
    let usedPercent: Double
    let windowDurationMins: Int?
    let resetsAt: TimeInterval?

    var remainingPercent: Int {
        Int((100 - min(100, max(0, usedPercent))).rounded(.down))
    }

    var durationLabel: String? {
        guard let minutes = windowDurationMins, minutes > 0 else { return nil }
        if minutes % 1440 == 0 { return "\(minutes / 1440)d" }
        if minutes % 60 == 0 { return "\(minutes / 60)h" }
        return "\(minutes)m"
    }

    var level: QuotaLevel { QuotaLevel(remainingPercent: remainingPercent) }

    func hasReset(at date: Date) -> Bool {
        resetsAt.map { $0 <= date.timeIntervalSince1970 } ?? false
    }

    /// Reset time in words, e.g. "Resets in 2 hr, 14 min (3:40 PM)".
    func resetDescription(at date: Date) -> String {
        guard let resetsAt else { return "Reset time unavailable" }
        let reset = Date(timeIntervalSince1970: resetsAt)
        let clock = UsageFormat.clock(reset, relativeTo: date)
        guard !hasReset(at: date) else { return "Reset at \(clock)" }
        return "Resets in \(UsageFormat.countdown(to: reset, from: date, style: .short)) (\(clock))"
    }
}

/// Severity shared by meters, numbers and summaries. Numbers always carry
/// the value; colour only adds emphasis.
enum QuotaLevel: Equatable {
    case normal
    case low
    case critical

    init(remainingPercent: Int) {
        self = remainingPercent <= 10 ? .critical : remainingPercent <= 25 ? .low : .normal
    }
}

enum UsageFormat {
    private static let countdownFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.maximumUnitCount = 2
        // Countdowns sit inside English sentences, so they stay English; clock
        // times still follow the user's locale and 12/24-hour setting.
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        return formatter
    }()
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMdjmm")
        return formatter
    }()

    /// Time remaining, rounded up to whole minutes: "2h 14m" or "2 hr, 14 min".
    static func countdown(to date: Date, from now: Date, style: DateComponentsFormatter.UnitsStyle) -> String {
        countdownFormatter.unitsStyle = style
        let minutes = max(1, (date.timeIntervalSince(now) / 60).rounded(.up))
        return countdownFormatter.string(from: minutes * 60) ?? "\(Int(minutes))m"
    }

    /// A time today, or a date and time otherwise.
    static func clock(_ date: Date, relativeTo now: Date) -> String {
        Calendar.current.isDate(date, inSameDayAs: now)
            ? timeFormatter.string(from: date)
            : dateTimeFormatter.string(from: date)
    }
}

struct CodexRateLimits: Equatable, Sendable {
    let windows: [RateLimitWindow]

    static func decode(_ data: Data) throws -> Self {
        struct Snapshot: Decodable {
            let primary: RateLimitWindow?
            let secondary: RateLimitWindow?
            let limitId: String?
        }
        struct Response: Decodable {
            let rateLimits: Snapshot
            let rateLimitsByLimitId: [String: Snapshot]?
        }
        let response = try JSONDecoder().decode(Response.self, from: data)
        let snapshot = response.rateLimitsByLimitId?["codex"] ?? response.rateLimits
        guard snapshot.limitId == nil || snapshot.limitId == "codex" else {
            throw UsageReadError.unavailable
        }
        let windows = [snapshot.primary, snapshot.secondary].compactMap { $0 }
        guard !windows.isEmpty else { throw UsageReadError.unavailable }
        return Self(windows: windows)
    }
}

enum ProfileUsage: Equatable, Sendable {
    case available(CodexRateLimits, checkedAt: Date)
    case unavailable(checkedAt: Date)

    func needsRefresh(at date: Date) -> Bool {
        switch self {
        case let .unavailable(checkedAt): return date.timeIntervalSince(checkedAt) >= 60
        case let .available(limits, checkedAt):
            return date.timeIntervalSince(checkedAt) >= 60 || limits.windows.contains { $0.hasReset(at: date) }
        }
    }
}

/// A profile's latest reading and whether a newer one is being read.
/// Refreshing keeps the previous reading visible instead of blanking it.
struct UsageState: Equatable {
    var reading: ProfileUsage?
    var isRefreshing = false

    var limits: CodexRateLimits? {
        if case let .available(limits, _) = reading { return limits }
        return nil
    }

    /// The window that blocks first, once it is low enough to mention.
    func constrainingWindow(at date: Date) -> RateLimitWindow? {
        limits?.windows
            .filter { !$0.hasReset(at: date) && $0.level != .normal }
            .min { lhs, rhs in
                lhs.remainingPercent != rhs.remainingPercent
                    ? lhs.remainingPercent < rhs.remainingPercent
                    : (lhs.resetsAt ?? 0) > (rhs.resetsAt ?? 0)
            }
    }

    /// A compact row summary such as "5h limit low · resets in 1h 12m".
    func summary(at date: Date = Date()) -> String? {
        guard let window = constrainingWindow(at: date) else { return nil }
        let name = window.durationLabel.map { "\($0) limit" } ?? "Limit"
        let state = window.remainingPercent == 0 ? "reached" : "low"
        guard let resetsAt = window.resetsAt else { return "\(name) \(state)" }
        let countdown = UsageFormat.countdown(to: Date(timeIntervalSince1970: resetsAt), from: date, style: .abbreviated)
        return "\(name) \(state) · resets in \(countdown)"
    }

    func detail(at date: Date = Date()) -> String {
        guard case let .available(limits, checkedAt) = reading else {
            if reading == nil || isRefreshing { return "Checking Codex usage for this profile…" }
            return "Codex usage is unavailable. Sign in to Codex CLI for this profile, check your connection, then refresh (⌘R). ChatGPT may use a different account."
        }
        let windows = limits.windows.enumerated().map { index, window in
            let label = window.durationLabel ?? "Limit \(index + 1)"
            let remaining = window.hasReset(at: date) ? "Awaiting a fresh reading" : "\(window.remainingPercent)% remaining"
            return "\(label): \(remaining). \(window.resetDescription(at: date))."
        }
        let checked = "Checked \(UsageFormat.clock(checkedAt, relativeTo: date))."
        let freshness = isRefreshing ? "Refreshing… \(checked)" : "\(checked) Refresh with ⌘R."
        return (["Codex CLI quota for this profile."] + windows + ["\(freshness) ChatGPT may use a different account."])
            .joined(separator: "\n")
    }
}

enum UsageReadError: Error, Equatable {
    case unavailable
    case timedOut
    case invalidResponse
}

/// Newline-delimited framing that searches each received byte once, so an
/// unterminated reply reaches the size limit in linear time.
struct LineBuffer {
    let limit: Int
    private var storage: [UInt8] = []
    private var start = 0
    private var searched = 0
    private var received = 0

    init(limit: Int) { self.limit = limit }

    /// Returns false once the total output exceeds the limit.
    mutating func append(_ bytes: ArraySlice<UInt8>) -> Bool {
        received += bytes.count
        guard received <= limit else { return false }
        if start > 0 {
            storage.removeSubrange(..<start)
            searched -= start
            start = 0
        }
        storage.append(contentsOf: bytes)
        return true
    }

    mutating func next() -> Data? {
        guard let newline = storage[searched...].firstIndex(of: 10) else {
            searched = storage.count
            return nil
        }
        defer { start = newline + 1; searched = start }
        return Data(storage[start..<newline])
    }
}

extension CLIClient {
    func loadUsage(for profile: String, timeout: TimeInterval = 10) async throws -> CodexRateLimits {
        guard Self.isValidProfileName(profile) else { throw CLIClientError.invalidProfileName }
        guard let executableURL else { throw CLIClientError.executableNotFound }
        let reader = AccountUsageReader()
        return try await withTaskCancellationHandler {
            // Blocking pipe I/O must not occupy Swift's cooperative pool.
            try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .utility).async {
                    do {
                        continuation.resume(returning: try reader.read(executableURL: executableURL, profile: profile, timeout: timeout))
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        } onCancel: {
            reader.cancel()
        }
    }
}

// One read through the official CLI's stdio protocol. No account files,
// external tokens, inference requests, or long-lived app-server are involved.
private final class AccountUsageReader: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }

    private func checkCancellation() throws {
        lock.lock()
        let cancelled = self.cancelled
        lock.unlock()
        if cancelled { throw CancellationError() }
    }

    func read(executableURL: URL, profile: String, timeout: TimeInterval) throws -> CodexRateLimits {
        try checkCancellation()
        let process = Process()
        let input = Pipe()
        let output = Pipe()
        process.executableURL = executableURL
        process.arguments = ["cli", profile, "app-server"]
        // A private, unbound directory avoids applying a project's strict
        // workspace guard to an account-level read.
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("codex-profile-usage-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: directory) }
        process.currentDirectoryURL = directory
        var environment = ProcessInfo.processInfo.environment
        for key in ["CODEX_ACCESS_TOKEN", "CODEX_API_KEY", "OPENAI_API_KEY"] {
            environment.removeValue(forKey: key)
        }
        process.environment = environment
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        // A CLI which exits early must not send SIGPIPE to the menu app.
        guard fcntl(input.fileHandleForWriting.fileDescriptor, F_SETNOSIGPIPE, 1) != -1 else {
            throw UsageReadError.unavailable
        }
        defer {
            try? input.fileHandleForWriting.close()
            if process.isRunning {
                process.terminate()
                let deadline = DispatchTime.now().uptimeNanoseconds + 300_000_000
                while process.isRunning && DispatchTime.now().uptimeNanoseconds < deadline { usleep(10_000) }
                if process.isRunning { kill(process.processIdentifier, SIGKILL) }
            }
            if process.processIdentifier > 0 { process.waitUntilExit() }
            try? output.fileHandleForReading.close()
        }
        try process.run()
        try input.fileHandleForReading.close()
        try output.fileHandleForWriting.close()
        let deadline = DispatchTime.now().uptimeNanoseconds + UInt64(max(0, timeout) * 1_000_000_000)
        var lines = LineBuffer(limit: 1_048_576)
        var bytes = [UInt8](repeating: 0, count: 65_536)

        func send(_ message: [String: Any]) throws {
            var data = try JSONSerialization.data(withJSONObject: message)
            data.append(10)
            try input.fileHandleForWriting.write(contentsOf: data)
        }
        func response(id: Int) throws -> Data {
            while true {
                try checkCancellation()
                guard DispatchTime.now().uptimeNanoseconds < deadline else { throw UsageReadError.timedOut }
                while let line = lines.next() {
                    guard let message = (try? JSONSerialization.jsonObject(with: line)) as? [String: Any] else {
                        throw UsageReadError.invalidResponse
                    }
                    // Ignore asynchronous notifications and unrelated replies.
                    guard message["method"] == nil, let responseID = message["id"] as? Int, responseID == id else { continue }
                    guard message["error"] == nil, let result = message["result"] as? [String: Any] else {
                        throw UsageReadError.unavailable
                    }
                    return try JSONSerialization.data(withJSONObject: result)
                }
                var descriptor = pollfd(fd: output.fileHandleForReading.fileDescriptor, events: Int16(POLLIN), revents: 0)
                let ready = poll(&descriptor, 1, 50)
                if ready < 0 {
                    if errno == EINTR { continue }
                    throw UsageReadError.unavailable
                }
                guard ready > 0 else { continue }
                let count = Darwin.read(descriptor.fd, &bytes, bytes.count)
                guard count > 0 else { throw UsageReadError.unavailable }
                guard lines.append(bytes[..<count]) else { throw UsageReadError.invalidResponse }
            }
        }

        try send(["id": 1, "method": "initialize", "params": ["clientInfo": [
            "name": "codex_profiles_menu", "title": "Codex Profiles",
            "version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev",
        ]]])
        _ = try response(id: 1)
        try send(["method": "initialized"])
        try send(["id": 2, "method": "account/rateLimits/read"])
        return try CodexRateLimits.decode(response(id: 2))
    }
}
