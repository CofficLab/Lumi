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

    /// 同步服务状态。
    ///
    /// - Parameters:
    ///   - status: 已知的新状态；为 nil 时回落到服务当前值。
    ///   - events: 已知的新事件列表；为 nil 时回落到服务当前值。
    ///
    /// 观察者会直接传入 @Published 派发出的新值（@Published 在 willSet 阶段
    /// 派发，此刻读取服务属性仍是旧值），因此这两个参数不是可选的常规路径。
    func applyServiceState(status: FilterStatus? = nil, events: [FirewallEvent]? = nil) {
        self.status = status ?? service.status
        self.events = events ?? service.events
    }

    /// 同步设置。
    ///
    /// - Parameter settings: 已知的新设置；为 nil 时回落到仓库当前值。
    func applySettings(_ settings: [String: AppSetting]? = nil) {
        self.settings = settings ?? repo.settings
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
