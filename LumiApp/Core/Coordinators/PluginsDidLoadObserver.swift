import Foundation

/// 仅负责在插件加载完成后触发回调；注册/注销与通知名由本类型统一处理。
@MainActor
final class PluginsDidLoadObserver {
    private var token: NSObjectProtocol?

    /// 多次调用时仅在首次注册；`stop()` 后可再次 `start`。
    func start(onFire: @escaping @MainActor () -> Void) {
        guard token == nil else { return }
        token = NotificationCenter.default.addObserver(
            forName: .pluginsDidLoad,
            object: nil,
            queue: nil
        ) { _ in
            Task { @MainActor in
                onFire()
            }
        }
    }

    func stop() {
        if let token {
            NotificationCenter.default.removeObserver(token)
            self.token = nil
        }
    }
}
