import Foundation

/// Toast 展示能力协议
///
/// 定义「任意代码 → 内核 → 瞬时提示」这一段的最小契约。
/// 内核只声明能力;具体的展示策略(渲染位置、队列/替换节流、自动消失
/// 时长、动画等)由实现方(通过插件注册)决定。
///
/// 典型实现:一个 UI 插件在 `onBoot(kernel:)` 中注册实现,通常以根覆盖层
/// (`LumiPlugin.rootOverlays(kernel:)`)方式订阅并渲染;未注册实现时,
/// `kernel.toast` 为 nil,调用方应静默跳过。
@MainActor
public protocol ToastProviding: AnyObject {
    /// 展示一条 Toast。
    ///
    /// **契约**:非阻塞、不抛错。实现可自行决定队列策略(排队、合并或
    /// 替换当前提示)。`toast.duration` 为 `nil` 时使用实现默认时长。
    func show(_ toast: LumiToast)
}

// MARK: - 默认实现

public extension ToastProviding {
    /// 便捷入口:按标题与风格展示一条 Toast。
    func show(
        _ title: String,
        detail: String? = nil,
        style: LumiToastStyle = .info,
        duration: TimeInterval? = nil
    ) {
        show(LumiToast(title: title, detail: detail, style: style, duration: duration))
    }
}
