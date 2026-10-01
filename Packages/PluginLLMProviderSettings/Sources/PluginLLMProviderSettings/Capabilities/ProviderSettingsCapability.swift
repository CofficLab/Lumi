import Combine
import Foundation
import KitLLM
import ProviderLLMManager

/// 供应商设置插件需要的最小管理能力。
///
/// 收敛 `LLMManaging` 与 `UserDefinedCloudProviderStore` 的调用面，
/// 页面 ViewModel 只依赖本能力，不再把庞大的 Provider 或 Store 传入 View。
@MainActor
protocol ProviderSettingsCapability: AnyObject {
    var allProviders: [any SuperLLMProvider] { get }
    var selectedProviderID: String? { get }
    var selectedModel: String? { get }
    var selectedModelID: String? { get }

    func provider(id: String) -> (any SuperLLMProvider)?
    func select(providerID: String, model: String?)
    func modelID(providerID: String, model: String) -> String?
    func select(modelID: String)

    // MARK: 动态模型池

    /// 远程模型源刷新成功后发布 providerID（供 VM 订阅刷新 models）。
    var modelsUpdatedPublisher: AnyPublisher<String, Never> { get }

    /// 指定供应商的动态模型池：远程型读 `availableModels`，静态型读 `providerInfo.models`。
    func availableModels(for providerID: String) -> [LLMModelInfo]

    // MARK: API Key

    func apiKey(for providerID: String) -> String
    func setAPIKey(_ value: String, for providerID: String)
    func removeAPIKey(for providerID: String)

    // MARK: 自定义供应商

    /// 自定义供应商配置变化发布者（供 ViewModel 刷新）。
    var customProviderConfigurationsPublisher: AnyPublisher<[UserDefinedCloudProviderConfiguration], Never> { get }
    func customProviderConfiguration(id: String) -> UserDefinedCloudProviderConfiguration?
    func isCustomProvider(id: String) -> Bool
    func removeCustomProvider(id: String)
    func makeCustomProviderEditor(configuration: UserDefinedCloudProviderConfiguration?) -> CustomCloudProviderEditor?

    // MARK: 下载

    /// 供应商支持模型下载时返回下载能力，否则返回 `nil`。
    func makeModelDownloadCapability(for providerID: String) -> (any ModelDownloadCapability)?
}

/// 将内核的 LLMManaging 与自定义供应商 Store 收窄为设置插件能力。
@MainActor
final class ProviderSettingsCapabilityAdapter: ProviderSettingsCapability {
    private let manager: any LLMManaging
    private let customProviderStore: UserDefinedCloudProviderStore?

    private let modelsUpdatedSubject = PassthroughSubject<String, Never>()
    private var observer: (any LLMManagerObserverHandle)?

    init(
        manager: any LLMManaging,
        customProviderStore: UserDefinedCloudProviderStore?
    ) {
        self.manager = manager
        self.customProviderStore = customProviderStore
        observer = manager.addObserver { [modelsUpdatedSubject] event in
            if case let .modelsRefreshed(providerID) = event {
                modelsUpdatedSubject.send(providerID)
            }
        }
    }

    var allProviders: [any SuperLLMProvider] {
        manager.allProviders()
    }

    var selectedProviderID: String? {
        manager.selectedProviderID
    }

    var selectedModel: String? {
        manager.selectedModel
    }

    var selectedModelID: String? {
        manager.selectedModelID?.rawValue
    }

    func provider(id: String) -> (any SuperLLMProvider)? {
        manager.provider(id: id)
    }

    func select(providerID: String, model: String?) {
        manager.select(providerID: providerID, model: model, reason: .userSelected)
    }

    func modelID(providerID: String, model: String) -> String? {
        manager.modelID(providerID: providerID, model: model)?.rawValue
    }

    func select(modelID: String) {
        guard let modelID = LLMModelID(rawValue: modelID) else { return }
        manager.select(modelID: modelID, reason: .userSelected)
    }

    var modelsUpdatedPublisher: AnyPublisher<String, Never> {
        modelsUpdatedSubject.eraseToAnyPublisher()
    }

    func availableModels(for providerID: String) -> [LLMModelInfo] {
        guard let provider = manager.provider(id: providerID) else { return [] }
        if let dynamic = provider as? any LLMModelListProviding {
            return dynamic.availableModels
        }
        return provider.providerInfo.models
    }

    func apiKey(for providerID: String) -> String {
        provider(id: providerID)?.getApiKey() ?? ""
    }

    func setAPIKey(_ value: String, for providerID: String) {
        provider(id: providerID)?.setApiKey(value)
    }

    func removeAPIKey(for providerID: String) {
        provider(id: providerID)?.removeApiKey()
    }

    var customProviderConfigurationsPublisher: AnyPublisher<[UserDefinedCloudProviderConfiguration], Never> {
        customProviderStore?.$configurations.eraseToAnyPublisher()
            ?? Just([]).eraseToAnyPublisher()
    }

    func customProviderConfiguration(id: String) -> UserDefinedCloudProviderConfiguration? {
        customProviderStore?.configurations.first { $0.id == id }
    }

    func isCustomProvider(id: String) -> Bool {
        customProviderStore?.isCustomProvider(id: id) ?? false
    }

    func removeCustomProvider(id: String) {
        try? customProviderStore?.remove(id: id)
    }

    func makeCustomProviderEditor(configuration: UserDefinedCloudProviderConfiguration?) -> CustomCloudProviderEditor? {
        guard let customProviderStore else { return nil }
        return CustomCloudProviderEditor(
            store: customProviderStore,
            configuration: configuration
        )
    }

    func makeModelDownloadCapability(for providerID: String) -> (any ModelDownloadCapability)? {
        guard let provider = provider(id: providerID),
              let downloader = provider as? any LLMModelDownloadProviding
        else {
            return nil
        }
        return ModelDownloadCapabilityAdapter(downloader: downloader)
    }
}
