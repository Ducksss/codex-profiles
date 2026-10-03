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

    func hasReset(at date: Date) -> Bool {
        resetsAt.map { $0 <= date.timeIntervalSince1970 } ?? false
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
    case loading
    case available(CodexRateLimits, checkedAt: Date)
    case unavailable(checkedAt: Date)

    func needsRefresh(at date: Date) -> Bool {
        switch self {
        case .loading: return false
        case let .unavailable(checkedAt): return date.timeIntervalSince(checkedAt) >= 60
        case let .available(limits, checkedAt):
            return date.timeIntervalSince(checkedAt) >= 60 || limits.windows.contains { $0.hasReset(at: date) }
        }
    }

    func detail(at date: Date = Date()) -> String {
        switch self {
        case .loading: return "Checking Codex usage for this profile…"
        case .unavailable:
            return "Codex usage is unavailable. Sign in to Codex CLI for this profile, check your connection, then refresh (⌘R). ChatGPT may use a different account."
        case let .available(limits, checkedAt):
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            let windows = limits.windows.enumerated().map { index, window in
                let label = window.durationLabel ?? "Limit \(index + 1)"
                let remaining = window.hasReset(at: date) ? "Awaiting a fresh reading" : "\(window.remainingPercent)% remaining"
                let reset = window.resetsAt.map { "Resets \(formatter.string(from: Date(timeIntervalSince1970: $0)))" }
                    ?? "Reset time unavailable"
                return "\(label): \(remaining). \(reset)."
            }
            return (["Codex CLI quota for this profile."] + windows + ["Checked \(formatter.string(from: checkedAt)). Refresh with ⌘R. ChatGPT may use a different account."]).joined(separator: "\n")
        }
    }
}

enum UsageReadError: Error, Equatable {
    case unavailable
    case timedOut
    case invalidResponse
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
        var buffer = Data()
        var receivedBytes = 0

        func send(_ message: [String: Any]) throws {
            var data = try JSONSerialization.data(withJSONObject: message)
            data.append(10)
            try input.fileHandleForWriting.write(contentsOf: data)
        }
        func response(id: Int) throws -> Data {
            while true {
                try checkCancellation()
                guard DispatchTime.now().uptimeNanoseconds < deadline else { throw UsageReadError.timedOut }
                while let newline = buffer.firstIndex(of: 10) {
                    let line = buffer.prefix(upTo: newline)
                    buffer.removeSubrange(...newline)
                    guard let message = try JSONSerialization.jsonObject(with: line) as? [String: Any] else {
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
                var bytes = [UInt8](repeating: 0, count: 4096)
                let count = Darwin.read(descriptor.fd, &bytes, bytes.count)
                guard count > 0 else { throw UsageReadError.unavailable }
                receivedBytes += count
                guard receivedBytes <= 1_048_576 else { throw UsageReadError.invalidResponse }
                buffer.append(contentsOf: bytes.prefix(count))
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
