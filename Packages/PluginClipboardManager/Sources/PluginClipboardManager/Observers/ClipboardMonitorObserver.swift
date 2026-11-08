import Foundation

/// Owns the platform polling loop and forwards clipboard changes to the monitor.
@MainActor
final class ClipboardMonitorObserver {
    private let monitor: ClipboardMonitor
    private var timer: Timer?

    init(monitor: ClipboardMonitor = .shared) {
        self.monitor = monitor
    }

    /// 开始轮询；重复调用无副作用。
    func start() {
        guard timer == nil else { return }
        monitor.startMonitoring()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.monitor.poll()
        }
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
        monitor.stopMonitoring()
    }
}
