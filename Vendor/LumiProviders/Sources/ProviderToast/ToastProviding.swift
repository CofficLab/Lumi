import Foundation

@MainActor
public enum ToastProvidingEvent {
    case currentToastChanged(LumiToast?)
}

@MainActor
public protocol ToastProvidingObserverHandle: AnyObject {
    func cancel()
}

@MainActor
public final class NoopToastProvidingObserverHandle: ToastProvidingObserverHandle {
    public init() {}
    public func cancel() {}
}

/// Toast 展示能力协议
///
/// 定义「任意代码 → 内核 → 瞬时提示」这一段的最小契约。
/// 内核只声明能力;具体的展示策略(渲染位置、队列/替换节流、自动消失
/// 时长、动画等)由实现方(通过插件注册)决定。
///
/// 典型实现:一个 UI 插件在 `onBoot(kernel:)` 中注册实现,通常以根覆盖层
/// 方式订阅并渲染;未注册实现时,调用方应静默跳过。
@MainActor
public protocol ToastProviding: AnyObject {
    var currentToast: LumiToast? { get }

    @discardableResult
    func addObserver(
        _ callback: @escaping (ToastProvidingEvent) -> Void
    ) -> any ToastProvidingObserverHandle

    /// 展示一条 Toast。
    ///
    /// **契约**:非阻塞、不抛错。实现可自行决定队列策略(排队、合并或
    /// 替换当前提示)。`toast.duration` 为 `nil` 时使用实现默认时长。
    func show(_ toast: LumiToast)

    /// 展示一条带来源窗口标识、需要用户明确关闭的错误通知。
    ///
    /// 实现应保留完整的 `message`，并提供可阅读、可复制的持久化面板；
    /// 错误不会像普通 Toast 一样自动消失。
    ///
    /// `sourceWindowID` 非空时，面板只在对应窗口渲染；为 `nil` 时由呈现层
    /// 在当前活动窗口兜底显示，避免同一错误在多个窗口重复弹出。
    func presentError(title: String, message: String, sourceWindowID: String?)

    /// 关闭当前持久化错误通知。
    func dismissError()
}

/// 可选的持续加载状态能力。
///
/// 通过独立协议保持 `ToastProviding` 的向后兼容性：只需要普通 Toast 的
/// 实现无需增加 loading 状态；完整的共享 Toast 插件实现此协议。
@MainActor
public protocol ToastLoadingProviding: ToastProviding {
    var currentLoading: LumiLoadingNotice? { get }
    func showLoading(title: String, detail: String?)
    func dismissLoading()
    func dismissAll()
}

// MARK: - 默认实现

public extension ToastProviding {
    var currentToast: LumiToast? { nil }

    /// 不指定来源窗口的便捷入口；等价于 `sourceWindowID == nil`，
    /// 由呈现层在当前活动窗口兜底显示。
    func presentError(title: String, message: String) {
        presentError(title: title, message: message, sourceWindowID: nil)
    }

    @discardableResult
    func addObserver(
        _ callback: @escaping (ToastProvidingEvent) -> Void
    ) -> any ToastProvidingObserverHandle {
        NoopToastProvidingObserverHandle()
    }

    /// 便捷入口:按标题与风格展示一条 Toast。
    func show(
        _ title: String,
        detail: String? = nil,
        style: LumiToastStyle = .info,
        duration: TimeInterval? = nil
    ) {
        show(LumiToast(title: title, detail: detail, style: style, duration: duration))
    }

    /// 兼容旧版 Cisum 的加载接口；不支持 loading 的 Provider 安静忽略。
    var currentLoading: LumiLoadingNotice? {
        (self as? any ToastLoadingProviding)?.currentLoading
    }

    func showLoading(title: String, detail: String?) {
        (self as? any ToastLoadingProviding)?.showLoading(title: title, detail: detail)
    }

    func dismissLoading() {
        (self as? any ToastLoadingProviding)?.dismissLoading()
    }

    func dismissAll() {
        if let provider = self as? any ToastLoadingProviding {
            provider.dismissAll()
        } else {
            dismissError()
        }
    }

    /// 便捷状态接口：保持 Lumi/Cisum 业务插件的调用方式一致。
    func info(_ title: String, detail: String? = nil, duration: TimeInterval = 3) {
        show(title, detail: detail, style: .info, duration: duration)
    }

    func success(_ title: String, detail: String? = nil, duration: TimeInterval = 3) {
        show(title, detail: detail, style: .success, duration: duration)
    }

    func warning(_ title: String, detail: String? = nil, duration: TimeInterval = 4) {
        show(title, detail: detail, style: .warning, duration: duration)
    }

    func error(_ title: String, detail: String? = nil, duration: TimeInterval? = nil) {
        if let duration {
            show(title, detail: detail, style: .error, duration: duration)
        } else {
            presentError(title: title, message: detail ?? title)
        }
    }

    func error(_ error: Error, title: String = "Error", duration: TimeInterval? = nil) {
        self.error(title, detail: error.localizedDescription, duration: duration)
    }
}
