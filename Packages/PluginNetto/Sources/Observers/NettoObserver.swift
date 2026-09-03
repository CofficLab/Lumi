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

        service.objectWillChange
            .sink { [weak viewModel] in viewModel?.applyServiceState() }
            .store(in: &cancellables)
        repo.objectWillChange
            .sink { [weak viewModel] in viewModel?.applySettings() }
            .store(in: &cancellables)

        viewModel.applyServiceState()
        viewModel.applySettings()
        Task { await service.refreshStatus() }
    }

    func cancel() {
        cancellables.removeAll()
    }
}
