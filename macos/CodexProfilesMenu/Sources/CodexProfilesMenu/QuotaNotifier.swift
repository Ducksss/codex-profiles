import Foundation
import UserNotifications

/// Low-quota notifications through the system notification center. Creating
/// it asks for nothing; permission is requested only when the person turns
/// Low-quota alerts on.
@MainActor
final class UserNotificationsQuotaNotifier: NSObject, QuotaNotifying, UNUserNotificationCenterDelegate {
    /// Clicking a notification opens the menu.
    var onOpen: (() -> Void)?
    private let center: UNUserNotificationCenter?

    override init() {
        // The notification center requires an app bundle; a bare executable has none.
        center = Bundle.main.bundleIdentifier == nil ? nil : UNUserNotificationCenter.current()
        super.init()
        center?.delegate = self
    }

    func permission() async -> NotificationPermission {
        guard let center else { return .denied }
        switch await center.notificationSettings().authorizationStatus {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        default: return .allowed
        }
    }

    func requestPermission() async -> Bool {
        guard let center else { return false }
        return (try? await center.requestAuthorization(options: [.alert])) ?? false
    }

    func post(_ notification: QuotaNotification) {
        guard let center else { return }
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.threadIdentifier = "low-quota"
        center.add(UNNotificationRequest(identifier: notification.identifier, content: content, trigger: nil))
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        let opened = response.actionIdentifier == UNNotificationDefaultActionIdentifier
        completionHandler()
        guard opened else { return }
        Task { @MainActor in self.onOpen?() }
    }
}
