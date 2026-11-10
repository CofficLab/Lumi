import Foundation
import ProviderToast

/// Open In 入口的失败反馈边界。
///
/// 标题栏 ViewModel 只依赖这一个方法，避免把 Toast 具体实现泄漏到各插件；
/// 测试可以注入记录型实现，验证「打开失败必须让用户看见」。
@MainActor
public protocol OpenInFailureReporting: AnyObject {
    /// 报告一次打开失败。`title` 由调用方本地化，`detail` 用于展示具体原因。
    func reportOpenFailure(title: String, detail: String?)
}

/// 把失败反馈转成一条错误风格 Toast。
///
/// 未注册 Toast 能力时安静忽略，保持插件在精简内核下的可用性。
@MainActor
public final class OpenInFailureToastReporter: OpenInFailureReporting {
    private let toast: (any ToastProviding)?

    public init(toast: (any ToastProviding)?) {
        self.toast = toast
    }

    public func reportOpenFailure(title: String, detail: String?) {
        toast?.show(title, detail: detail, style: .error)
    }
}

/// 无反馈能力时的空实现，供预览与不需要提示的场景使用。
@MainActor
public final class NoopOpenInFailureReporter: OpenInFailureReporting {
    public init() {}

    public func reportOpenFailure(title: String, detail: String?) {}
}
