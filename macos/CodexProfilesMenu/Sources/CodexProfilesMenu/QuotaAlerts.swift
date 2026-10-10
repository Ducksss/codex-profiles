import Foundation

// Low-quota alerts. Everything here is plain Foundation so it can be tested
// without AppKit or UserNotifications. Alerts only show the numbers; the app
// never switches profiles or accounts on the person's behalf.

/// One profile's quota window at or below the low threshold.
struct QuotaAlert: Equatable {
    let profile: String
    let window: RateLimitWindow
    /// Identifies the window within its profile: its duration, or its
    /// position when the response gave none.
    let slot: Int

    var level: QuotaLevel { window.level }

    /// "work: 5h limit at 8%, resets 14:20". Clock times follow the user's
    /// locale; the surrounding words stay English like the rest of the menu.
    func description(at now: Date) -> String {
        let name = window.durationLabel.map { "\($0) limit" } ?? "limit"
        let state = window.remainingPercent == 0 ? "reached" : "at \(window.remainingPercent)%"
        guard let resetsAt = window.resetsAt else { return "\(profile): \(name) \(state)" }
        return "\(profile): \(name) \(state), resets \(UsageFormat.clock(Date(timeIntervalSince1970: resetsAt), relativeTo: now))"
    }

    static func slot(of window: RateLimitWindow, at index: Int) -> Int {
        window.windowDurationMins ?? -(index + 1)
    }
}

/// What the menu-bar icon shows: every initialized profile whose constraining
/// window is low or critical and has not reset yet. Within a window the
/// remaining quota can only fall until its reset, so a reading stays a true
/// upper bound until then even when the menu has not been opened since.
struct QuotaIndicator: Equatable {
    static let normal = QuotaIndicator(alerts: [], nextChange: nil)

    /// Most constrained first.
    let alerts: [QuotaAlert]
    /// The earliest reset among them, when the icon must be re-evaluated.
    let nextChange: Date?

    var level: QuotaLevel { alerts.map(\.level).max() ?? .normal }

    init(alerts: [QuotaAlert], nextChange: Date?) {
        self.alerts = alerts
        self.nextChange = nextChange
    }

    init(usage: [String: ProfileUsage], profiles: [String], at now: Date) {
        let alerts = profiles.compactMap { profile -> QuotaAlert? in
            let state = UsageState(reading: usage[profile])
            guard let window = state.constrainingWindow(at: now),
                  let index = state.limits?.windows.firstIndex(of: window) else { return nil }
            return QuotaAlert(profile: profile, window: window, slot: QuotaAlert.slot(of: window, at: index))
        }.sorted { lhs, rhs in
            lhs.window.remainingPercent != rhs.window.remainingPercent
                ? lhs.window.remainingPercent < rhs.window.remainingPercent
                : lhs.profile < rhs.profile
        }
        self.init(alerts: alerts, nextChange: alerts.compactMap(\.window.resetsAt).min().map(Date.init(timeIntervalSince1970:)))
    }

    func lines(at now: Date) -> [String] {
        let shown = alerts.prefix(4).map { $0.description(at: now) }
        return alerts.count > 4 ? shown + ["and \(alerts.count - 4) more"] : shown
    }

    func toolTip(at now: Date) -> String {
        (["Codex Profiles"] + lines(at: now)).joined(separator: "\n")
    }

    /// Names each profile and window, so the state never depends on the icon alone.
    func accessibilityLabel(at now: Date) -> String {
        let lines = lines(at: now)
        guard !lines.isEmpty else { return "Codex Profiles" }
        return "Codex Profiles. Low Codex quota: " + lines.joined(separator: "; ")
    }
}

/// Decides which notifications to post. A notification announces a crossing,
/// never a state: the first reading of each window after launch, or after
/// alerts are turned on, is a baseline, so a quota that was already low does
/// not notify by itself. Each profile window notifies at most once per level
/// per reset period, and a profile gets one notification per reading.
struct QuotaCrossingTracker {
    /// Reset times can vary by a few seconds between readings of the same
    /// period; a record outlives its reset by this margin.
    static let resetGrace: TimeInterval = 60

    private struct WindowID: Hashable {
        let profile: String
        let slot: Int
    }

    private struct Mark {
        let level: QuotaLevel
        let resetsAt: TimeInterval?
    }

    private var observed: [WindowID: Mark] = [:]
    private var notified: [WindowID: Mark] = [:]

    /// Forgets every baseline, as when alerts are turned off.
    mutating func reset() {
        observed.removeAll()
        notified.removeAll()
    }

    /// Records the current readings and returns the profiles that crossed into
    /// low or critical since the previous reading, most constrained first.
    mutating func observe(_ usage: [String: ProfileUsage], profiles: [String], at now: Date) -> [QuotaAlert] {
        let current = Set(profiles)
        observed = observed.filter { current.contains($0.key.profile) }
        notified = notified.filter { current.contains($0.key.profile) }
        let time = now.timeIntervalSince1970
        var alerts: [QuotaAlert] = []
        for profile in profiles {
            // Unavailable or missing readings keep the previous baseline.
            guard case let .available(limits, _) = usage[profile] else { continue }
            var crossed: [QuotaAlert] = []
            for (index, window) in limits.windows.enumerated() {
                let id = WindowID(profile: profile, slot: QuotaAlert.slot(of: window, at: index))
                // A passed reset restores the quota; the reading no longer applies.
                let level = window.hasReset(at: now) ? .normal : window.level
                if let mark = notified[id] {
                    let expired = mark.resetsAt.map { time >= $0 + Self.resetGrace } ?? (level == .normal)
                    if expired { notified[id] = nil }
                }
                let previous = observed[id]
                observed[id] = Mark(level: level, resetsAt: window.resetsAt)
                guard let previous else { continue }
                let previousLevel = previous.resetsAt.map { $0 <= time } == true ? .normal : previous.level
                guard level > previousLevel, level > (notified[id]?.level ?? .normal) else { continue }
                notified[id] = Mark(level: level, resetsAt: window.resetsAt)
                crossed.append(QuotaAlert(profile: profile, window: window, slot: id.slot))
            }
            if let alert = crossed.min(by: { $0.window.remainingPercent < $1.window.remainingPercent }) {
                alerts.append(alert)
            }
        }
        return alerts.sorted { $0.window.remainingPercent < $1.window.remainingPercent }
    }
}

/// Another profile with clearly more of the same window left. It is
/// mentioned, never switched to.
struct QuotaHeadroom: Equatable {
    /// Alerts start at 25%, so this is always at least twice as much.
    static let minimumRemaining = 50
    /// An older reading may overstate what is left.
    static let maximumAge: TimeInterval = 15 * 60

    let profile: String
    let remainingPercent: Int

    static func suggestion(for alert: QuotaAlert, usage: [String: ProfileUsage], profiles: [String], at now: Date) -> QuotaHeadroom? {
        guard let duration = alert.window.windowDurationMins else { return nil }
        return profiles.compactMap { profile -> QuotaHeadroom? in
            guard profile != alert.profile, case let .available(limits, checkedAt) = usage[profile],
                  now.timeIntervalSince(checkedAt) <= maximumAge,
                  // A profile low in any window is no real alternative.
                  UsageState(reading: usage[profile]).constrainingWindow(at: now) == nil,
                  let window = limits.windows.first(where: { $0.windowDurationMins == duration && !$0.hasReset(at: now) }),
                  window.remainingPercent >= minimumRemaining else { return nil }
            return QuotaHeadroom(profile: profile, remainingPercent: window.remainingPercent)
        }.min { lhs, rhs in
            lhs.remainingPercent != rhs.remainingPercent ? lhs.remainingPercent > rhs.remainingPercent : lhs.profile < rhs.profile
        }
    }
}

/// The text of one low-quota notification.
struct QuotaNotification: Equatable {
    let identifier: String
    let title: String
    let body: String

    init(identifier: String, title: String, body: String) {
        self.identifier = identifier
        self.title = title
        self.body = body
    }

    init(alert: QuotaAlert, headroom: QuotaHeadroom?, at now: Date) {
        let window = alert.window
        // A later, more severe crossing replaces the earlier notification.
        identifier = "low-quota.\(alert.profile).\(alert.slot)"
        title = window.remainingPercent == 0 ? "\(alert.profile): Codex limit reached"
            : alert.level == .critical ? "\(alert.profile): Codex quota almost used"
            : "\(alert.profile): Codex quota low"
        let name = window.durationLabel.map { "\($0) limit" } ?? "Limit"
        let state = window.remainingPercent == 0 ? "reached" : "at \(window.remainingPercent)%"
        var sentences = ["\(name) \(state).", "\(window.resetDescription(at: now))."]
        if let headroom { sentences.append("\(headroom.profile) has \(headroom.remainingPercent)% left.") }
        body = sentences.joined(separator: " ")
    }
}

/// The persisted Low-quota alerts choice. Off by default, so the app never
/// asks for notification permission until the person turns alerts on.
struct QuotaAlertPreferences {
    static let enabledKey = "lowQuotaAlerts"
    let defaults: UserDefaults

    var isEnabled: Bool {
        get { defaults.bool(forKey: Self.enabledKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.enabledKey) }
    }
}

enum NotificationPermission: Equatable {
    case notDetermined
    case allowed
    case denied
}

/// Posts notifications. Tests substitute a fake so they never touch the
/// system notification center or ask for permission.
@MainActor
protocol QuotaNotifying: AnyObject {
    func permission() async -> NotificationPermission
    func requestPermission() async -> Bool
    func post(_ notification: QuotaNotification)
}

enum QuotaAlertToggle: Equatable {
    case enabled
    case disabled
    /// Notifications are not allowed; the preference stays off.
    case denied
    /// Another change is still waiting for a permission answer.
    case busy
}

/// Connects usage readings to the menu-bar indicator and, when the person has
/// turned alerts on, to notifications and a modest background refresh.
@MainActor
final class QuotaAlertController {
    nonisolated static let refreshInterval: TimeInterval = 300
    nonisolated static let permissionDeniedMessage = "Codex Profiles isn’t allowed to send notifications. Turn them on in System Settings › Notifications › Codex Profiles, then choose Low-quota alerts again. The menu-bar icon still marks low quota."

    var onIndicatorChange: ((QuotaIndicator) -> Void)?
    private(set) var indicator = QuotaIndicator.normal
    /// The last permission answer, while alerts are on.
    private(set) var permission: NotificationPermission?
    private(set) var isChanging = false

    private let store: WorkspaceStore
    private let notifier: QuotaNotifying
    private let preferences: QuotaAlertPreferences
    private let refreshInterval: TimeInterval
    private var tracker = QuotaCrossingTracker()
    private var indicatorTimer: Task<Void, Never>?

    var isEnabled: Bool { preferences.isEnabled }

    init(store: WorkspaceStore, notifier: QuotaNotifying, defaults: UserDefaults = .standard,
         refreshInterval: TimeInterval = QuotaAlertController.refreshInterval) {
        self.store = store
        self.notifier = notifier
        preferences = QuotaAlertPreferences(defaults: defaults)
        self.refreshInterval = refreshInterval
        store.onUsageChange = { [weak self] in self?.usageDidChange() }
    }

    /// Shows the current state and resumes background reads if alerts are on.
    /// Turning alerts on is the only path that asks for permission.
    func start() {
        updateIndicator(at: Date())
        guard isEnabled else { return }
        store.startBackgroundUsageRefresh(every: refreshInterval)
        Task { await refreshPermission() }
    }

    /// Notices permission changed in System Settings since the last check.
    func refreshPermission() async {
        guard isEnabled else { return }
        permission = await notifier.permission()
    }

    func setEnabled(_ enabled: Bool) async -> QuotaAlertToggle {
        guard !isChanging else { return .busy }
        guard enabled else {
            preferences.isEnabled = false
            permission = nil
            store.stopBackgroundUsageRefresh()
            tracker.reset()
            return .disabled
        }
        isChanging = true
        defer { isChanging = false }
        var answer = await notifier.permission()
        if answer == .notDetermined { answer = await notifier.requestPermission() ? .allowed : .denied }
        guard answer == .allowed else { return .denied }
        permission = answer
        preferences.isEnabled = true
        // Readings already on screen are the baseline, never a crossing.
        tracker.reset()
        _ = tracker.observe(store.usage, profiles: store.profiles, at: Date())
        store.startBackgroundUsageRefresh(every: refreshInterval)
        return .enabled
    }

    func usageDidChange(at now: Date = Date()) {
        updateIndicator(at: now)
        guard isEnabled else { return }
        for alert in tracker.observe(store.usage, profiles: store.profiles, at: now) {
            let headroom = QuotaHeadroom.suggestion(for: alert, usage: store.usage, profiles: store.profiles, at: now)
            // Posting without permission fails quietly; the icon still shows it.
            notifier.post(QuotaNotification(alert: alert, headroom: headroom, at: now))
        }
    }

    private func updateIndicator(at now: Date) {
        let next = QuotaIndicator(usage: store.usage, profiles: store.profiles, at: now)
        indicatorTimer?.cancel()
        indicatorTimer = nil
        // Clear the icon when the earliest low window resets, even without a new reading.
        if let change = next.nextChange, change > now {
            let delay = change.timeIntervalSince(now) + 1
            indicatorTimer = Task { @MainActor [weak self] in
                guard (try? await Task.sleep(for: .milliseconds(Int64(delay * 1000)), clock: .continuous)) != nil else { return }
                self?.updateIndicator(at: Date())
            }
        }
        guard next != indicator else { return }
        indicator = next
        onIndicatorChange?(next)
    }
}
