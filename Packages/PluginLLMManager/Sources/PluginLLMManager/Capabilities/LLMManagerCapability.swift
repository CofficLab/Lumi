import Foundation
import KitLLM
import ProviderLLMManager

/// LLM 管理器插件所需的最小供应商管理能力。
///
/// 收敛 `LLMManaging` 的调用面，ViewModel 只依赖本能力，不再把庞大的
/// Provider 传入 View。
@MainActor
protocol LLMManagerCapability: AnyObject {
    var selectedProviderID: String? { get }

    func provider(id: String) -> (any SuperLLMProvider)?

    func allProviders() -> [any SuperLLMProvider]

    func select(providerID: String, model: String?)
}

/// 将 Kernel 的 LLMManaging Provider 适配为插件能力。
@MainActor
final class LLMManagerCapabilityAdapter: LLMManagerCapability {
    private weak var manager: (any LLMManaging)?

    init(manager: any LLMManaging) {
        self.manager = manager
    }

    var selectedProviderID: String? {
        manager?.selectedProviderID
    }

    func provider(id: String) -> (any SuperLLMProvider)? {
        manager?.provider(id: id)
    }

    func allProviders() -> [any SuperLLMProvider] {
        manager?.allProviders() ?? []
    }

    func select(providerID: String, model: String?) {
        manager?.select(providerID: providerID, model: model)
    }
}
