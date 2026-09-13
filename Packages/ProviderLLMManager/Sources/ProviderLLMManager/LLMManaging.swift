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
    func select(providerID: String, model: String?)

    /// 根据全局模型 ID 查询路由；未注册或模型已不可用时返回 `nil`。
    func modelRoute(for modelID: LLMModelID) -> LLMModelRoute?

    /// 生成指定 Provider 下模型的全局唯一 ID；`model == nil` 表示该 Provider 默认模型。
    func modelID(providerID: String, model: String?) -> LLMModelID?

    /// 只按模型 ID 更新全局选择。
    func select(modelID: LLMModelID)
}

public extension LLMManaging {
    var selectedModelID: LLMModelID? {
        guard let selectedProviderID, let selectedModel else { return nil }
        return LLMModelID(providerID: selectedProviderID, modelID: selectedModel)
    }

    func modelID(providerID: String, model: String? = nil) -> LLMModelID? {
        guard let provider = provider(id: providerID) else { return nil }
        let selected = model ?? (provider.providerInfo.defaultModel.isEmpty
            ? provider.providerInfo.modelIDs.first
            : provider.providerInfo.defaultModel)
        guard let selected,
              provider.providerInfo.contains(model: selected) || selected == provider.providerInfo.defaultModel else {
            return nil
        }
        return LLMModelID(providerID: providerID, modelID: selected)
    }

    func modelRoute(for modelID: LLMModelID) -> LLMModelRoute? {
        guard let provider = provider(id: modelID.providerID) else { return nil }
        let info = provider.providerInfo
        guard info.contains(model: modelID.modelID) || info.defaultModel == modelID.modelID else { return nil }
        let modelInfo = info.models.first(where: { $0.id == modelID.modelID }) ?? LLMModelInfo(id: modelID.modelID)
        return LLMModelRoute(
            modelID: modelID,
            providerID: info.id,
            modelName: modelID.modelID,
            providerInfo: info,
            modelInfo: modelInfo
        )
    }

    func select(modelID: LLMModelID) {
        guard modelRoute(for: modelID) != nil else { return }
        select(providerID: modelID.providerID, model: modelID.modelID)
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
