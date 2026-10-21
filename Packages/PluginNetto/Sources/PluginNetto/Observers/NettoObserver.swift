import Combine
import Foundation

@MainActor
final class NettoObserver {
    private var cancellables = Set<AnyCancellable>()
    private let viewModel: NettoViewModel
    private let service: FirewallService

    init(viewModel: NettoViewModel, service: FirewallService = .shared, repo: AppSettingRepo = .shared) {
        self.viewModel = viewModel
        self.service = service

        // 注意：@Published 在 willSet 阶段派发，objectWillChange 触发时读取
        // service / repo 的属性拿到的仍是旧值，会漏掉「最后一次变更」
        // （新产生的防火墙事件、刚改动的放行设置都不会同步到视图）。
        // 因此这里订阅值本身，并把收到的值直接写回 ViewModel。
        service.$status
            .combineLatest(service.$events)
            .sink { [weak viewModel] status, events in
                viewModel?.applyServiceState(status: status, events: events)
            }
            .store(in: &cancellables)
        repo.$settings
            .sink { [weak viewModel] settings in
                viewModel?.applySettings(settings)
            }
            .store(in: &cancellables)

        viewModel.applyServiceState()
        viewModel.applySettings()
        Task { await service.refreshStatus() }
    }

    func cancel() {
        cancellables.removeAll()
    }
}
