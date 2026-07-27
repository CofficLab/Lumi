import Foundation
import os

/// 运行时桥接：把 `LumiKernel` 提供的插件数据目录传给底层存储服务。
///
/// - `IdleTimePlugin.onBoot` 在首次记录事件前写入 `directoryURL`（来自
///   `kernel.storage?.pluginDataDirectory(for: "IdleTime")`）。
/// - `IdleActivityStore` 初始化时读取它；为 `nil` 时回退到临时目录。
///
/// 用 `OSAllocatedUnfairLock` 保护，满足 Swift 6 严格并发检查
/// （避免非隔离的可变全局共享状态）。
enum IdleTimeRuntimeBridge {
    private static let lock = OSAllocatedUnfairLock<URL?>(initialState: nil)

    static var directoryURL: URL? {
        get { lock.withLock { $0 } }
        set { lock.withLock { $0 = newValue } }
    }
}
