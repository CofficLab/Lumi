import LumiUI
import ProviderToast

/// Model Selector 需要的最小 Toast 能力边界。
///
/// ViewModel 只在「刷新模型」「切换模型」两处提示结果，不需要错误弹层、
/// loading 或观察能力。
@MainActor
protocol ModelSelectorToastCapability: AnyObject {
    /// 展示一条 Toast；`ProviderToast` 未注册时为空实现，静默忽略。
    func notify(_ title: String, detail: String?, style: LumiToastStyle)
}

/// 将内核的 `ToastProviding` 收窄为 Model Selector 的提示能力。
@MainActor
final class ModelSelectorToastCapabilityAdapter: ModelSelectorToastCapability {
    private let toast: (any ToastProviding)?

    init(toast: (any ToastProviding)?) {
        self.toast = toast
    }

    func notify(_ title: String, detail: String?, style: LumiToastStyle) {
        toast?.show(title, detail: detail, style: style)
    }
}
