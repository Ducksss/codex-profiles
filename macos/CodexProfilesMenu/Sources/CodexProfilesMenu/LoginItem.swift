import ServiceManagement

enum LoginItemStatus: Equatable {
    case enabled
    case disabled
    case requiresApproval
}

/// Open at Login for the companion itself. Tests substitute a fake so they
/// never register a real login item.
@MainActor
protocol LoginItemControlling: AnyObject {
    var status: LoginItemStatus { get }
    func register() throws
    func unregister() throws
    func openSystemSettings()
}

@MainActor
final class MainAppLoginItem: LoginItemControlling {
    var status: LoginItemStatus {
        switch SMAppService.mainApp.status {
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        default: .disabled
        }
    }

    func register() throws { try SMAppService.mainApp.register() }
    func unregister() throws { try SMAppService.mainApp.unregister() }
    func openSystemSettings() { SMAppService.openSystemSettingsLoginItems() }
}
