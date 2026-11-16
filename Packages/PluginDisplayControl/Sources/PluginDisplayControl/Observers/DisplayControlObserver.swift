import Combine
import Foundation

@MainActor
final class DisplayControlObserver {
    private var cancellables = Set<AnyCancellable>()
    private var timer: Timer?

    init(viewModel: DisplayControlViewModel, service: DisplayService = .shared) {
        service.objectWillChange
            .sink { [weak viewModel] in viewModel?.apply(service) }
            .store(in: &cancellables)
        viewModel.apply(service)
        service.refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak service] _ in service?.refresh() }
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
        cancellables.removeAll()
    }

    /// 刷新定时器是否在运行（测试用于断言运行时禁用已停止周期刷新，#460）。
    var isRunningForTesting: Bool { timer != nil }
}
