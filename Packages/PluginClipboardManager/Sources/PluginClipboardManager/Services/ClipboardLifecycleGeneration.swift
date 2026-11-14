import Foundation

/// 剪贴板监控的生命周期代次。
///
/// macOS 没有公开的剪贴板变更通知，只能靠轮询发现变化；一旦插件被运行时禁用，
/// 已经在处理中的内容（尤其是图片编码，它跑在独立的 detached Task 里，
/// 取消定时器并不会让它停下）仍可能写 PNG 与数据库（见 issue #423）。
///
/// 代次机制让在途处理在写盘之前先确认「监控仍然有效」：
/// `stop()` 之后代次必然变化，任何以旧代次开始的处理都会被判定为过期。
///
/// - Note: 全部访问都在主线程（`ClipboardMonitor` 是 `@MainActor`），无需加锁。
struct ClipboardLifecycleGeneration {
    private(set) var value: UInt64 = 0

    /// 当前代次。
    var current: UInt64 { value }

    /// 停止监控：推进代次，让所有在途处理失效。
    mutating func stop() {
        value &+= 1
    }

    /// 以当前代次开始一次处理。
    func begin() -> UInt64 { value }

    /// 处理开始时捕获的代次是否仍然有效。
    func isCurrent(_ captured: UInt64) -> Bool {
        value == captured
    }
}
