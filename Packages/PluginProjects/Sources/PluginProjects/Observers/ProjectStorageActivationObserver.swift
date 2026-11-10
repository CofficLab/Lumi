import AppKit
import Foundation

/// 监听应用回到前台，重新探测项目存储状态。
///
/// ## 为什么需要
///
/// 项目目录是否还在磁盘上会随外部操作变化：目录被删除、外置硬盘被拔出、
/// 网络卷重新挂载。探测结果按路径缓存在 `ProjectStorageDetector` 中，
/// 缓存不会自己失效，因此需要外部事件触发重新读取。
///
/// 应用激活是最可靠的重探测时机——用户切走再切回来的过程中，磁盘状态
/// 可能已经改变，而 Lumi 在后台期间不会感知到文件系统变化。
@MainActor
final class ProjectStorageActivationObserver {
    private var token: NSObjectProtocol?

    /// - Parameter onActivate: 应用回到前台时调用，用于清空缓存并驱动重绘。
    init(onActivate: @escaping @MainActor () -> Void) {
        token = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                onActivate()
            }
        }
    }

    /// 停止监听。
    ///
    /// - Note: 不放在 `deinit` 里。Swift 6 的 `deinit` 是 nonisolated 的，
    ///   访问 `NSObjectProtocol`（非 Sendable）会直接编译失败。改为显式停止，
    ///   由插件在 `onShutdown` 中调用。
    func cancel() {
        if let token {
            NotificationCenter.default.removeObserver(token)
            self.token = nil
        }
    }
}
