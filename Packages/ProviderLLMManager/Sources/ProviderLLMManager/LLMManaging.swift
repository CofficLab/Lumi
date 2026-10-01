import Foundation
import KitLLM

/// 已注册模型的确定路由。`modelID` 是 Lumi 全局唯一 ID，`modelName` 是
/// 发送给 Provider API 的原始模型名。
public struct LLMModelRoute: Sendable, Equatable {
    public let modelID: LLMModelID
    public let providerID: String
    public let modelName: String
    public let providerInfo: LLMProviderInfo
    public let modelInfo: LLMModelInfo

    public init(
        modelID: LLMModelID,
        providerID: String,
        modelName: String,
        providerInfo: LLMProviderInfo,
        modelInfo: LLMModelInfo
    ) {
        self.modelID = modelID
        self.providerID = providerID
        self.modelName = modelName
        self.providerInfo = providerInfo
        self.modelInfo = modelInfo
    }
}

/// LLM 供应商管理能力
@MainActor
public protocol LLMManaging: AnyObject, SuperLLMProvider {
    // MARK: - Observation（注册 / 选中状态变化监听）

    /// 注册 LLM 供应商/模型状态观察者。
    ///
    /// 回调在状态有效变更后同步执行；返回句柄可 `cancel()` 停止接收。
    @discardableResult
    func addObserver(
        _ callback: @escaping (LLMManagerEvent) -> Void
    ) -> any LLMManagerObserverHandle

    // MARK: - Registration（LLM Provider 插件调用）

    /// 全部已注册供应商，按注册顺序返回。
    func allProviders() -> [any SuperLLMProvider]

    /// 按 id 查找供应商；未注册时返回 `nil`。
    func provider(id: String) -> (any SuperLLMProvider)?

    /// 根据全局模型 ID 查找所属供应商；模型尚未注册时返回 `nil`。
    func provider(for modelID: LLMModelID) -> (any SuperLLMProvider)?

    /// 当前已注册供应商数量（诊断 / 空态 UI）。
    var providerCount: Int { get }

    /// 注册一个供应商。重复注册同一 id 时覆盖实现并保持原顺序。
    /// - Throws: `LLMProviderManagerError.emptyProviderID` — id 为空时。
    func register(_ provider: any SuperLLMProvider) throws

    /// 注销指定 id 的供应商；若注销的是当前选中项，则回退到第一个供应商。
    func unregister(id: String)

    // MARK: - Selection（UI / 发送链路读取）

    /// 当前选中的供应商 id；未持久化且无任何供应商时为 `nil`。
    var selectedProviderID: String? { get }

    /// 当前选中的模型 id（属于选中供应商）；可能为 `nil`（用默认模型回退）。
    var selectedModel: String? { get }

    /// 当前全局选中的 Lumi 全局唯一模型 ID。
    var selectedModelID: LLMModelID? { get }

    /// 指定供应商的模型 id 列表；供应商未注册时返回空数组。
    func models(for providerID: String) -> [String]

    /// 切换选中的供应商与模型（模型可空，表示回退默认模型）。
    /// 供应商不存在时静默忽略（保持现状）。
    /// - Parameter reason: 本次切换的触发来源，随 `selectionChanged` 事件透传。
    func select(providerID: String, model: String?, reason: ModelSelectionReason)

    /// 根据全局模型 ID 查询路由；未注册或模型已不可用时返回 `nil`。
    func modelRoute(for modelID: LLMModelID) -> LLMModelRoute?

    /// 生成指定 Provider 下模型的全局唯一 ID；`model == nil` 表示该 Provider 默认模型。
    func modelID(providerID: String, model: String?) -> LLMModelID?

    /// 只按模型 ID 更新全局选择。
    /// - Parameter reason: 本次切换的触发来源，随 `selectionChanged` 事件透传。
    func select(modelID: LLMModelID, reason: ModelSelectionReason)

    /// 通知观察者：指定供应商的远程模型列表已刷新成功。
    ///
    /// 由供应商插件在成功拉取模型后调用；模型池可能变化，观察者应重新读取
    /// `models(for:)` / `modelRoute(for:)`。默认实现广播 `modelsRefreshed` 事件。
    func notifyModelsRefreshed(providerID: String)
}

public extension LLMManaging {
    var selectedModelID: LLMModelID? {
        guard let selectedProviderID, let selectedModel else { return nil }
        return LLMModelID(providerID: selectedProviderID, modelID: selectedModel)
    }

    func modelID(providerID: String, model: String? = nil) -> LLMModelID? {
        guard let provider = provider(id: providerID) else { return nil }
        let info = provider.providerInfo
        let selected = model ?? (info.defaultModel.isEmpty
            ? modelIDs(of: provider).first
            : info.defaultModel)
        guard let selected,
              contains(model: selected, in: provider) || selected == info.defaultModel else {
            return nil
        }
        return LLMModelID(providerID: providerID, modelID: selected)
    }

    func modelRoute(for modelID: LLMModelID) -> LLMModelRoute? {
        guard let provider = provider(id: modelID.providerID) else { return nil }
        let info = provider.providerInfo
        let dynamicContains = contains(model: modelID.modelID, in: provider)
        guard dynamicContains || info.defaultModel == modelID.modelID else { return nil }
        let modelInfo = modelInfo(for: modelID.modelID, in: provider) ?? LLMModelInfo(id: modelID.modelID)
        return LLMModelRoute(
            modelID: modelID,
            providerID: info.id,
            modelName: modelID.modelID,
            providerInfo: info,
            modelInfo: modelInfo
        )
    }

    func select(modelID: LLMModelID, reason: ModelSelectionReason) {
        guard modelRoute(for: modelID) != nil else { return }
        select(providerID: modelID.providerID, model: modelID.modelID, reason: reason)
    }
}

/// 远程模型列表刷新成功后的通知方法（默认实现不做事，保持自定义实现兼容）。
public extension LLMManaging {
    /// 默认实现为空；`DefaultLLMManager` 覆写为广播 `modelsRefreshed`。
    func notifyModelsRefreshed(providerID: String) {}
}

// MARK: - Dynamic model list capability

public extension LLMManaging {
    /// 获取供应商的动态模型池（可远程更新）。
    ///
    /// 供应商实现 `LLMModelListProviding`（远程模型列表）时读取其
    /// `availableModels`；否则回退到 `providerInfo.models` 静态列表。
    /// 既保证远程模型不落空，也保证静态供应商行为零变化。
    func dynamicModels(of provider: any SuperLLMProvider) -> [LLMModelInfo] {
        (provider as? any LLMModelListProviding)?.availableModels ?? provider.providerInfo.models
    }

    /// 动态模型池中的全部模型 id。
    func modelIDs(of provider: any SuperLLMProvider) -> [String] {
        dynamicModels(of: provider).map(\.id)
    }

    /// 动态模型池是否包含指定模型。
    func contains(model id: String, in provider: any SuperLLMProvider) -> Bool {
        dynamicModels(of: provider).contains { $0.id == id }
    }

    /// 动态模型池中指定模型的元数据；不存在时返回 `nil`。
    func modelInfo(for id: String, in provider: any SuperLLMProvider) -> LLMModelInfo? {
        dynamicModels(of: provider).first { $0.id == id }
    }
}

// MARK: - Default registration

public extension LLMManaging {
    /// 管理器自身作为 `LLMProviding` 的身份标识（区别于具体供应商）。
    static var managerProviderID: String { "llm-provider-manager" }

    func provider(for modelID: LLMModelID) -> (any SuperLLMProvider)? {
        guard modelRoute(for: modelID) != nil else { return nil }
        return provider(id: modelID.providerID)
    }
}
