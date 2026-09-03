import Combine
import Foundation

@MainActor
final class NettoViewModel: ObservableObject {
    @Published private(set) var status: FilterStatus = .indeterminate
    @Published private(set) var events: [FirewallEvent] = []
    @Published private(set) var settings: [String: AppSetting] = [:]

    private let service: FirewallService
    private let repo: AppSettingRepo

    init(service: FirewallService = .shared, repo: AppSettingRepo = .shared) {
        self.service = service
        self.repo = repo
    }

    func applyServiceState() {
        status = service.status
        events = service.events
    }

    func applySettings() {
        settings = repo.settings
    }

    func isAllowed(appId: String) -> Bool {
        settings[appId]?.allowed ?? true
    }

    func setAllowed(appId: String, allowed: Bool) {
        repo.setAllowed(appId: appId, allowed: allowed)
        applySettings()
    }

    func toggleFilter() {
        if status == .running {
            service.stopFilter()
        } else {
            service.startFilter()
        }
    }
}
