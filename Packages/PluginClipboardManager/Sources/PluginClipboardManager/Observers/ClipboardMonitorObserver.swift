import Foundation

/// Owns the platform polling loop and forwards clipboard changes to the monitor.
@MainActor
final class ClipboardMonitorObserver {
    private let monitor: ClipboardMonitor
    private var timer: Timer?

    init(monitor: ClipboardMonitor = .shared) {
        self.monitor = monitor
    }

    /// 轮询间隔（秒）。
    ///
    /// macOS 没有公开的剪贴板变更通知，只能靠轮询 `changeCount` 发现变化。
    /// 两次轮询之间发生的多次复制，中间值会被后一次覆盖而无法恢复 ——
    /// 只能靠缩短间隔把丢失窗口压到最小（见 issue #775）。
    ///
    /// 读取 `changeCount` 是极廉价的操作（每次约 1 微秒），
    /// 100ms 间隔每秒的开销不到 0.02 毫秒。
    nonisolated private static let pollInterval: TimeInterval = 0.1

    /// 开始轮询；重复调用无副作用。
    func start() {
        guard timer == nil else { return }
        monitor.startMonitoring()
        timer = Timer.scheduledTimer(
            withTimeInterval: Self.pollInterval,
            repeats: true
        ) { [weak self] _ in
            self?.monitor.poll()
        }
    }

    /// 当前轮询间隔。仅供单元测试断言。
    nonisolated static var pollIntervalForTesting: TimeInterval { pollInterval }

    func cancel() {
        timer?.invalidate()
        timer = nil
        monitor.stopMonitoring()
    }
}
