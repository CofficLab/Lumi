import Foundation
import ProviderToast

/// Open In Remote 插件的提示能力边界。
///
/// ViewModel 只在「打开失败」一处提示原因，不需要错误弹层、loading 或
/// 观察能力，因此收窄为单条 Toast 通知。
@MainActor
protocol OpenInRemoteToastCapability: AnyObject {
    /// 展示一条 Toast；`ProviderToast` 未注册时为空实现，静默忽略。
    func notify(_ title: String, detail: String?, style: LumiToastStyle)
}

/// 将内核的 `ToastProviding` 收窄为 Open In Remote 插件的提示能力。
@MainActor
final class OpenInRemoteToastCapabilityAdapter: OpenInRemoteToastCapability {
    private let toast: (any ToastProviding)?

    init(toast: (any ToastProviding)?) {
        self.toast = toast
    }

    func notify(_ title: String, detail: String?, style: LumiToastStyle) {
        toast?.show(title, detail: detail, style: style)
    }
}
