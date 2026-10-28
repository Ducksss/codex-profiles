import Foundation

@MainActor
enum QuotaAlertTests {
    static func run() async throws {
        indicatorState()
        crossingDetectionAndDeduplication()
        headroomSuggestion()
        notificationText()
        preferencePersistence()
        print("Checking low-quota alert permission and notifications…")
        try await controllerAsksOnlyWhenTurnedOn()
        await enablingIgnoresUnsettledReadings()
        await otherReadingsKeepUnsettledProfilesOutOfTheBaseline()
        await unansweredPermissionStopsWaiting()
        print("Checking background usage refresh only while alerts are on…")
        try await backgroundRefreshFollowsAlerts()
        print("Low-quota indicator, crossing, headroom and preference tests passed.")
    }

    private nonisolated static let now = Date(timeIntervalSince1970: 1_000_000)

    private static func window(_ remaining: Double, _ minutes: Int?, resetIn seconds: TimeInterval?, from date: Date = now) -> RateLimitWindow {
        RateLimitWindow(usedPercent: 100 - remaining, windowDurationMins: minutes, resetsAt: seconds.map { date.timeIntervalSince1970 + $0 })
    }

    private static func reading(_ windows: [RateLimitWindow], checkedAt: Date = now) -> ProfileUsage {
        .available(CodexRateLimits(windows: windows), checkedAt: checkedAt)
    }

    private static func indicatorState() {
        let empty = QuotaIndicator(usage: [:], profiles: ["work"], at: now)
        expect(empty == .normal && empty.level == .normal, "no readings must leave the icon unbadged")
        expect(empty.accessibilityLabel(at: now) == "Codex Profiles" && empty.toolTip(at: now) == "Codex Profiles",
            "the unbadged icon must keep its plain name")

        let usage: [String: ProfileUsage] = [
            "work": reading([window(8, 300, resetIn: 3600), window(60, 10080, resetIn: 86400)]),
            "personal": reading([window(70, 300, resetIn: 7200), window(20, 10080, resetIn: 172_800)]),
            "healthy": reading([window(80, 300, resetIn: 600)]),
            "expired": reading([window(3, 300, resetIn: -5)]),
            "offline": .unavailable(checkedAt: now),
            "removed": reading([window(1, 300, resetIn: 600)]),
        ]
        let profiles = ["expired", "healthy", "offline", "personal", "work"]
        let indicator = QuotaIndicator(usage: usage, profiles: profiles, at: now)
        expect(indicator.level == .critical && indicator.alerts.map(\.profile) == ["work", "personal"],
            "the icon must list low and critical profiles, most constrained first, ignoring healthy, reset, unavailable and removed ones")
        expect(indicator.nextChange == now.addingTimeInterval(3600), "the icon must be re-evaluated at the earliest reset")
        let workReset = UsageFormat.clock(now.addingTimeInterval(3600), relativeTo: now)
        let personalReset = UsageFormat.clock(now.addingTimeInterval(172_800), relativeTo: now)
        expect(indicator.lines(at: now) == ["work: 5h limit at 8%, resets \(workReset)", "personal: 7d limit at 20%, resets \(personalReset)"],
            "each line must name the profile, window, remaining quota and reset time")
        expect(indicator.accessibilityLabel(at: now) == "Codex Profiles. Low Codex quota: work: 5h limit at 8%, resets \(workReset); personal: 7d limit at 20%, resets \(personalReset)",
            "VoiceOver must hear every low profile and window, not just a badge")
        expect(indicator.toolTip(at: now).split(separator: "\n").count == 3, "the tooltip must keep one line per profile")
        expect(QuotaIndicator(usage: usage, profiles: profiles, at: now.addingTimeInterval(3601)).alerts.map(\.profile) == ["personal"],
            "a window must leave the icon once its reset passes, without a new reading")
        expect(QuotaIndicator(usage: ["personal": usage["personal"]!], profiles: ["personal"], at: now).level == .low,
            "a low window alone must show the low badge")

        let reached = QuotaIndicator(usage: ["work": reading([window(0, 300, resetIn: 600)])], profiles: ["work"], at: now)
        expect(reached.lines(at: now)[0].hasPrefix("work: 5h limit reached, resets "), "an exhausted window must say reached")
        let unknown = QuotaIndicator(usage: ["work": reading([window(9, nil, resetIn: nil)])], profiles: ["work"], at: now)
        expect(unknown.lines(at: now) == ["work: limit at 9%"] && unknown.nextChange == nil,
            "missing durations and reset times must stay honest")
        let many = Dictionary(uniqueKeysWithValues: (1...6).map { ("p\($0)", reading([window(Double($0), 300, resetIn: 600)])) })
        let crowded = QuotaIndicator(usage: many, profiles: many.keys.sorted(), at: now)
        expect(crowded.lines(at: now).count == 5 && crowded.lines(at: now).last == "and 2 more", "a long list must stay compact")

        expect(indicator.refreshDelay(at: now) == 3601 && QuotaIndicator.normal.refreshDelay(at: now) == nil,
            "the icon must be re-evaluated just after the earliest reset, and only when something is low")
        let implausible = QuotaIndicator(usage: ["work": reading([window(5, 300, resetIn: 1e17)])], profiles: ["work"], at: now)
        expect(implausible.refreshDelay(at: now) == QuotaIndicator.maximumRefreshDelay && QuotaIndicator.maximumRefreshDelay == 86_400,
            "an implausible reset time must not overflow the timer; the icon is checked again within a day")
        expect(QuotaIndicator(alerts: [], nextChange: Date(timeIntervalSince1970: .infinity)).refreshDelay(at: now) == QuotaIndicator.maximumRefreshDelay
            && QuotaIndicator(alerts: [], nextChange: now.addingTimeInterval(-1)).refreshDelay(at: now) == nil,
            "non-finite and past reset times must not schedule an invalid wait")
    }

    private static func crossingDetectionAndDeduplication() {
        let reset = 3600.0
        var tracker = QuotaCrossingTracker()
        func observe(_ windows: [RateLimitWindow], at date: Date = now) -> [QuotaAlert] {
            tracker.observe(["work": reading(windows, checkedAt: date)], profiles: ["work"], at: date)
        }
        expect(observe([window(20, 300, resetIn: reset)]).isEmpty, "a quota already low at launch must not notify")
        expect(observe([window(20, 300, resetIn: reset)]).isEmpty, "an unchanged reading must not notify")
        expect(observe([window(15, 300, resetIn: reset)]).isEmpty, "falling within the same level must not notify")
        let critical = observe([window(8, 300, resetIn: reset)])
        expect(critical.count == 1 && critical[0].level == .critical && critical[0].slot == 300 && critical[0].window.remainingPercent == 8,
            "crossing into critical must notify once")
        // Reset times may move by a few seconds between readings of one period.
        expect(observe([window(5, 300, resetIn: reset + 2)]).isEmpty, "the same level and reset period must not notify again")
        expect(observe([window(0, 300, resetIn: reset)]).isEmpty, "reaching the limit is still the critical level")
        let nextPeriod = now.addingTimeInterval(reset + QuotaCrossingTracker.resetGrace)
        expect(observe([window(90, 300, resetIn: 18000, from: nextPeriod)], at: nextPeriod).isEmpty, "a restored quota must not notify")
        let low = observe([window(22, 300, resetIn: 18000, from: nextPeriod)], at: nextPeriod)
        expect(low.count == 1 && low[0].level == .low, "a new reset period must notify again")

        // An early reset restores the quota with a new reset time before the old one passes.
        var early = QuotaCrossingTracker()
        func observeEarly(_ remaining: Double, resetsAt: TimeInterval, at date: Date) -> [QuotaAlert] {
            early.observe(["work": reading([window(remaining, 300, resetIn: resetsAt - now.timeIntervalSince1970)], checkedAt: date)],
                profiles: ["work"], at: date)
        }
        let oldReset = now.timeIntervalSince1970 + reset
        _ = observeEarly(40, resetsAt: oldReset, at: now)
        expect(observeEarly(20, resetsAt: oldReset, at: now.addingTimeInterval(60)).count == 1, "falling to 20% must notify once")
        let earlyReset = now.addingTimeInterval(600)
        let newReset = earlyReset.timeIntervalSince1970 + 18000
        expect(observeEarly(100, resetsAt: newReset, at: earlyReset).isEmpty, "an early reset must not notify by itself")
        let afterEarly = observeEarly(20, resetsAt: newReset, at: now.addingTimeInterval(1800))
        expect(afterEarly.count == 1 && afterEarly[0].level == .low,
            "an early reset must start a new period, so falling low again notifies before the old reset time")

        // Reset times jitter by seconds; a reading just past the old reset can still belong to its period.
        var jitter = QuotaCrossingTracker()
        _ = jitter.observe(["work": reading([window(20, 300, resetIn: reset)])], profiles: ["work"], at: now)
        let straddling = now.addingTimeInterval(reset + 5)
        expect(jitter.observe(["work": reading([window(19, 300, resetIn: 5, from: straddling)], checkedAt: straddling)],
            profiles: ["work"], at: straddling).isEmpty,
            "a reset time that moved by seconds must not turn an already-low quota into a crossing")

        // Without a reset time, a level re-arms only after a clear recovery.
        var unknown = QuotaCrossingTracker()
        var minute = 0.0
        func observeUnknown(_ remaining: Double) -> Int {
            minute += 5
            let date = now.addingTimeInterval(minute * 60)
            return unknown.observe(["work": reading([window(remaining, 300, resetIn: nil)], checkedAt: date)], profiles: ["work"], at: date).count
        }
        _ = observeUnknown(30)
        expect([25.0, 26, 25, 26, 25].map(observeUnknown).reduce(0, +) == 1,
            "a quota hovering at the threshold without a reset time must notify once")
        expect(observeUnknown(30) == 0 && observeUnknown(25) == 0, "climbing exactly five points must not re-arm")
        expect(observeUnknown(31) == 0 && observeUnknown(25) == 1, "climbing more than five points above the threshold must re-arm")
        expect(observeUnknown(9) == 1 && observeUnknown(12) == 0 && observeUnknown(9) == 0,
            "critical must not repeat while it hovers near 10%")
        expect(observeUnknown(16) == 0 && observeUnknown(9) == 1, "recovering above 15% must re-arm critical")

        var direct = QuotaCrossingTracker()
        func observeDirect(_ windows: [RateLimitWindow], at date: Date = now) -> [QuotaAlert] {
            direct.observe(["work": reading(windows, checkedAt: date)], profiles: ["work"], at: date)
        }
        _ = observeDirect([window(60, 300, resetIn: reset), window(40, 10080, resetIn: 86400)])
        let both = observeDirect([window(20, 300, resetIn: reset), window(10, 10080, resetIn: 86400)])
        expect(both.count == 1 && both[0].slot == 10080 && both[0].level == .critical,
            "two windows crossing together must produce one notification naming the most constrained")
        expect(observeDirect([window(18, 300, resetIn: reset), window(9, 10080, resetIn: 86400)]).isEmpty,
            "every window that crossed together counts as notified")

        let later = now.addingTimeInterval(reset + 1)
        var periodEnded = QuotaCrossingTracker()
        _ = periodEnded.observe(["work": reading([window(5, 300, resetIn: reset)])], profiles: ["work"], at: now)
        let afterReset = periodEnded.observe(["work": reading([window(20, 300, resetIn: 18000, from: later)], checkedAt: later)],
            profiles: ["work"], at: later)
        expect(afterReset.count == 1 && afterReset[0].level == .low,
            "a low reading after the previous window reset must count as a crossing")

        var interrupted = QuotaCrossingTracker()
        _ = interrupted.observe(["work": reading([window(30, 300, resetIn: reset)])], profiles: ["work"], at: now)
        expect(interrupted.observe(["work": .unavailable(checkedAt: now)], profiles: ["work"], at: now).isEmpty, "unavailable usage never notifies")
        expect(interrupted.observe(["work": reading([window(20, 300, resetIn: reset)])], profiles: ["work"], at: now).count == 1,
            "an unavailable reading in between must keep the baseline")
        interrupted.reset()
        expect(interrupted.observe(["work": reading([window(5, 300, resetIn: reset)])], profiles: ["work"], at: now).isEmpty,
            "turning alerts off and on again must start from a new baseline")

        var profiles = QuotaCrossingTracker()
        let healthy: [String: ProfileUsage] = ["work": reading([window(50, 300, resetIn: reset)]), "personal": reading([window(50, 300, resetIn: reset)])]
        _ = profiles.observe(healthy, profiles: ["personal", "work"], at: now)
        let lowBoth: [String: ProfileUsage] = ["work": reading([window(9, 300, resetIn: reset)]), "personal": reading([window(20, 300, resetIn: reset)])]
        expect(profiles.observe(lowBoth, profiles: ["personal", "work"], at: now).map(\.profile) == ["work", "personal"],
            "each profile must notify separately, most constrained first")
        _ = profiles.observe(healthy, profiles: ["personal"], at: now)
        expect(profiles.observe(lowBoth, profiles: ["personal", "work"], at: now).map(\.profile).isEmpty,
            "a removed profile must lose its baseline instead of notifying when it returns")
    }

    private static func headroomSuggestion() {
        let alert = QuotaAlert(profile: "work", window: window(8, 300, resetIn: 3600), slot: 300)
        var usage: [String: ProfileUsage] = [
            "work": reading([window(8, 300, resetIn: 3600)]),
            "personal": reading([window(70, 300, resetIn: 7200), window(60, 10080, resetIn: 86400)]),
            "client": reading([window(95, 300, resetIn: 7200), window(10, 10080, resetIn: 86400)]),
            "stale": reading([window(97, 300, resetIn: 7200)], checkedAt: now.addingTimeInterval(-QuotaHeadroom.maximumAge - 1)),
            "weekly": reading([window(99, 10080, resetIn: 86400)]),
            "expired": reading([window(98, 300, resetIn: -1)]),
            "nearly": reading([window(49, 300, resetIn: 7200)]),
            "offline": .unavailable(checkedAt: now),
        ]
        let profiles = usage.keys.sorted()
        expect(QuotaHeadroom.suggestion(for: alert, usage: usage, profiles: profiles, at: now) == QuotaHeadroom(profile: "personal", remainingPercent: 70),
            "only a fresh profile with clearly more of the same window, and no low window of its own, may be mentioned")
        usage["another"] = reading([window(70, 300, resetIn: 7200)])
        expect(QuotaHeadroom.suggestion(for: alert, usage: usage, profiles: profiles + ["another"], at: now)?.profile == "another",
            "equal headroom must choose deterministically by name")
        expect(QuotaHeadroom.suggestion(for: alert, usage: usage, profiles: ["work", "client", "stale", "weekly", "expired", "nearly"], at: now) == nil,
            "without a clear alternative there must be no suggestion")
        expect(QuotaHeadroom.suggestion(forProfile: "work", usage: usage, profiles: profiles + ["another"], at: now)?.profile == "another"
            && QuotaHeadroom.suggestion(forProfile: "personal", usage: usage, profiles: profiles, at: now) == nil,
            "a row suggestion must start from the profile's own low window, and a healthy profile needs none")
        let unknown = QuotaAlert(profile: "work", window: window(8, nil, resetIn: 3600), slot: -1)
        expect(QuotaHeadroom.suggestion(for: unknown, usage: usage, profiles: profiles, at: now) == nil,
            "an unknown window duration has no comparable window")
    }

    private static func notificationText() {
        let critical = QuotaAlert(profile: "work", window: window(8, 300, resetIn: 3600), slot: 300)
        let suggested = QuotaNotification(alert: critical, headroom: QuotaHeadroom(profile: "personal", remainingPercent: 70), at: now)
        expect(suggested.identifier == "low-quota.work.300" && suggested.title == "work: Codex quota almost used",
            "a critical notification must name the profile and replace earlier ones for the same window")
        expect(suggested.body == "5h limit at 8%. \(critical.window.resetDescription(at: now)). personal has 70% left.",
            "the body must give the reset time and mention clear headroom without switching")
        expect(suggested.body.contains("Resets in 1 hr ("), "countdowns must stay English like the rest of the menu")
        let low = QuotaNotification(alert: QuotaAlert(profile: "work", window: window(20, 10080, resetIn: 600), slot: 10080), headroom: nil, at: now)
        expect(low.title == "work: Codex quota low" && low.body.hasPrefix("7d limit at 20%. Resets in 10 min") && !low.body.contains("left."),
            "a low notification without headroom must not suggest another profile")
        let reached = QuotaNotification(alert: QuotaAlert(profile: "work", window: window(0, 300, resetIn: nil), slot: 300), headroom: nil, at: now)
        expect(reached.title == "work: Codex limit reached" && reached.body == "5h limit reached. Reset time unavailable.",
            "an exhausted window must say so honestly")
    }

    private static func preferencePersistence() {
        let suite = WorkspaceStore.testSuiteName("QuotaAlertPreferences")
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        expect(!QuotaAlertPreferences(defaults: defaults).isEnabled, "low-quota alerts must default to off")
        QuotaAlertPreferences(defaults: defaults).isEnabled = true
        let reopened = UserDefaults(suiteName: suite)!
        expect(reopened.bool(forKey: "lowQuotaAlerts") && QuotaAlertPreferences(defaults: reopened).isEnabled,
            "turning alerts on must persist under a stable key")
        QuotaAlertPreferences(defaults: defaults).isEnabled = false
        expect(!QuotaAlertPreferences(defaults: reopened).isEnabled, "turning alerts off must persist")
    }

    private static func controllerAsksOnlyWhenTurnedOn() async throws {
        let suite = WorkspaceStore.testSuiteName("QuotaAlertController")
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        // Fresh readings stay cached, so the background pass started by turning
        // alerts on cannot replace them; no executable is available anyway.
        let store = WorkspaceStore(client: CLIClient(executableURL: nil), defaults: defaults)
        let start = Date()
        func preview(work: Double, personal: Double = 80, at date: Date = start) {
            store.loadPreview([], profiles: ["personal", "work"], usage: [
                "work": reading([window(work, 300, resetIn: 3600, from: start)], checkedAt: date),
                "personal": reading([window(personal, 300, resetIn: 7200, from: start)], checkedAt: date),
            ])
        }
        preview(work: 30)
        let notifier = FakeNotifier()
        let alerts = QuotaAlertController(store: store, notifier: notifier, defaults: defaults, refreshInterval: 3600)
        var indicators: [QuotaIndicator] = []
        alerts.onIndicatorChange = { indicators.append($0) }
        alerts.start()
        expect(!alerts.isEnabled && notifier.permissionChecks == 0 && notifier.requests == 0 && !store.isRefreshingUsageInBackground,
            "starting with alerts off must not check or request permission or read usage in the background")

        preview(work: 20)
        expect(indicators.last?.level == .low && indicators.last?.alerts.first?.profile == "work", "the icon must mark low quota while alerts are off")
        expect(notifier.posted.isEmpty, "alerts that are off must never notify")

        notifier.grant = false
        expect(await alerts.setEnabled(true) == .denied && notifier.requests == 1, "turning alerts on must ask for permission once")
        expect(!alerts.isEnabled && !QuotaAlertPreferences(defaults: defaults).isEnabled && !store.isRefreshingUsageInBackground,
            "a denied permission must leave alerts and background reads off")
        expect(QuotaAlertController.permissionDeniedMessage.contains("System Settings › Notifications › Codex Profiles"),
            "a denial must explain where to allow notifications")
        expect(await alerts.setEnabled(true) == .denied && notifier.requests == 1, "an earlier denial must not prompt again")

        notifier.current = .notDetermined
        notifier.grant = true
        expect(await alerts.setEnabled(true) == .enabled && alerts.isEnabled && alerts.permission == .allowed,
            "granting permission must turn alerts on")
        expect(QuotaAlertPreferences(defaults: defaults).isEnabled && store.isRefreshingUsageInBackground,
            "turning alerts on must persist the choice and start background reads")
        expect(notifier.posted.isEmpty, "a quota already low when alerts were turned on must not notify")

        preview(work: 8, at: start.addingTimeInterval(1))
        expect(notifier.posted.count == 1 && notifier.posted[0].title == "work: Codex quota almost used"
            && notifier.posted[0].body.hasSuffix("personal has 80% left."),
            "crossing into critical must notify once and mention clear headroom")
        expect(store.profiles == ["personal", "work"] && store.filteredTargets.count == 2,
            "an alert must never switch, hide or reorder profiles")
        preview(work: 7, at: start.addingTimeInterval(2))
        expect(notifier.posted.count == 1, "a newer reading at the same level must not notify again")
        expect(indicators.last?.level == .critical, "the icon must follow the newest reading")

        expect(!alerts.isBlocked, "allowed notifications must not show as blocked")
        notifier.current = .notDetermined
        await alerts.refreshPermission()
        expect(alerts.isEnabled && alerts.isBlocked, "alerts on without a permission answer must show as blocked, like a denial")
        notifier.current = .denied
        await alerts.refreshPermission()
        expect(alerts.isEnabled && alerts.permission == .denied && alerts.isBlocked,
            "revoked permission must be noticed without turning alerts off")

        expect(await alerts.setEnabled(false) == .disabled && !alerts.isEnabled && !store.isRefreshingUsageInBackground,
            "turning alerts off must stop background reads")
        preview(work: 30, personal: 9, at: start.addingTimeInterval(3))
        expect(notifier.posted.count == 1, "alerts turned off must not notify")
        expect(notifier.requests == 2, "turning alerts off must not ask for permission")
    }

    private static func enablingIgnoresUnsettledReadings() async {
        let suite = WorkspaceStore.testSuiteName("QuotaAlertSettled")
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = WorkspaceStore(client: CLIClient(executableURL: nil), defaults: defaults)
        let opened = Date()
        func weekly(_ remaining: Double, checkedAt: Date) -> ProfileUsage {
            reading([window(remaining, 10080, resetIn: 86400, from: opened)], checkedAt: checkedAt)
        }
        // The menu just opened: a two-hour-old 40% reading is on screen while its refresh runs.
        store.loadPreview([], profiles: ["work"], usage: ["work": weekly(40, checkedAt: opened.addingTimeInterval(-7200))],
            readingUsage: ["work"])
        let notifier = FakeNotifier()
        notifier.current = .allowed
        let alerts = QuotaAlertController(store: store, notifier: notifier, defaults: defaults, refreshInterval: 3600)
        expect(await alerts.setEnabled(true) == .enabled, "alerts could not be turned on")
        store.loadPreview([], profiles: ["work"], usage: ["work": weekly(20, checkedAt: Date())])
        expect(notifier.posted.isEmpty,
            "a reading that was still refreshing when alerts were turned on must not make a crossing from stale data")
        store.loadPreview([], profiles: ["work"], usage: ["work": weekly(8, checkedAt: Date().addingTimeInterval(1))])
        expect(notifier.posted.count == 1 && notifier.posted[0].title == "work: Codex quota almost used",
            "the first settled reading after turning alerts on must become the baseline")
        _ = await alerts.setEnabled(false)
    }

    private static func otherReadingsKeepUnsettledProfilesOutOfTheBaseline() async {
        let suite = WorkspaceStore.testSuiteName("QuotaAlertOtherSettled")
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = WorkspaceStore(client: CLIClient(executableURL: nil), defaults: defaults)
        let opened = Date()
        let stale = opened.addingTimeInterval(-7200)
        func weekly(_ remaining: Double, checkedAt: Date) -> ProfileUsage {
            reading([window(remaining, 10080, resetIn: 86400, from: opened)], checkedAt: checkedAt)
        }
        // Both profiles show two-hour-old readings while their refreshes run.
        store.loadPreview([], profiles: ["personal", "work"], usage: [
            "personal": weekly(40, checkedAt: stale),
            "work": weekly(30, checkedAt: stale),
        ], readingUsage: ["personal", "work"])
        let notifier = FakeNotifier()
        notifier.current = .allowed
        let alerts = QuotaAlertController(store: store, notifier: notifier, defaults: defaults, refreshInterval: 3600)
        expect(await alerts.setEnabled(true) == .enabled, "alerts could not be turned on")
        // personal settles first; work's stale reading is still on screen.
        store.loadPreview([], profiles: ["personal", "work"], usage: [
            "personal": weekly(40, checkedAt: Date()),
            "work": weekly(30, checkedAt: stale),
        ], readingUsage: ["work"])
        store.loadPreview([], profiles: ["personal", "work"], usage: [
            "personal": weekly(40, checkedAt: Date()),
            "work": weekly(20, checkedAt: Date()),
        ])
        expect(notifier.posted.isEmpty,
            "another profile's reading must not make a still-refreshing reading the baseline for a crossing")
        _ = await alerts.setEnabled(false)
    }

    private static func unansweredPermissionStopsWaiting() async {
        let suite = WorkspaceStore.testSuiteName("QuotaAlertTimeout")
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = WorkspaceStore(client: CLIClient(executableURL: nil), defaults: defaults)
        store.loadPreview([], profiles: [])
        let notifier = FakeNotifier()
        notifier.answersRequest = false
        let alerts = QuotaAlertController(store: store, notifier: notifier, defaults: defaults, refreshInterval: 3600, permissionTimeout: 0.05)
        let toggle = Task { await alerts.setEnabled(true) }
        for _ in 0..<100 where !alerts.isChanging { await Task.yield() }
        let whileWaiting = await alerts.setEnabled(false)
        expect(alerts.isChanging && whileWaiting == .busy, "a pending permission prompt must keep the toggle waiting")
        expect(await toggle.value == .denied && !alerts.isChanging && !alerts.isEnabled && notifier.requests == 1,
            "an unanswered permission prompt must stop blocking the toggle and leave alerts off")
        notifier.current = .allowed
        expect(await alerts.setEnabled(true) == .enabled && notifier.requests == 1,
            "allowing notifications later must turn alerts on when chosen again, without another prompt")
        _ = await alerts.setEnabled(false)
    }

    private static func backgroundRefreshFollowsAlerts() async throws {
        let suite = WorkspaceStore.testSuiteName("QuotaAlertRefresh")
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let fixture = try UsageTests.Fixture()
        defer { fixture.cleanup() }
        let store = WorkspaceStore(client: CLIClient(executableURL: fixture.executable), defaults: defaults)
        store.loadPreview([], profiles: ["work"])
        let notifier = FakeNotifier()
        notifier.current = .allowed
        let alerts = QuotaAlertController(store: store, notifier: notifier, defaults: defaults, refreshInterval: 0.05)
        alerts.start()
        try await Task.sleep(nanoseconds: 250_000_000)
        expect(calls(fixture) == 0, "alerts that are off must not read usage in the background")

        expect(await alerts.setEnabled(true) == .enabled, "alerts could not be turned on")
        try await waitUntil { if case .available = store.usage["work"] { return !store.isRefreshingUsage } else { return false } }
        let first = calls(fixture)
        expect(first == 1, "turning alerts on must read usage once through the existing reader")
        try await Task.sleep(nanoseconds: 250_000_000)
        expect(calls(fixture) == first, "background passes must reuse the 60-second cache")
        // An older reading is due again, so the next pass reads it.
        store.loadPreview([], profiles: ["work"], usage: ["work": reading([window(50, 300, resetIn: 3600, from: Date())], checkedAt: Date().addingTimeInterval(-120))])
        try await waitUntil { calls(fixture) == first + 1 && !store.isRefreshingUsage }
        expect(!(try fixture.isRunning("work")), "background reads must stop their app-servers")
        _ = await alerts.setEnabled(false)
        try await Task.sleep(nanoseconds: 150_000_000)
        store.loadPreview([], profiles: ["work"], usage: ["work": reading([window(50, 300, resetIn: 3600, from: Date())], checkedAt: Date().addingTimeInterval(-120))])
        try await Task.sleep(nanoseconds: 250_000_000)
        expect(calls(fixture) == first + 1, "turning alerts off must stop background reads")

        let empty = try UsageTests.Fixture()
        defer { empty.cleanup() }
        let emptyStore = WorkspaceStore(client: CLIClient(executableURL: empty.executable), defaults: defaults)
        emptyStore.loadPreview([], profiles: [])
        let emptyAlerts = QuotaAlertController(store: emptyStore, notifier: notifier, defaults: defaults, refreshInterval: 0.05)
        expect(await emptyAlerts.setEnabled(true) == .enabled, "alerts could not be turned on without profiles")
        try await Task.sleep(nanoseconds: 250_000_000)
        expect(calls(empty) == 0, "without initialized profiles no reader may start")
        await emptyStore.stopUsageRefresh()
        expect(!emptyStore.isRefreshingUsageInBackground, "Quit must stop background reads")
        _ = await emptyAlerts.setEnabled(false)
    }

    @MainActor
    private final class FakeNotifier: QuotaNotifying {
        var current = NotificationPermission.notDetermined
        var grant = true
        /// False leaves the prompt unanswered, as when it is dismissed without a choice.
        var answersRequest = true
        var permissionChecks = 0
        var requests = 0
        var posted: [QuotaNotification] = []

        func permission() async -> NotificationPermission {
            permissionChecks += 1
            return current
        }

        func requestPermission() async -> Bool {
            requests += 1
            guard answersRequest else {
                try? await Task.sleep(for: .seconds(3600))
                return false
            }
            current = grant ? .allowed : .denied
            return grant
        }

        func post(_ notification: QuotaNotification) { posted.append(notification) }
    }

    private static func calls(_ fixture: UsageTests.Fixture) -> Int {
        (try? fixture.read("calls"))?.split(whereSeparator: \.isNewline).count ?? 0
    }

    private static func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(3)
        while !condition() {
            expect(Date() < deadline, "background usage refresh did not finish in time")
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    private static func expect(_ condition: Bool, _ message: String) {
        guard condition else { fatalError(message) }
    }
}
