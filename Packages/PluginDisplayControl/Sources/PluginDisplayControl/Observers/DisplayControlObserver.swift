import Combine
import Foundation

@MainActor
final class DisplayControlObserver {
    private var cancellables = Set<AnyCancellable>()
    private var timer: Timer?

    init(viewModel: DisplayControlViewModel, service: DisplayService = .shared) {
        // 必须订阅 displaysDidChange（displays 写入**之后**发出）而不是
        // objectWillChange（willSet 阶段发出）：后者触发 apply 时读到的还是
        // 旧数组，导致 ViewModel 每轮刷新滞后一轮（#459）。
        // pendingValues 的 objectWillChange 事件不影响 displays 拷贝，无需监听。
        service.displaysDidChange
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
